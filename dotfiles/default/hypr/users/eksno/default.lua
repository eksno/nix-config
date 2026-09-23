-- Palette is required directly by the files that use it
-- (shared/themes/default/border.lua, shared/utility/general.lua), so it does
-- not need sourcing here the way startino-neptune.conf did.

-- shared/themes/default/**
require("shared/themes/default/animation")
require("shared/themes/default/border")
require("shared/themes/default/decoration")
require("shared/themes/default/env")
require("shared/themes/default/transparency")

-- shared/workflow/default/**  (note: the .conf `**` glob did NOT recurse into
-- binds/, so only these two were ever loaded here)
require("shared/workflow/default/master")
require("shared/workflow/default/startup")

-- keymap
require("shared/workflow/default/binds/dvp")

-- shared/utility/**
require("shared/utility/cursor")
require("shared/utility/dwindle")
require("shared/utility/general")
require("shared/utility/layerrules")
require("shared/utility/misc")
require("shared/utility/monitor")
require("shared/utility/workspace")

-- users/eksno/default/**
require("users/eksno/default/brightness")
require("users/eksno/default/norwegian")
require("users/eksno/default/startup")

-- Phonetic triggers
hl.bind("CTRL + ALT + r", hl.dsp.exec_cmd("phonetic --trigger r"))
hl.bind("CTRL + ALT + c", hl.dsp.exec_cmd("phonetic --trigger c"))
hl.bind("CTRL + ALT + g", hl.dsp.exec_cmd("phonetic --trigger g"))
