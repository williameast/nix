# Audio and video applications
{ config, pkgs, lib, ... }:

let
  # Resolve bundles its own Qt5 without the wayland platform plugin, so it
  # aborts when QT_QPA_PLATFORM=wayland (set by hyprland). Force XWayland.
  davinci-resolve = pkgs.symlinkJoin {
    name = "davinci-resolve";
    paths = [ pkgs.davinci-resolve ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/davinci-resolve --set QT_QPA_PLATFORM xcb
    '';
  };
in
{
  home.packages = with pkgs; [
    # Audio
    flac
    ft2-clone # FastTracker II clone
    audacity

    # Video
    vlc
    yt-dlp
    ffmpeg
    davinci-resolve
    kdePackages.kdenlive
    losslesscut-bin
  ];
}
