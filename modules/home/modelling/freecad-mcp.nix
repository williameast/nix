# FreeCAD MCP (spkane/freecad-addon-robust-mcp-server): lets Claude drive FreeCAD.
#
# Two halves from the same pinned source:
# - "Robust MCP Bridge" workbench in FreeCAD, which serves XML-RPC on
#   localhost:9875. Start it from the workbench toolbar ("Start MCP Bridge"),
#   or tick auto-start in its preferences.
# - `freecad-mcp`, the MCP server Claude Desktop and Claude Code launch; it
#   talks to the bridge, so FreeCAD must be running with the bridge started.
#
# To update: bump `version`, then
#   nix-prefetch-url --unpack <repo>/archive/refs/tags/robust-mcp-server-v<version>.tar.gz
#   nix hash convert --hash-algo sha256 <hash>
{ config, lib, pkgs, ... }:

let
  version = "0.6.2";
  src = pkgs.fetchFromGitHub {
    owner = "spkane";
    repo = "freecad-addon-robust-mcp-server";
    rev = "robust-mcp-server-v${version}";
    hash = "sha256-CqErPT3VtZeyuoA7GWEY7dD1rzniWdD3H1BbbIdB49Y=";
  };

  freecad-mcp = pkgs.python3Packages.buildPythonApplication {
    pname = "freecad-robust-mcp";
    inherit version src;
    pyproject = true;
    # hatch-vcs reads the version from git, which the tarball doesn't have
    env.SETUPTOOLS_SCM_PRETEND_VERSION = version;
    build-system = with pkgs.python3Packages; [ hatchling hatch-vcs ];
    dependencies = with pkgs.python3Packages; [ mcp pydantic pydantic-settings ];
    # Wants mcp>=1.29.1; nixpkgs has 1.29.0
    pythonRelaxDeps = [ "mcp" ];
    pythonImportsCheck = [ "freecad_mcp" ];
    meta.mainProgram = "freecad-mcp";
  };

  claudeDesktopConfig = "${config.xdg.configHome}/Claude/claude_desktop_config.json";
  claudeCodeConfig = "${config.home.homeDirectory}/.claude.json";
  mcpServer = {
    command = lib.getExe freecad-mcp;
    env.FREECAD_MODE = "xmlrpc";
  };
in
{
  home.packages = [ freecad-mcp ];

  # The workbench is a subfolder of the repo (package.xml <subdirectory>)
  home.file.".local/share/FreeCAD/Mod/FreecadRobustMCPBridge".source =
    "${src}/addon/FreecadRobustMCPBridge";

  # Claude Desktop and Claude Code both write their own state into these files,
  # so they can't be read-only symlinks; merge the server entry into each on
  # every switch instead. Claude Code's top-level mcpServers is user scope
  # (available in every project).
  home.activation.claudeFreecadMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mergeFreecadMcp() {
      local cfg="$1" server="$2" tmp
      run mkdir -p "$(dirname "$cfg")"
      [ -s "$cfg" ] || echo '{}' > "$cfg"
      tmp=$(mktemp)
      ${lib.getExe pkgs.jq} --argjson server "$server" \
        '.mcpServers.freecad = $server' "$cfg" > "$tmp"
      if [ -z "''${DRY_RUN:-}" ]; then mv "$tmp" "$cfg"; else rm "$tmp"; fi
    }
    mergeFreecadMcp ${lib.escapeShellArg claudeDesktopConfig} \
      ${lib.escapeShellArg (builtins.toJSON mcpServer)}
    mergeFreecadMcp ${lib.escapeShellArg claudeCodeConfig} \
      ${lib.escapeShellArg (builtins.toJSON (mcpServer // { type = "stdio"; }))}
  '';
}
