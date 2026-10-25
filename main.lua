-- Instant Text: every text printer reveals the current page (or the segment up
-- to the next scripted pause) at once. Prompts, page breaks, choices and timed
-- pauses keep their native behavior.
--
-- gen1recomp 0.3.96 has no text-speed hook, so each printer gets one
-- idempotent bridge that asks the mod-owned hook HOOK. The loader removes that
-- hook on rollback/reset, which turns every bridge back into a pass-through.
-- Save data and options are never written.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  local generation = tonumber(mod and mod.generation)
    or tonumber(mod and mod.game and mod.game.generation)
    or tonumber(GameVersion.generation())

  local HOOK = "instant_text.enabled"
  local MARK = "_instantTextBridge"
  local BOOST = 100000
  local DRAIN_LIMIT = 4096
  local function no() return false end
  local function enabled()
    return Runtime.wantsHook(HOOK) and Runtime.call(HOOK, no) == true
  end

  -- Replace t[key] once with build(original); repeated loads reuse it.
  local function bridge(t, key, build)
    if type(t) ~= "table" or type(t[key]) ~= "function" then return false end
    t[MARK] = t[MARK] or {}
    if not t[MARK][key] then
      t[key] = build(t[key])
      t[MARK][key] = t[key]
    end
    return true
  end

  local function optional(name)
    local ok, value = pcall(require, name)
    return ok and type(value) == "table" and value or nil
  end

  -- Shared drain for token printers whose `render` handles one token per call
  -- in state "char" (RSE SceneKit and the FRLG new-game scene). Stops as soon
  -- as a pause, wait, page break, scroll or the end changes the state.
  local function drainRun(original)
    return function(self, ...)
      if not (enabled() and self.active and self.state == "char") then
        return original(self, ...)
      end
      local result
      for _ = 1, DRAIN_LIMIT do
        if not (self.active and self.state == "char") then break end
        self.delay = 0
        result = self:render(...)
        if result == "finish" then return result end
      end
      return result
    end
  end

  if generation == 3 then
    local Message = require("src.ui.game3.message")
    assert(type(Message.tick) == "function" and type(Message.skipReveal) == "function",
      "Instant Text: missing Gen 3 message printer")
    local Rs = optional("src.ui.game3.rs.field_auto_scroll_message")

    bridge(Message, "tick", function(original)
      return function(...)
        if enabled() and Message.open and not Message._waiting
            and not (Rs and Rs.ownsFrame and Rs.ownsFrame()) then
          Message.skipReveal()
        end
        return original(...)
      end
    end)

    -- Ruby/Sapphire field text runs on the native auto-scroll printer. Its
    -- state is private, so remember each prepared state and drain plain
    -- character steps; pause and the 60-frame wait/scroll timers stay.
    if Rs and type(Rs.prepare) == "function" and type(Rs.tick) == "function" then
      local prepared = setmetatable({}, { __mode = "k" })
      bridge(Rs, "prepare", function(original)
        return function(...)
          local s = original(...)
          if type(s) == "table" then prepared[s] = true end
          Rs._instantTextLast = s
          return s
        end
      end)
      local DRAIN = { char_delay = true, normal = true, begin = true, newline = true }
      bridge(Rs, "tick", function(original)
        return function(...)
          local s = Rs._instantTextLast
          if not (enabled() and s and prepared[s] and Rs.isPrinting()
              and (s.task or 0) >= 2 and DRAIN[s.printer]) then
            return original(...)
          end
          for _ = 1, DRAIN_LIMIT do
            if not (Rs.isPrinting() and DRAIN[s.printer]) then break end
            s.delay = 0
            original(...)
          end
        end
      end)
    end

    local Kit = optional("src.ui.game3.rse.scene_kit")
    if Kit and type(Kit.printer) == "function" then
      local ok, probe = pcall(Kit.printer, {}, { speed = 1 })
      local Printer = ok and getmetatable(probe)
      if type(Printer) == "table" then bridge(Printer, "run", drainRun) end
    end

    -- The FRLG intro printer is created inside Scene:oakPrint; bridge its
    -- class the first time one appears.
    local Scene = optional("src.ui.game3.new_game_scene")
    if Scene then
      bridge(Scene, "oakPrint", function(original)
        return function(self, ...)
          local result = original(self, ...)
          local Printer = self and type(self.printer) == "table" and getmetatable(self.printer)
          if type(Printer) == "table" then bridge(Printer, "run", drainRun) end
          return result
        end
      end)
    end
  else
    assert(generation == 1 or generation == 2,
      "Instant Text: unsupported generation " .. tostring(generation))
    local TextBox = require("src.render.TextBox")
    assert(type(TextBox.update) == "function", "Instant Text: missing TextBox")

    local function typing(box)
      return not box.done and not box.waiting and (box.holdFrames or 0) <= 0
        and box.pauseFrames == nil and not box.pauseSrc and not box.preSound
        and type(box.codes) == "table" and (box.charIndex or 0) < #box.codes
    end

    -- The vanilla typewriter stops at each line end; continue through the
    -- following lines of the page in the same frame, but never while a
    -- scroll slide is animating, and keep the arrow blink cadence.
    bridge(TextBox, "update", function(original)
      return function(self, dt, ...)
        if not (enabled() and typing(self)) then return original(self, dt, ...) end
        local blink = self.blink
        for pass = 1, 8 do
          if pass > 1 and (self.scrollPx or not typing(self)) then break end
          self.charTimer = (self.charTimer or 0) + BOOST
          original(self, dt, ...)
          self.charTimer = 0
        end
        if blink then self.blink = (blink + 1) % 480 end
      end
    end)

    if generation == 1 then
      local BattleState = require("src.battle.BattleState")
      bridge(BattleState, "updateQueue", function(original)
        return function(self, ...)
          local cur = type(self.shown) == "table" and self.shown[#self.shown]
          local boost = enabled() and self.current and not self.msgWaiting
            and not self.waitingUI and not self.waitingSound and not self.draining
            and not self.animPlaying and (self.waitFrames or 0) <= 0
            and type(cur) == "table" and type(self.codes) == "table"
            and #cur < #self.codes
          if not boost then return original(self, ...) end
          self.charTimer = (self.charTimer or 0) + BOOST
          local result = original(self, ...)
          self.charTimer = 0
          return result
        end
      end)
    else
      local Typer = require("src.ui.gen2.Typer")
      bridge(Typer, "delay", function(original)
        return function(self, ...)
          if enabled() then return 0 end
          return original(self, ...)
        end
      end)
    end
  end

  mod.hooks:wrap(HOOK, function() return true end)
end
