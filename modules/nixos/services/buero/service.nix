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
  ]);

  buero = pkgs.stdenv.mkDerivation {
    pname   = "buero";
    version = "1.0.0";
    src     = bueroSrc;

    nativeBuildInputs = [ pkgs.makeWrapper ];
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/{bin,lib/buero}
      cp app.py $out/lib/buero/
      cp -r templates static pdf_templates $out/lib/buero/
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
      BUERO_HOST     = "127.0.0.1";
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

  networking.firewall.allowedTCPPorts = [ 5055 ];
}
