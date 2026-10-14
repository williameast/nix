{ config, pkgs, lib, ... }:

let
  bueroSrc = builtins.path { path = ./.; name = "buero-src"; };

  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    flask
    pyyaml
    requests
    weasyprint
    jinja2
    werkzeug
    qrcode
    pillow
    pypdf
    anthropic
  ]);

  buero = pkgs.stdenv.mkDerivation {
    pname   = "buero";
    version = "1.0.0";
    src     = bueroSrc;

    nativeBuildInputs = [ pkgs.makeWrapper ];
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/{bin,lib/buero}
      cp *.py $out/lib/buero/
      cp -r templates static pdf_templates $out/lib/buero/
      # CI typeface, used by the web UI and embedded in invoice PDFs
      mkdir -p $out/lib/buero/static/fonts
      for w in Regular Italic Medium SemiBold Bold BoldItalic; do
        cp ${pkgs.poppins}/share/fonts/truetype/Poppins-$w.ttf $out/lib/buero/static/fonts/
      done
      makeWrapper ${pythonEnv}/bin/python $out/bin/buero \
        --add-flags "$out/lib/buero/app.py" \
        --set BUERO_APP_DIR "$out/lib/buero"
    '';
  };

  dataDir = "/mnt/vault-new/buero";

in {
  systemd.services.buero = {
    description = "Büro — freelance management";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" ];

    environment = {
      BUERO_DATA_DIR = dataDir;
      BUERO_HOST     = "0.0.0.0";
      BUERO_PORT     = "5055";
    };

    serviceConfig = {
      ExecStart        = "${buero}/bin/buero";
      User             = "buero";
      Group            = "buero";
      Restart          = "on-failure";
      RestartSec       = "5s";

      # Note: namespace-based hardening (ProtectSystem, PrivateTmp, etc.)
      # is omitted — milo runs as an LXC container which doesn't support them.
      NoNewPrivileges  = true;
    };
  };

  users.users.buero = {
    isSystemUser = true;
    group        = "buero";
    description  = "Büro service user";
  };

  users.groups.buero = {};

  systemd.tmpfiles.rules = [
    "d '${dataDir}'                0750 buero buero -"
    "d '${dataDir}/data'           0750 buero buero -"
    "d '${dataDir}/data/clients'   0750 buero buero -"
    "d '${dataDir}/data/invoices'  0750 buero buero -"
    "d '${dataDir}/data/expenses'  0750 buero buero -"
    "d '${dataDir}/data/projects'  0750 buero buero -"
    "d '${dataDir}/uploads'        0750 buero buero -"
  ];

}
