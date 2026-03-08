{
  system,
  inputs,
  config,
  pkgs,
  ...
}:
{
  # virtual webcam
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1 '';
  environment.systemPackages = with pkgs; [
    obs-studio
  ];
}
