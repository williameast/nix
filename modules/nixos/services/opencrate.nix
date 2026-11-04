# opencrate: keeps rekordbox USB sticks (Pioneer XDJ-700, CDJ-2000NXS2,
# CDJ-3000/3000X) in sync with Navidrome playlists, and sends plays from the
# decks back to Navidrome. Plug a FAT32 stick into milo; it is mounted
# through udisks2 and shows up in the web UI.
#
# Web UI: http://milo:4590 (no login of its own: reachable over Tailscale
# only, as tailscale0 is a trusted interface and the port stays closed on
# the LAN). Source and docs: github.com/williameast/opencrate
{ config, pkgs, lib, inputs, ... }:

{
  imports = [ inputs.opencrate.nixosModules.default ];

  services.opencrate = {
    enable = true;

    # Read access to /mnt/vault-new/music (weast:users, 775). opencrate only
    # reads the library; it writes to the sticks and /var/lib/opencrate.
    musicGroup = "users";

    settings = {
      navidrome = {
        url = "http://127.0.0.1:4533";
        user = "weast";
        # No password: Navidrome trusts this header from 127.0.0.1 only
        # (ReverseProxyWhitelist below), so opencrate needs no secret.
        proxy_header = "Remote-User";
      };

      library.music_dirs = [ "/mnt/vault-new/music" ];

      # Navidrome playlist "Techno/Peak" becomes folder Techno > Peak on the stick.
      export.folder_separator = "/";

      # Plays from the decks become Navidrome scrobbles. No Last.fm or
      # ListenBrainz account is linked in Navidrome, so they stay there.
      # (If one is linked later: turn off "Send scrobbles to external
      # services" for the opencrate player in Navidrome first.)
      scrobble.forwarding_checked = true;

      # A "🎧 Stick: <name>" playlist per stick in Navidrome, showing what is
      # on it, with the last sync and a link to the web UI in its comment.
      mirror.enabled = true;

      server = {
        listen = "0.0.0.0:4590";
        public_url = "http://milo:4590";
        # Mount sticks when plugged in (milo has no desktop automounter).
        automount = true;
      };
    };
  };

  services.navidrome.settings = {
    # Lets opencrate log in as a user by naming it in the Remote-User header,
    # from milo itself only. Any program on milo could do the same; nothing
    # on the network can (checked against Navidrome 0.64).
    ReverseProxyWhitelist = "127.0.0.1/32";

    # New players report files' real paths, so opencrate reads songs straight
    # from /mnt/vault-new/music instead of downloading them. Only affects
    # players registered from now on (existing apps keep their setting).
    Subsonic.DefaultReportRealPath = true;
  };
}
