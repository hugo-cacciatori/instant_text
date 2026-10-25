package.path = "./?.lua;./?/init.lua;" .. package.path
-- Supply data compression only; native cache access remains headless.
love = {
  data = {
    compress = function(_, _, bytes, level) return deflate(bytes, level) end,
    decompress = function(_, _, bytes) return inflate(bytes) end,
  },
  graphics = {
    newQuad = function() return {} end,
    newImage = function() return { getDimensions = function() return 256, 256 end } end,
  },
}
local GameVersion = require("src.core.GameVersion")
GameVersion.set(TEST_VERSION)
assert(require("src.core.Version").engine == "0.3.96", "wrong installed engine")

local fs, overlay = {}, {}
function fs.read(p) return overlay[p] or fs_read(p) end
function fs.getInfo(p) return overlay[p] and { type = "file" } or fs_info(p) end
function fs.getDirectoryItems(p) return fs_list(p) end
function fs.load(p)
  local bytes = fs.read(p)
  return bytes and loadstring(bytes, "@" .. p)
end
function fs.write(p, bytes) overlay[p] = bytes return true end
function fs.createDirectory() return true end
fs.root = "."

local generation = GameVersion.generation()
local Loader = require("src.mods.Loader")
local game = { data = {} }
if generation == 3 then
  local Dataset = require("src.core.game3.dataset")
  Dataset.cacheRootOverride = CACHE_ROOT
  assert(Dataset.hydrate(game), "installed dataset did not hydrate")
end

local loader = Loader.new({ fs = fs, generation = generation })
loader:load(game.data)
assert(#loader.errors == 0, table.concat(loader.errors, "\n"))
local mod = loader.mods.instant_text
assert(mod and mod.state == "loaded", "installed mod did not load for " .. TEST_VERSION)

if generation == 3 then
  local Message = require("src.ui.game3.message")
  Message.reset()
  Message.show("INSTALLED TEST\nSECOND LINE\fPAGE TWO", { speed = 1 })
  local n = 0
  while not Message.isWaiting() and n < 10 do Message.tick(); n = n + 1 end
  assert(n <= 1 and Message.isOpen() and Message._page == 1, "page 1 did not reveal instantly")
  Message.advance()
  assert(Message._page == 2, "A press did not advance to page 2")
  n = 0
  while not Message.isWaiting() and n < 10 do Message.tick(); n = n + 1 end
  assert(n <= 1 and Message.isOpen() and Message._page == 2, "page 2 did not reveal instantly")
  Message.advance()
  assert(not Message.isOpen(), "A press did not close final page")

  loader:_rollback("instant_text")
  Message.show("SLOW TEST", { speed = 1 })
  local slowTicks = 0
  while not Message.isWaiting() and slowTicks < 100 do Message.tick(); slowTicks = slowTicks + 1 end
  assert(slowTicks > 5, "rollback did not restore slow reveal")
  Message.reset()
  print("PASS installed " .. TEST_VERSION .. ": instant message reveal and rollback")
  return
end

if generation == 1 then
  local TextBox = require("src.render.TextBox")
  local BattleState = require("src.battle.BattleState")
  local pressed = false
  local popped = 0
  local testGame = {
    data = {}, save = { options = { textSpeed = 5 } },
    input = { wasPressed = function(_, k) return pressed and k == "a" end, isDown = function() return false end },
    stack = { push = function() end, pop = function() popped = popped + 1 end, top = function() end },
  }
  local box = TextBox.new(testGame, "INSTALLED DIALOGUE\nSECOND LINE\fPAGE TWO")
  local n = 0
  while not box.waiting and not box.done and n < 10 do box:update(1 / 60); n = n + 1 end
  assert(n <= 2 and box.waiting, "Gen 1 dialogue did not reveal page 1 instantly")
  while (box.preWait or 0) > 0 do box:update(1 / 60) end
  pressed = true
  box:update(1 / 60)
  pressed = false
  while (box.holdFrames or 0) > 0 do box:update(1 / 60) end
  box:update(1 / 60)
  assert(box.done, "Gen 1 dialogue did not reveal page 2 instantly")

  -- Battle text
  local codes = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
  local battle = setmetatable({ current = {}, shown = { {} }, codes = codes,
    lines = { {} }, lineIndex = 1, charIndex = 0, queue = {}, game = testGame },
    { __index = BattleState })
  battle:updateQueue()
  assert(#battle.shown[1] == #codes and battle.charTimer == 0, "Gen 1 battle text line not instant")

  loader:_rollback("instant_text")
  local slowBox = TextBox.new(testGame, "SLOW NOW\nAGAIN")
  local slowFrames = 0
  while not slowBox.waiting and not slowBox.done and slowFrames < 100 do slowBox:update(1 / 60); slowFrames = slowFrames + 1 end
  assert(slowFrames > 10, "Gen 1 rollback did not restore typewriter")
  print("PASS installed " .. TEST_VERSION .. ": instant dialogue, battle text, and rollback")
  return
end

if generation == 2 then
  local TextBox = require("src.render.TextBox")
  local Typer = require("src.ui.gen2.Typer")
  local testGame = {
    data = {}, save = { options = { textSpeed = "SLOW" } },
    input = { wasPressed = function() return false end, isDown = function() return false end },
    stack = { push = function() end, pop = function() end, top = function() end },
  }
  local box = TextBox.new(testGame, "CRYSTAL DIALOGUE\nLINE TWO")
  local n = 0
  while not box.waiting and not box.done and n < 10 do box:update(1 / 60); n = n + 1 end
  assert(n <= 2 and box.done, "Gen 2 dialogue did not reveal instantly")

  local typer = Typer.new(testGame)
  typer:start({ "HELLO", "CRYSTAL" })
  assert(typer:tick() and typer.shown == typer.total, "Gen 2 Typer did not reveal instantly")

  loader:_rollback("instant_text")
  local slowBox = TextBox.new(testGame, "SLOW NOW\nAGAIN")
  local slowFrames = 0
  while not slowBox.waiting and not slowBox.done and slowFrames < 100 do slowBox:update(1 / 60); slowFrames = slowFrames + 1 end
  assert(slowFrames > 10, "Gen 2 rollback did not restore typewriter")
  local slowTyper = Typer.new(testGame)
  slowTyper:start({ "HELLO", "CRYSTAL" })
  assert(not slowTyper:tick(), "Gen 2 rollback did not restore Typer delay")
  print("PASS installed " .. TEST_VERSION .. ": instant dialogue, Typer, and rollback")
  return
end
