-- Instant Text: every text printer reveals the current page (or the segment up
-- to the next scripted pause) at once. Prompts, page breaks, choices and timed
-- pauses keep their native behavior.
--
-- gen1recomp 0.3.96 has no text-speed hook, so each printer gets one
-- idempotent bridge that asks the mod-owned hook HOOK. The loader removes that
-- hook on rollback/reset, which turns every bridge back into a pass-through.
-- Save data and options are never written.
-- The logic lives in the bundled `text_speed` lib (lib/text_speed/); this file only wires it.
return function(mod)
  local use = assert(load(assert(mod:read("lib/init.lua"), "missing lib/init.lua"), "@lib/init.lua"))(mod)
  use("text_speed").install(mod)
end
