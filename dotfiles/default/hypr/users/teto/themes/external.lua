-- These were `exec` (not `exec-once`) in the .conf, i.e. they re-ran on every
-- config reload. A bare hl.exec_cmd() at file scope reproduces that, since the
-- file is re-evaluated on reload.
hl.exec_cmd([[gsettings set org.gnome.desktop.interface gtk-theme "dark"]])          -- for GTK3 apps
hl.exec_cmd([[gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"]]) -- for GTK4 apps

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct") -- for Qt apps
