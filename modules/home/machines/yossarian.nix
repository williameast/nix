# Machine-specific configuration for yossarian (laptop)
# Intel CometLake-U GT2 integrated graphics
{ config, pkgs, lib, ... }:

{
  # Laptop-specific packages
  home.packages = with pkgs; [
    # Power management
    powertop

    # Brightness control (if needed)
    # brightnessctl
  ];

  # Laptop-specific settings can go here
  # e.g., different screen DPI, power settings, etc.
}
