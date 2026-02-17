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
    # orr = {
    #   deviceId = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
    #   managed = true;  # TODO: Get real device ID from orr
    # };
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
      deviceId = "4P2OO2I-P2GZBL3-LDXC743-DEYLFU5-GQPKE4H-MORB7DG-2T237QG-3SHP4QZ";
      managed = false;
    };
    ultracc = {
      deviceId = "SJ5NHJ6-B277L5B-UYSFSOF-VQO3N4E-6OG2NK4-VAPWPMF-OGZJFIR-DZEVFAP";
      addresses = [ "tcp://apoc-direct.usbx.me:18918" ];
      managed = false;  # Manually configured on website
    };
  };

  # Define folders that should be synced across all machines
  # Use 'devices' to override which devices get this folder (optional)
  # Use 'pathOverrides' to specify absolute paths for specific machines
  sharedFolders = {
    org = {
      path = "org";  # Default: relative to home directory
      ignorePerms = false;
      devices = [ "yossarian" "milo" "phone" ];
      pathOverrides = {};  # All machines use default ~/org
    };
    # Torrent metainfo files (.torrent) - sync TO ultracc for downloading
    torrent-metainfo = {
      path = "torrentfiles";
      ignorePerms = false;
      devices = [ "yossarian" "milo" "ultracc" ];  # TODO: Add orr when we have its device ID
      pathOverrides = {};  # All use default ~/torrentfiles

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

    # Staging folders - send/receive between ultracc and milo
    # Media arrives from ultracc, gets sorted/archived on milo
    music-staging = {
      path = "staging/music";
      ignorePerms = false;
      devices = [ "ultracc" "milo" ];
      pathOverrides = {
        milo = "/mnt/vault-new/staging/music";
      };
    };
    tv-shows = {
      path = "tv-shows";
      ignorePerms = false;
      devices = [ "ultracc" "milo" ];
      pathOverrides = {
        milo = "/mnt/vault-new/tv-shows";
      };
      # NOTE: On ultracc, manually set path to ~/media/TV Shows
    };
    movies = {
      path = "movies";
      ignorePerms = false;
      devices = [ "ultracc" "milo" ];
      pathOverrides = {
        milo = "/mnt/vault-new/movies";
      };
      # NOTE: On ultracc, manually set path to ~/media/Movies
    };
    program-staging = {
      path = "staging/programs";
      ignorePerms = false;
      devices = [ "ultracc" "milo" ];
      pathOverrides = {
        milo = "/mnt/vault-new/staging/programs";
      };
    };
    misc = {
      path = "misc";
      ignorePerms = false;
      devices = [ "ultracc" "milo" ];
      pathOverrides = {
        milo = "/mnt/vault-new/misc";
      };
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

      # Collect all devices mentioned in folder device lists
      # This ensures spokes know about non-hub devices when folders require it
      foldersDevices = lib.unique (lib.flatten (
        lib.mapAttrsToList (name: cfg:
          cfg.devices or []
        ) sharedFolders
      ));

      # Base topology devices
      baseDevices =
        if hubAndSpoke then
          if hostname == hub then
            otherMachines  # Hub knows about everyone
          else
            [ hub ]  # Spokes know about hub
        else
          otherMachines;  # Full-mesh: everyone knows everyone

      # Combine base topology with folder-specific devices, excluding self
      allNeededDevices = lib.unique (baseDevices ++ foldersDevices);
      validDevices = lib.filter (d: d != hostname && builtins.hasAttr d machines) allNeededDevices;
    in
      validDevices;

  # Helper function: Build complete syncthing configuration for a host
  # Returns { devices, folders, tmpfiles } ready to use
  buildSyncthingConfig = { hostname, homeDir }:
    let
      # Get devices this host should know about
      knownDevices = getDevicesForHost hostname;

      # Build device configuration
      devices = lib.listToAttrs (map (name: {
        name = name;
        value = { id = machines.${name}.deviceId; }
          // lib.optionalAttrs (machines.${name} ? addresses) {
            addresses = machines.${name}.addresses;
          };
      }) knownDevices);

      # Build folder configuration with path resolution
      folders = lib.mapAttrs (folderName: folderConfig: {
        # Use override if exists, otherwise default to homeDir/path
        path = folderConfig.pathOverrides.${hostname} or "${homeDir}/${folderConfig.path}";
        devices = getDevicesForFolder hostname folderName;
        ignorePerms = folderConfig.ignorePerms;
        type = folderConfig.type or "sendreceive";
      } // lib.optionalAttrs (folderConfig ? patterns) {
        ignorePatterns = folderConfig.patterns;
      }) sharedFolders;

      # Build tmpfiles rules for folder creation
      tmpfiles = lib.mapAttrsToList (folderName: folderConfig:
        let
          folderPath = folderConfig.pathOverrides.${hostname} or "${homeDir}/${folderConfig.path}";
        in
          "d ${folderPath} 0755 weast users -"
      ) (lib.filterAttrs (name: cfg:
        # Only include folders this host syncs
        builtins.elem hostname (getDevicesForFolder hostname name)
      ) sharedFolders);
    in {
      inherit devices folders tmpfiles;
    };

in {
  inherit hubAndSpoke hub machines sharedFolders
          getDevicesForHost getDevicesForFolder
          buildSyncthingConfig;
}
