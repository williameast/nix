# Free-to-air IPTV for Jellyfin Live TV, built from iptv-org (https://github.com/iptv-org/iptv)
#
# iptv-playlist (daily) downloads iptv-org's channel and stream database,
# takes the channels listed below, and for each one picks a stream that isn't
# geo-blocked, needs no special headers, and actually answers from milo. The
# result is /var/lib/iptv/channels.m3u, which Jellyfin uses as an M3U tuner
# (Dashboard → Live TV; set up once via the Jellyfin API, stored in Jellyfin).
#
# Pay channels (Sky, TNT, DAZN, HBO, TCM…) are deliberately not listed: their
# iptv-org entries are usually unofficial relays.
#
# To add a channel: find its id at https://iptv-org.github.io (e.g. "More4.uk")
# and add it to a group below.
{ config, pkgs, lib, ... }:

let
  groups = {
    "UK" = [
      "BBCOne.uk" "BBCTwo.uk" "BBCThree.uk" "BBCFour.uk" "BBCNews.uk" "BBCScotland.uk"
      "BBCAlba.uk" "CBBC.uk" "CBeebies.uk" "Channel4.uk" "More4.uk" "E4.uk" "Channel5.uk"
      "5USA.uk" "ITV2.uk" "ITV3.uk" "ITV4.uk" "Really.uk" "Quest.uk" "TogetherTV.uk"
      "PBSAmerica.uk" "GBNews.uk" "TalkTV.uk" "ThatsTV.uk" "HistoryHit.uk" "TrueCrime.uk"
      "TopGear.uk" "TheGrahamNortonShow.uk"
    ];
    "Classic films" = [
      "TalkingPicturesTV.uk" "GREATmovies.uk" "GREATromance.uk" "TVSClassicMovies.us"
      "TVSFilmNoirNetwork.us" "TVSNostalgiaMovies.us" "TVSWesternMovie.us" "ClassicCinema.us"
      "ClassicMoviesChannel.us" "ARTFLIXMovieClassics.us" "30ATVClassicMovies.us"
      "PlutoTVCultFilms.us" "PlutoTVWesterns.us" "ClassicMovieWesterns.us" "ShoutFactoryTV.us"
      "FilmRiseWestern.us" "Runtime.us" "70sCinema.us"
    ];
    "Arthouse" = [
      "arte.de" "PlutoTVCinedeautor.de" "CINDIETV.br" "GravitasMovies.us" "ClassicArtsShowcase.us"
    ];
  };

  stateDir = "/var/lib/iptv";

  build = pkgs.writeScript "iptv-playlist" ''
    #!${pkgs.python3}/bin/python3
    import concurrent.futures, json, os, urllib.request

    GROUPS = json.loads(${builtins.toJSON (builtins.toJSON groups)})
    OUT = "${stateDir}/channels.m3u"
    API = "https://iptv-org.github.io/api"
    QUALITY = {"2160p": 5, "1080p": 4, "720p": 3, "576p": 2, "480p": 1}


    def get(name):
        with urllib.request.urlopen(f"{API}/{name}.json", timeout=120) as r:
            return json.load(r)


    def plays(url):
        """True if the stream answers with something that looks like video or a playlist."""
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                head = r.read(4096)
            return r.status == 200 and (head.startswith(b"#EXTM3U") or head[:1] == b"G" or len(head) > 1000)
        except Exception:
            return False


    channels = {c["id"]: c for c in get("channels")}
    logos = {}
    for l in get("logos"):
        logos.setdefault(l["channel"], l["url"])
    streams = {}
    for s in get("streams"):
        if (s.get("channel") and "Geo-blocked" not in (s.get("labels") or [])
                and not s.get("user_agent") and not s.get("referrer")):
            streams.setdefault(s["channel"], []).append(s)


    def pick(cid):
        cands = sorted(streams.get(cid, []), key=lambda s: (
            "Not 24/7" in (s.get("labels") or []), -QUALITY.get(s.get("quality") or "", 0)))
        return next((s for s in cands if plays(s["url"])), None)


    wanted = [(g, cid) for g, ids in GROUPS.items() for cid in ids]
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        chosen = list(pool.map(lambda w: pick(w[1]), wanted))

    lines, missing = ["#EXTM3U"], []
    for (group, cid), s in zip(wanted, chosen):
        name = channels.get(cid, {}).get("name", cid)
        if not s:
            missing.append(name)
            continue
        logo = logos.get(cid, "")
        lines.append(f'#EXTINF:-1 tvg-id="{cid}" tvg-name="{name}" tvg-logo="{logo}" group-title="{group}",{name}')
        lines.append(s["url"])
    tmp = OUT + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.replace(tmp, OUT)
    print(f"{(len(lines) - 1) // 2} of {len(wanted)} channels working; no working stream: {', '.join(missing) or 'none'}")
  '';
in
{
  systemd.services.iptv-playlist = {
    description = "Build the Jellyfin IPTV playlist from iptv-org";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${build}";
      User = "jellyfin";
      Group = "jellyfin";
      StateDirectory = "iptv";
    };
  };

  systemd.timers.iptv-playlist = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      OnBootSec = "5min";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };
}
