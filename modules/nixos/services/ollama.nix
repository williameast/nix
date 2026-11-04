# Ollama - local LLMs on orr's RX 7600 XT (16 GB VRAM), via Vulkan
#
# Listens on all interfaces but no firewall port is opened, so only the
# tailnet can reach it (tailscale0 is trusted). milo fronts it with a
# wake-on-demand proxy: ./orr-llm.nix
#
# Models download on first start (ollama-model-loader.service); check with
# `ollama list`. Sizes at Q4: qwen3:14b ~9 GB, gpt-oss:20b ~14 GB.
{ config, pkgs, lib, ... }:

{
  services.ollama = {
    enable = true;
    # Vulkan needs no ROCm stack and is reliable on RDNA3 (gfx1102)
    package = pkgs.ollama-vulkan;
    host = "0.0.0.0";
    port = 11434;

    loadModels = [
      "qwen3:14b"
      "gpt-oss:20b"
    ];

    environmentVariables = {
      # Keep a model in VRAM between requests from milo (default 5m)
      OLLAMA_KEEP_ALIVE = "30m";
      # Default is 4k; flash attention + q8 KV cache keep 16k affordable
      OLLAMA_CONTEXT_LENGTH = "16384";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
  };

  # Keep orr awake while Ollama has a model loaded (i.e. while serving milo and
  # for OLLAMA_KEEP_ALIVE afterwards), so hypridle's 30-minute suspend can't cut
  # off a nightly batch. Once the model unloads, orr may sleep again.
  systemd.services.ollama-sleep-guard = {
    description = "Block sleep while Ollama has a model loaded";
    after = [ "ollama.service" ];
    wantedBy = [ "ollama.service" ];
    path = [ pkgs.curl pkgs.jq pkgs.systemd pkgs.coreutils ];
    script = ''
      guard=""
      while true; do
        loaded=$(curl -sf -m 5 http://127.0.0.1:${toString config.services.ollama.port}/api/ps \
          | jq '.models | length' 2>/dev/null || echo 0)
        if [ "''${loaded:-0}" -gt 0 ] && [ -z "$guard" ]; then
          systemd-inhibit --what=sleep:idle --who=ollama --why="LLM model loaded" sleep infinity &
          guard=$!
        elif [ "''${loaded:-0}" -eq 0 ] && [ -n "$guard" ]; then
          kill "$guard"; guard=""
        fi
        sleep 30
      done
    '';
    serviceConfig.Restart = "always";
  };

  # Wake-on-LAN (magic packet = 64) on wired connections, so milo can boot
  # orr. Set via NetworkManager rather than networking.interfaces.*.wakeOnLan:
  # that adds a .link file to the initrd, and orr's 96 MB ESP (shared with
  # Windows) can't hold a second initrd.
  networking.networkmanager.settings.connection."ethernet.wake-on-lan" = 64;
}
