-- Palette is required directly by the files that use it, so it no longer
-- needs sourcing here the way startino-neptune.conf did.

-- shared/themes/default/**
require("shared/themes/default/animation")
require("shared/themes/default/border")
require("shared/themes/default/decoration")
require("shared/themes/default/env")
require("shared/themes/default/transparency")

-- shared/workflow/default/**  (the .conf `**` glob did NOT recurse into binds/)
require("shared/workflow/default/master")
require("shared/workflow/default/startup")

-- keymap
require("shared/workflow/default/binds/voyager2H")

-- shared/utility/**
require("shared/utility/cursor")
require("shared/utility/dwindle")
require("shared/utility/general")
require("shared/utility/layerrules")
require("shared/utility/misc")
require("shared/utility/monitor")
require("shared/utility/workspace")

