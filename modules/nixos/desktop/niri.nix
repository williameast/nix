# NixOS-level configuration for Niri compositor
{ config, pkgs, lib, ... }:

{
  # Enable Niri
  programs.niri.enable = true;

  # Required services for Wayland compositors
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # Enable XDG portal for screen sharing, etc.
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Enable sound
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  # Fonts
  fonts.packages = with pkgs; [
    inter
    noto-fonts
    noto-fonts-color-emoji
    font-awesome
  ];
}
