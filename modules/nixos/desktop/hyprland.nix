# NixOS-level configuration for Hyprland compositor
{ config, pkgs, lib, ... }:

{
  # Enable Hyprland
  programs.hyprland.enable = true;

  # Greeter - launches Hyprland session
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
        user = "greeter";
      };
    };
  };

  # Enable XDG portal for screen sharing, etc.
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };

  # GVFS (trash, network shares, MTP for Thunar)
  services.gvfs.enable = true;

  # Tumbler (thumbnail service for Thunar)
  services.tumbler.enable = true;

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
    jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
    font-awesome
    nerd-fonts.symbols-only  # Waybar icons
  ];
}
