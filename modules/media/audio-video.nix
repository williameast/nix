# Audio and video applications
{ config, pkgs, lib, ... }:

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
  ];
}
