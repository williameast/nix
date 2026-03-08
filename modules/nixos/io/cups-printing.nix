# CUPS printing server for network receipt printing
# Configured for Epson TM-T88V receipt printer on milo
{ config, pkgs, lib, ... }:

{
  # Enable CUPS printing service
  services.printing = {
    enable = true;

    # Listen on all interfaces for network printing
    listenAddresses = [ "*:631" ];

    # Allow network printing from LAN
    allowFrom = [ "all" ];
    browsing = true;
    defaultShared = true;

    # Enable web interface
    webInterface = true;

    # Drivers for Epson ESC/POS printers
    # NOTE: TM-T88V works as raw queue since scripts generate ESC/POS directly
    drivers = [ pkgs.cups-filters ];

    # Extra configuration for raw queue support
    extraConf = ''
      # Allow raw printing (for ESC/POS commands)
      FileDevice Yes

      # Set default paper size (80mm thermal roll)
      DefaultPaperSize Custom.80x297mm

      # Enable sharing
      <Location />
        Order allow,deny
        Allow all
      </Location>

      <Location /admin>
        Order allow,deny
        Allow all
      </Location>

      <Location /admin/conf>
        AuthType Default
        Require user @SYSTEM
        Order allow,deny
        Allow all
      </Location>
    '';
  };

  # Avahi for printer discovery (advertises printer on LAN)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # Open firewall for CUPS/IPP
  networking.firewall = {
    allowedTCPPorts = [
      631   # IPP (Internet Printing Protocol)
    ];
    allowedUDPPorts = [
      631   # IPP discovery
      5353  # mDNS for Avahi
    ];
  };

  # Add user to lpadmin group for printer administration
  users.users.weast.extraGroups = [ "lpadmin" ];

  # Script to set up Epson TM-T88V printer
  # Run manually after rebuild: sudo setup-tm-t88v
  environment.systemPackages = with pkgs; [
    cups
    (pkgs.writeScriptBin "setup-tm-t88v" ''
      #!/usr/bin/env bash
      set -e

      echo "Detecting Epson TM-T88V USB printer..."

      # Find USB printer device
      DEVICE=$(lpinfo -v | grep -i "usb.*EPSON.*TM-T88" | head -n1 | awk '{print $2}')

      if [ -z "$DEVICE" ]; then
        echo "Error: Epson TM-T88V not found on USB"
        echo "Available devices:"
        lpinfo -v
        exit 1
      fi

      echo "Found printer at: $DEVICE"

      # Check if printer already exists
      if lpstat -p EPSON_TM-T88V 2>/dev/null; then
        echo "Printer EPSON_TM-T88V already configured"
        echo "To reconfigure, run: lpadmin -x EPSON_TM-T88V"
        exit 0
      fi

      # Add printer as raw queue (no driver - accepts ESC/POS directly)
      echo "Adding printer as raw queue..."
      lpadmin -p EPSON_TM-T88V \
        -v "$DEVICE" \
        -m raw \
        -o printer-is-shared=true \
        -E

      echo "Printer EPSON_TM-T88V configured successfully!"
      echo ""
      echo "Test printing from this machine:"
      echo "  echo 'Test' | lp -d EPSON_TM-T88V"
      echo ""
      echo "Print from network (other machines):"
      echo "  lp -h milo.local:631 -d EPSON_TM-T88V receipt.prn"
    '')
  ];
}
