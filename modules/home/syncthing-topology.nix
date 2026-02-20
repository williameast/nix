# Syncthing topology - single source of truth
#
# Architecture: hub-and-spoke with milo as hub
#
# Security model:
#   - Spokes (orr, yossarian, phone) only connect to milo
#   - ultracc only connects to milo (untrusted external seedbox)
#   - ultracc cannot reach orr, yossarian, or phone
#   - milo is the security boundary and ingress point for all external data
#
{ lib }:

let
  hub = "milo";

  machines = {
    orr = {
      deviceId = "6CAAUBX-ZWSS2NP-UB24GXN-376QXI3-XLGYUEU-X6MP2TQ-GBZRKDJ-EKAOIAT";
      addresses = [ "tcp://orr:22000" "dynamic" ];
    };
    yossarian = {
      deviceId = "KYPSGOI-6NG3XBG-ASF7CGR-AQAYK3B-JWVUGBU-2G7WQUL-GZKHB4X-RIIDDQK";
      addresses = [ "tcp://yossarian:22000" "dynamic" ];
    };
    milo = {
      deviceId = "KIX2RRT-YL2HLDC-AOSS2IZ-HC3ZGA6-7LYME6W-MIOLC27-ZLGYIQ2-UKUETQA";
      addresses = [ "tcp://milo:22000" "dynamic" ];
    };
    phone = {
      deviceId = "4P2OO2I-P2GZBL3-LDXC743-DEYLFU5-GQPKE4H-MORB7DG-2T237QG-3SHP4QZ";
      # No fixed address - discovers milo via relay
    };
    ultracc = {
      deviceId = "SJ5NHJ6-B277L5B-UYSFSOF-VQO3N4E-6OG2NK4-VAPWPMF-OGZJFIR-DZEVFAP";
      addresses = [ "tcp://apoc-direct.usbx.me:18918" ];
      # External seedbox: only ever connects to milo, never to spokes
    };
  };

  # Shared folders.
  # Each folder declares which machines participate.
  # Security constraint: any folder including ultracc must also include milo.
  # Spokes reach ultracc indirectly via milo - they never know ultracc exists.
  sharedFolders = {

    # Personal notes and org files - all trusted devices
    org = {
      path = "org";
      devices = [ "orr" "yossarian" "milo" "phone" ];
    };

    # Torrent watch folder: drop a .torrent on any machine, milo forwards to ultracc.
    # On ultracc: configure as Receive Only, path = torrent client watch folder.
    torrent-metainfo = {
      path = "torrentfiles";
      devices = [ "orr" "yossarian" "milo" "ultracc" ];
      patterns = [
        "!*.torrent"  # Whitelist: only sync .torrent files
        "*"           # Exclude everything else
      ];
    };

    # Media ingress from ultracc → milo. Spokes access media via Jellyfin/Navidrome.
    # On ultracc: configure as Send Only.
    music-staging = {
      path = "staging/music";
      devices = [ "ultracc" "milo" ];
      pathOverrides.milo = "/mnt/vault-new/staging/music";
    };
    tv-shows = {
      path = "tv-shows";
      devices = [ "ultracc" "milo" ];
      pathOverrides.milo = "/mnt/vault-new/tv-shows";
      # On ultracc: path = ~/media/TV Shows
    };
    movies = {
      path = "movies";
      devices = [ "ultracc" "milo" ];
      pathOverrides.milo = "/mnt/vault-new/movies";
      # On ultracc: path = ~/media/Movies
    };
    program-staging = {
      path = "staging/programs";
      devices = [ "ultracc" "milo" ];
      pathOverrides.milo = "/mnt/vault-new/staging/programs";
    };
    misc = {
      path = "misc";
      devices = [ "ultracc" "milo" ];
      pathOverrides.milo = "/mnt/vault-new/misc";
    };
  };

  # Returns the direct sync peers for a given hostname and folder.
  # Hub: connects directly to all other participants.
  # Spokes: connect only to hub, routing all traffic through it.
  # This enforces the security boundary - spokes never see ultracc.
  getFolderPeers = hostname: folderName:
    let
      participants = (sharedFolders.${folderName}).devices or [];
    in
      if !(builtins.elem hostname participants) then
        []
      else if hostname == hub then
        lib.filter (d: d != hub) participants
      else if builtins.elem hub participants then
        [ hub ]
      else
        [];

  # Returns all devices a host needs in its Syncthing device config.
  # Spokes only need to know about the hub.
  # Hub needs all its direct peers across every folder.
  getKnownDevices = hostname:
    if hostname == hub then
      lib.unique (lib.flatten (
        lib.mapAttrsToList (folderName: _:
          getFolderPeers hub folderName
        ) sharedFolders
      ))
    else
      [ hub ];

  # Build complete Syncthing config for a host: devices, folders, tmpfiles.
  buildSyncthingConfig = { hostname, homeDir }:
    let
      devices = lib.listToAttrs (map (name: {
        name = name;
        value = { id = machines.${name}.deviceId; }
          // lib.optionalAttrs (machines.${name} ? addresses) {
            addresses = machines.${name}.addresses;
          };
      }) (getKnownDevices hostname));

      relevantFolders = lib.filterAttrs (folderName: _:
        getFolderPeers hostname folderName != []
      ) sharedFolders;

      folders = lib.mapAttrs (folderName: folderConfig: {
        path = folderConfig.pathOverrides.${hostname} or "${homeDir}/${folderConfig.path}";
        devices = getFolderPeers hostname folderName;
        ignorePerms = folderConfig.ignorePerms or false;
        type = folderConfig.type or "sendreceive";
      } // lib.optionalAttrs (folderConfig ? patterns) {
        ignorePatterns = folderConfig.patterns;
      }) relevantFolders;

      # Use "-" for user/group: systemd-tmpfiles --user runs as the current user
      # and cannot chown; the directory will be owned by whoever creates it.
      tmpfiles = lib.mapAttrsToList (_: folderConfig:
        "d ${folderConfig.pathOverrides.${hostname} or "${homeDir}/${folderConfig.path}"} 0755 - - -"
      ) relevantFolders;

    in {
      inherit devices folders tmpfiles;
    };

in {
  inherit hub machines sharedFolders buildSyncthingConfig;
}
