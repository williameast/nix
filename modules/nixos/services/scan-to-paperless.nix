# Scan-to-Paperless: the Brother DCP-L2520DW's "Scan" button drops PDFs into
# Paperless' consume dir. No PC, no scanner GUI.
#
# How it works:
#   brscan-skey (Brother's button daemon) registers milo with the printer via
#   SNMP. Pressing Scan on the printer then sends a UDP event to milo:54925 and
#   brscan-skey runs scan-page, which scans one page into a batch dir. The
#   scan-batcher service merges a batch into one PDF and hands it to Paperless.
#
# On the printer: Scan → pick a function → pick "milo" → Start
#   Scan to Image         scan this page, submit the document NOW
#                         (single receipt, or the last page of a multi-page doc)
#   Scan to File/OCR/Email  add this page to the current document; it is
#                         submitted automatically after ${toString idleSeconds}s without a new page
#
# Requires modules/nixos/services/scanning.nix (brscan4 net device config) and
# paperless-ngx.nix. Logs: journalctl -u brscan-skey -u scan-batcher
{ config, pkgs, lib, ... }:

let
  idleSeconds = 120;  # quiet time after the last page before a batch is submitted
  device = "brother4:net1;dev0";  # fallback if brscan-skey doesn't pass one
  stateDir = "/var/lib/scan-to-paperless";
  batchDir = "${stateDir}/batch";
  consumeDir = config.services.paperless.consumptionDir;

  # Brother's binary-only daemon. Hardcodes /opt/brother/scanner/brscan-skey,
  # so the service bind-mounts it there (see BindReadOnlyPaths below).
  brscan-skey = pkgs.stdenv.mkDerivation rec {
    pname = "brscan-skey";
    version = "0.3.4-0";
    src = pkgs.fetchurl {
      url = "https://download.brother.com/welcome/dlf006652/brscan-skey-${version}.amd64.deb";
      sha256 = "14d8rvsq8w196sld8xq3rvcghmifl7f31805rnfxlpdmzgkgfq33";
    };
    nativeBuildInputs = [ pkgs.dpkg pkgs.autoPatchelfHook ];
    unpackPhase = "dpkg-deb -x $src .";
    installPhase = ''
      mkdir -p $out
      cp -r opt $out/
      # Brother's own scanimage wrapper (needs libsane) — we use sane-backends' instead
      rm $out/opt/brother/scanner/brscan-skey/skey-scanimage
    '';
    meta.license = lib.licenses.unfree;
  };

  saneEnv = {
    SANE_CONFIG_DIR = "/etc/sane-config";
    LD_LIBRARY_PATH = "/etc/sane-libs";
  };

  # Called by brscan-skey as: scan-page <now|batch> "<sane device>" ...
  scanPage = pkgs.writeShellScript "scan-page" ''
    set -uo pipefail
    mode=$1
    dev=''${2:-${device}}
    echo "button: mode=$mode args=''${*:2}"

    part="${batchDir}/.page-$(date +%s%N).jpg.part"
    scan() {
      ${pkgs.sane-backends}/bin/scanimage --device-name "$dev" \
        --mode "24bit Color[Fast]" --resolution 300 -x 210 -y 297 \
        --format=jpeg --output-file "$part"
    }
    # Brother's own scripts wait a moment and retry once for network scanners
    sleep 1
    scan || { sleep 2; scan; } || { echo "scan failed" >&2; rm -f "$part"; exit 1; }

    page="''${part%.part}"
    page="${batchDir}/page-''${page#${batchDir}/.page-}"
    mv "$part" "$page"
    echo "scanned $page"
    [ "$mode" = now ] && touch "${batchDir}/submit"
    exit 0
  '';

  skeyConfig = pkgs.writeText "brscan-skey.config" ''
    password=
    IMAGE="${scanPage} now"
    OCR="${scanPage} batch"
    EMAIL="${scanPage} batch"
    FILE="${scanPage} batch"
    SEMID=b
  '';

  # Merges batched pages into one PDF once a batch is submitted or goes idle.
  batcher = pkgs.writeShellScript "scan-batcher" ''
    set -uo pipefail
    shopt -s nullglob
    while sleep 5; do
      # Claim the submit marker before listing pages: scan-page writes the page
      # first, so every page belonging to this submit is already present.
      submit=0
      mv "${batchDir}/submit" "${batchDir}/.submit" 2>/dev/null && submit=1
      pages=("${batchDir}"/page-*.jpg)
      if (( ''${#pages[@]} == 0 )); then rm -f "${batchDir}/.submit"; continue; fi

      newest=$(stat -c %Y "''${pages[-1]}")
      if (( !submit && $(date +%s) - newest < ${toString idleSeconds} )); then continue; fi

      name="scan-$(date +%Y-%m-%d_%H-%M-%S)"
      # .part isn't a type Paperless consumes; the rename makes it pick the file up
      if ${pkgs.img2pdf}/bin/img2pdf --pagesize A4 -o "${consumeDir}/$name.pdf.part" "''${pages[@]}" \
         && mv "${consumeDir}/$name.pdf.part" "${consumeDir}/$name.pdf"; then
        echo "submitted $name.pdf (''${#pages[@]} pages)"
        rm -f "''${pages[@]}"
      else
        echo "failed to build $name.pdf, moving pages to ${stateDir}/failed" >&2
        rm -f "${consumeDir}/$name.pdf.part"
        mkdir -p "${stateDir}/failed"
        mv "''${pages[@]}" "${stateDir}/failed/"
      fi
      rm -f "${batchDir}/.submit"
    done
  '';

  serviceUser = config.services.paperless.user;  # so consumed files belong to paperless
in
{
  systemd.tmpfiles.rules = [
    "d ${batchDir} 0750 ${serviceUser} ${serviceUser} -"
  ];

  systemd.services.brscan-skey = {
    description = "Brother scan button daemon (scan to Paperless)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = with pkgs; [ bash coreutils hostname curl ];
    environment = saneEnv // { HOME = stateDir; };

    serviceConfig = {
      ExecStart = "${brscan-skey}/opt/brother/scanner/brscan-skey/brscan-skey-exe -f";
      User = serviceUser;
      StateDirectory = "scan-to-paperless";
      Restart = "on-failure";
      RestartSec = "10s";
      PrivateTmp = true;  # it keeps lock files in /tmp; start clean every time
      TemporaryFileSystem = "/opt:ro";
      BindReadOnlyPaths = [
        "${brscan-skey}/opt/brother/scanner/brscan-skey:/opt/brother/scanner/brscan-skey"
        "${skeyConfig}:/opt/brother/scanner/brscan-skey/brscan-skey.config"
        "${pkgs.brscan4}/opt/brother/scanner/brscan4:/opt/brother/scanner/brscan4"
      ];
    };
  };

  systemd.services.scan-batcher = {
    description = "Merge scanned pages into PDFs for Paperless";
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = [ consumeDir ];
    serviceConfig = {
      ExecStart = "${batcher}";
      User = serviceUser;
      StateDirectory = "scan-to-paperless";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  # The printer sends button events to this port
  networking.firewall.allowedUDPPorts = [ 54925 ];
}
