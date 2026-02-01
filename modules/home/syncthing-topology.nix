# Syncthing topology configuration - central source of truth
# Toggle between hub-and-spoke and full-mesh by changing hubAndSpoke boolean
{ lib }:

let
  # ========== CONFIGURATION ==========
  # Set to true for hub-and-spoke (milo as central hub)
  # Set to false for full-mesh (all devices sync with each other)
  hubAndSpoke = true;

  # Define the hub (only used in hub-and-spoke mode)
  hub = "milo";

  # Define all machines in the sync network
  machines = {
    # Nix-managed hosts
    orr = {
      deviceId = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
      managed = true;  # Managed by this Nix config
    };
    yossarian = {
      deviceId = "KYPSGOI-6NG3XBG-ASF7CGR-AQAYK3B-JWVUGBU-2G7WQUL-GZKHB4X-RIIDDQK";
      managed = true;
    };
    milo = {
      deviceId = "D4PDFYN-5WQJA3W-W7E2XPG-KMBY4LZ-YACVJ2X-NHFUOWV-JZTOROP-YH7HMAD";
      managed = true;
    };

    # External devices (NOT managed by Nix - configure manually on device)
    phone = {
      # Get device ID from Syncthing app on phone: Settings -> Show device ID
      deviceId = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
      managed = false;  # Manually configured on Android
    };
    ultracc = {
      # Get device ID from ultra
      deviceId = "SJ5NHJ6-B277L5B-UYSFSOF-VQO3N4E-6OG2NK4-VAPWPMF-OGZJFIR-DZEVFAP";
      managed = false;  # Manually configured on website
    };
  };

  # Define folders that should be synced across all machines
  # Use 'devices' to override which devices get this folder (optional)
  sharedFolders = {
    org = {
      path = "org";  # Relative to home directory
      ignorePerms = false;
      devices = [ "orr" "yossarian" "milo"];
      # Syncs to all devices (default behavior)
    };
    # music = {
    #   path = "Music";
    #   ignorePerms = false;
    #   # Only sync to computers and milo (archive), not phone/ultracc
    #   devices = [ "orr" "yossarian" "milo" ];
    # };

    # Torrent metainfo files (.torrent) - sync TO ultracc for downloading
    torrent-metainfo = {
      path = "torrentfiles";
      ignorePerms = false;
      devices = [ "orr" "yossarian" "milo" "ultracc" ];

      # Only sync .torrent files (Syncthing ignore patterns)
      # Lines starting with ! are includes (whitelist mode)
      patterns = [
        "!*.torrent"  # Include .torrent files
        "*"           # Exclude everything else
      ];

      # Type for Nix-managed machines (ultracc you configure manually)
      type = "sendreceive";

      # NOTE: On ultracc (not managed by Nix), manually configure this folder:
      # - Folder ID: "torrent-metainfo" (MUST match this key exactly)
      # - Path: Set to your ultracc torrent watch folder (e.g., /home/user/watch/)
      # - Type: "Receive Only" (so ultracc only receives, doesn't send back)
      # - File Versioning: Optional, to keep removed .torrents
    };

    # Completed downloads FROM ultracc (media files)
    downloads = {
      path = "Downloads/torrents";
      ignorePerms = false;
      devices = [ "ultracc" "milo" ];

      # Ultracc sends completed downloads, milo receives and archives
      # On ultracc: set this folder to "Send Only"
      # On milo: receives everything for archival

      # NOTE: On ultracc, configure this folder to:
      # - Folder ID: "downloads" (MUST match this key)
      # - Path: Your completed downloads folder
      # - Type: "Send Only" (ultracc only sends, doesn't receive)
    };
  };

  # ========== COMPUTED VALUES (don't edit below) ==========
  # Helper function: get list of devices to sync with for a given host and folder
  getDevicesForFolder = hostname: folderName:
    let
      folder = sharedFolders.${folderName};
      allMachines = builtins.attrNames machines;
      otherMachines = lib.filter (m: m != hostname) allMachines;

      # Default topology-based device list
      topologyDevices =
        if hubAndSpoke then
          # Hub-and-spoke: only sync with hub (or all spokes if you ARE the hub)
          if hostname == hub then
            otherMachines  # Hub syncs with everyone
          else
            [ hub ]  # Spokes only sync with hub
        else
          # Full-mesh: sync with everyone
          otherMachines;

      # If folder has explicit device list, use it; otherwise use topology default
      allowedDevices = folder.devices or topologyDevices;

      # Filter to only include allowed devices AND exclude self
      validDevices = lib.filter (d: d != hostname && builtins.elem d allowedDevices) topologyDevices;
    in
      validDevices;

  # Helper function: get list of ALL devices this host should know about
  # (Used for device configuration)
  getDevicesForHost = hostname:
    let
      allMachines = builtins.attrNames machines;
      otherMachines = lib.filter (m: m != hostname) allMachines;
    in
      if hubAndSpoke then
        if hostname == hub then
          otherMachines  # Hub knows about everyone
        else
          [ hub ]  # Spokes only know about hub
      else
        otherMachines;  # Full-mesh: everyone knows everyone

in {
  inherit hubAndSpoke hub machines sharedFolders getDevicesForHost getDevicesForFolder;
}
