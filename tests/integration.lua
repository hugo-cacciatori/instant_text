package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")
local Sdk = require("tests.modkit.sdk")
local GameVersion = require("src.core.GameVersion")
local Runtime = require("src.mods.Runtime")
local Logger = require("src.core.Logger")
-- Missing-glyph warnings are expected without imported fonts; keep output readable.
if Logger.warn then Logger.warn = function() end end
local total = 0
local function check(value, message)
  total = total + 1
  assert(value, message)
end

local function load(version, generation)
  GameVersion.set(version)
  Runtime.reset()
  local opts = { generation = generation }
  if generation == 3 then opts.data = Sdk.gen3Data() end
  local run = Sdk.loadMod(MOD_PATH, opts)
  check(#run.errors == 0, version .. ": " .. table.concat(run.errors, "\n"))
  check(run.mod and run.mod.state == "loaded", version .. ": real loader")
  check(not run.loader.optionSchemas.instant_text, version .. ": no settings schema")
  return run
end

-- ------------------------------------------------------------ Gen 1 / Gen 2
local TextBox = require("src.render.TextBox")
local pressed = false
local function textGame(options)
  local popped = 0
  local game = {
    data = {}, save = { options = options },
    input = { wasPressed = function(_, k) return pressed and (k == "a") end,
              isDown = function() return false end },
    stack = { push = function() end, pop = function() popped = popped + 1 end,
              top = function() end },
  }
  return game, function() return popped end
end
local TEXT = "HELLO THERE\nSECOND LINE\fPAGE TWO"
local function framesToWait(box, limit)
  local n = 0
  while not box.waiting and not box.done and n < limit do box:update(1 / 60); n = n + 1 end
  return n
end

local function checkTextBox(version, options, vanilla)
  local game, popped = textGame(options)
  check(vanilla > 20, version .. ": vanilla typewriter is slow (" .. vanilla .. ")")
  local box = TextBox.new(game, TEXT)
  local n = framesToWait(box, 1000)
  check(n <= 2 and box.waiting, version .. ": two-line page appears at once (" .. n .. ")")
  for _ = 1, 30 do box:update(1 / 60) end
  check(box.waiting and popped() == 0, version .. ": page prompt still waits for A")
  pressed = true
  box:update(1 / 60)
  pressed = false
  check(not box.waiting and (box.holdFrames or 0) > 0, version .. ": page clear hold preserved")
  local hold = 0
  while (box.holdFrames or 0) > 0 do box:update(1 / 60); hold = hold + 1 end
  check(hold >= 15, version .. ": page clear timing kept (" .. hold .. ")")
  box:update(1 / 60)
  check(box.done and popped() == 0, version .. ": last page instant, box stays until A")
  pressed = true
  box:update(1 / 60)
  pressed = false
  check(popped() == 1, version .. ": A closes the finished box")

  -- Scripted pause markers still pause.
  local paused = TextBox.new(game, "WAIT" .. TextBox.PAUSE .. "FOR IT")
  paused:update(1 / 60)
  check(paused.pauseFrames and paused.pauseFrames > 0 and not paused.done,
    version .. ": pause marker still holds the text")
  local pf = 0
  while not paused.done and pf < 200 do paused:update(1 / 60); pf = pf + 1 end
  check(paused.done and pf >= 10, version .. ": text resumes after the pause (" .. pf .. ")")
  return game
end

for _, spec in ipairs({
  { "red", 1, { textSpeed = 5 } }, { "blue", 1, { textSpeed = 5 } },
  { "yellow", 1, { textSpeed = 3 } },
  { "gold", 2, { textSpeed = "SLOW" } }, { "silver", 2, { textSpeed = "MID" } },
  { "crystal", 2, { textSpeed = "SLOW" } },
}) do
  local version, generation, options = spec[1], spec[2], spec[3]
  GameVersion.set(version)
  Runtime.reset()
  local vanilla = framesToWait(TextBox.new((textGame(options)), TEXT), 1000)
  local run = load(version, generation)
  local game = checkTextBox(version, options, vanilla)
  if generation == 1 then
    local BattleState = require("src.battle.BattleState")
    local codes = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
    local battle = setmetatable({ current = {}, shown = { {} }, codes = codes,
      lines = { {} }, lineIndex = 1, charIndex = 0, queue = {}, game = game },
      { __index = BattleState })
    battle:updateQueue()
    check(#battle.shown[1] == #codes and battle.charTimer == 0,
      version .. ": battle line typed in one frame without leftover timer")
    battle.shown, battle.charIndex, battle.msgWaiting = { {} }, 0, true
    battle.msgPreWait = 3
    battle:updateQueue()
    check(#battle.shown[1] == 0, version .. ": battle CONT wait still blocks")
  else
    local Typer = require("src.ui.gen2.Typer")
    local typer = Typer.new(game)
    typer:start({ "HELLO", "WORLD" })
    check(typer:tick() and typer.shown == typer.total, version .. ": Typer page at once")
  end
  run.loader:_rollback("instant_text")
  local slow = TextBox.new(game, TEXT)
  check(framesToWait(slow, 1000) > 20, version .. ": rollback restores typewriter")
  if generation == 2 then
    local typer = require("src.ui.gen2.Typer").new(game)
    typer:start({ "HELLO", "WORLD" })
    check(not typer:tick(), version .. ": rollback restores Typer")
  end
  run.release()
  local again = load(version, generation)
  check(TextBox.update == TextBox._instantTextBridge.update, version .. ": reload reuses bridge")
  again.release()
  Runtime.reset()
  check(framesToWait(TextBox.new(game, TEXT), 1000) > 20, version .. ": reset restores vanilla")
  print("PASS " .. version)
end

-- ------------------------------------------------------------------- Gen 3
local dummyFont = {
  widths = setmetatable({}, { __index = function() return 6 end }),
  quads = setmetatable({}, { __index = function() return {} end }),
  height = 14, pitch = 16, letterSpacing = 0,
}
local okRs, rsFaces = pcall(require, "src.ui.game3.rs.font_faces")
if okRs and type(rsFaces) == "table" then
  local realLoad = rsFaces.load
  rsFaces.load = function(spec, name, language, loadImage, loadTable, palette, textMode)
    local okTbl, tbl = pcall(loadTable, spec.manifest)
    if okTbl and tbl then
      return realLoad(spec, name, language, loadImage, loadTable, palette, textMode)
    end
    return dummyFont
  end
end

local Message = require("src.ui.game3.message")
local function messageFrames(limit)
  local n = 0
  while not Message.isWaiting() and n < limit do Message.tick(); n = n + 1 end
  return n
end
local Kit = require("src.ui.game3.rse.scene_kit")
local IR = { { t = "text", s = "HI THERE" }, { t = "ext", cmd = 0x08, args = { 6 } },
  { t = "text", s = "SLOW" }, { t = "para" }, { t = "text", s = "MORE" } }
local function kitFrames(p, limit)
  local n = 0
  while p.state == "char" and n < limit do p:run({ new = {}, held = {} }); n = n + 1 end
  return n
end

for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  GameVersion.set(version)
  Runtime.reset()
  Message.reset()
  Message.show("HELLO THERE\nSECOND LINE", { speed = 1 })
  local vanilla = messageFrames(1000)
  Message.reset()
  check(vanilla > 20, version .. ": vanilla message is slow (" .. vanilla .. ")")
  local run = load(version, 3)

  Message.show("HELLO THERE\nSECOND LINE\fPAGE TWO", { speed = 1 })
  check(messageFrames(1000) <= 1, version .. ": message page appears at once")
  for _ = 1, 30 do Message.tick() end
  check(Message.isOpen() and Message._page == 1, version .. ": page waits for A")
  Message.advance()
  check(Message._page == 2, version .. ": A turns the page")
  check(messageFrames(1000) <= 1, version .. ": next page at once")
  Message.advance()
  check(not Message.isOpen(), version .. ": A closes the last page")

  local stayed = false
  Message.show("STAY UP", { speed = 1, stay = true })
  check(messageFrames(10) <= 1, version .. ": stay message at once")
  Message.advance()
  stayed = Message.isOpen()
  check(stayed, version .. ": stay message remains open")
  Message.reset()

  Message.show("AUTO ONE\fAUTO TWO", { speed = 1 })
  Message.setAutoScroll()
  messageFrames(10)
  local ticks = 0
  while Message._page == 1 and ticks < 200 do Message.tick(); ticks = ticks + 1 end
  check(Message._page == 2 and ticks >= 45, version .. ": auto-scroll hold kept (" .. ticks .. ")")
  Message.reset()

  local p = Kit.printer(IR, { speed = 4 })
  p:run({ new = {}, held = {} })
  check(p.state == "pause" and p.lines[1] == "HI THERE", version .. ": SceneKit drains to the pause")
  local pauseFrames = 0
  while p.state == "pause" and pauseFrames < 50 do p:run({ new = {}, held = {} }); pauseFrames = pauseFrames + 1 end
  check(pauseFrames >= 6, version .. ": SceneKit pause timing kept (" .. pauseFrames .. ")")
  p:run({ new = {}, held = {} })
  check(p.state == "clear" and p.lines[1] == "HI THERESLOW", version .. ": SceneKit stops at page break")
  for _ = 1, 20 do p:run({ new = {}, held = {} }) end
  check(p.state == "clear", version .. ": SceneKit page break waits for A")
  p:run({ new = { a = true }, held = {} })
  p:run({ new = {}, held = {} })
  check(not p.active or p.lines[1] == "MORE", version .. ": SceneKit next page at once")

  run.loader:_rollback("instant_text")
  Message.show("HELLO THERE\nSECOND LINE", { speed = 1 })
  check(messageFrames(1000) > 20, version .. ": rollback restores message speed")
  Message.reset()
  check(kitFrames(Kit.printer(IR, { speed = 4 }), 1000) > 5, version .. ": rollback restores SceneKit")
  run.release()
  local again = load(version, 3)
  check(Message.tick == Message._instantTextBridge.tick, version .. ": reload reuses bridge")
  again.release()
  Runtime.reset()
  Message.show("HELLO THERE\nSECOND LINE", { speed = 1 })
  check(messageFrames(1000) > 20, version .. ": reset restores vanilla")
  Message.reset()
  print("PASS " .. version)
end

print("PASS " .. total .. " assertions; native loader and printers across Gen 1-3; no windows")
