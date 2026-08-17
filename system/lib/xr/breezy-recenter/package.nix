{ writeShellApplication }:

# Recenter the XR pose by writing the IPC control flag the xr-driver polls.
# Path + key match XRLinuxDriver src/state.c:
#   state_files_directory = "/dev/shm"
#   control_flags_filename = "xr_driver_control"
#   recognized: recenter_screen=true|false (single-shot, daemon clears it)
#
# Bound to Super+R in both compositors via system/lib/xr/breezy-session
# (GNOME custom-keybinding) and dotfiles/default/hypr/users/jorge/default/breezy.conf.
writeShellApplication {
  name = "breezy-recenter";
  text = ''
    printf 'recenter_screen=true\n' > /dev/shm/xr_driver_control
  '';
}
