# `phonetic-rescue`: re-transcribe the last Phonetic recording
# (/tmp/phonetic_debug.wav) after a failed transcription, using Phonetic's own
# config and transcribe(). Needs the phonetic overlay (pkgs.phonetic).
# See FIXES.md "phonetic-long-recording-429".
{ pkgs, ... }:
let
  python = pkgs.python312.withPackages (ps: [
    (ps.toPythonModule pkgs.phonetic)
    ps.httpx
    ps.numpy
    ps.python-dotenv
    ps.soundfile
  ]);
in
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "phonetic-rescue";
      runtimeInputs = with pkgs; [
        ffmpeg-headless # transcribe() encodes the payload as MP3
        wl-clipboard
      ];
      text = ''exec ${python}/bin/python ${./phonetic_rescue.py} "$@"'';
    })
  ];
}
