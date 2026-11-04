# orr-llm - milo's front door to the Ollama server on orr (./ollama.nix)
#
# Anything on milo or the tailnet talks to http://milo:11434 as if it were
# Ollama. If orr is asleep or off, the proxy sends a Wake-on-LAN packet and
# holds the connection until orr's Ollama answers (boot + Tailscale up takes
# ~30-60 s), then pipes it through. Tailnet-only: no firewall port opened.
#
# Manual: `wake-orr` sends the packet and waits until Ollama is up.
{ config, pkgs, lib, ... }:

let
  orrMac = "18:c0:4d:65:89:80";  # enp9s0
  orrHost = "orr.quoll-bleak.ts.net";
  ollamaPort = 11434;
  wakeTimeout = 180;  # seconds to wait for orr to boot

  proxy = pkgs.writers.writePython3Bin "orr-llm-proxy" {
    flakeIgnore = [ "E501" ];
  } ''
    import asyncio
    import socket
    import sys
    import time

    MAC = bytes.fromhex("${lib.replaceStrings [ ":" ] [ "" ] orrMac}")
    HOST = "${orrHost}"
    PORT = ${toString ollamaPort}
    WAKE_TIMEOUT = ${toString wakeTimeout}


    def log(msg):
        print(msg, file=sys.stderr, flush=True)


    def send_magic_packet():
        packet = b"\xff" * 6 + MAC * 16
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            s.sendto(packet, ("255.255.255.255", 9))


    async def connect_orr():
        try:
            return await asyncio.wait_for(asyncio.open_connection(HOST, PORT), 3)
        except (OSError, asyncio.TimeoutError):
            return None


    async def connect_waking():
        conn = await connect_orr()
        if conn:
            return conn
        log("orr unreachable, sending Wake-on-LAN")
        start = last_wake = time.monotonic()
        send_magic_packet()
        while time.monotonic() - start < WAKE_TIMEOUT:
            await asyncio.sleep(3)
            if time.monotonic() - last_wake > 30:
                send_magic_packet()
                last_wake = time.monotonic()
            conn = await connect_orr()
            if conn:
                log(f"orr up after {time.monotonic() - start:.0f}s")
                return conn
        return None


    async def pipe(reader, writer):
        try:
            while data := await reader.read(65536):
                writer.write(data)
                await writer.drain()
        except OSError:
            pass
        finally:
            writer.close()


    async def handle(client_r, client_w):
        conn = await connect_waking()
        if not conn:
            log("orr did not come up in time")
            client_w.write(b"HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
            await client_w.drain()
            client_w.close()
            return
        orr_r, orr_w = conn
        await asyncio.gather(pipe(client_r, orr_w), pipe(orr_r, client_w))


    async def main():
        server = await asyncio.start_server(handle, "0.0.0.0", PORT)
        log(f"proxying :{PORT} -> {HOST}:{PORT}")
        async with server:
            await server.serve_forever()


    asyncio.run(main())
  '';

  wake-orr = pkgs.writeShellApplication {
    name = "wake-orr";
    runtimeInputs = [ pkgs.wakeonlan pkgs.curl ];
    text = ''
      url="http://${orrHost}:${toString ollamaPort}/api/version"
      if curl -sf -m 3 "$url" >/dev/null; then
        echo "orr is already up"
        exit 0
      fi
      wakeonlan ${orrMac}
      echo -n "waiting for orr"
      for _ in $(seq ${toString (wakeTimeout / 3)}); do
        if curl -sf -m 3 "$url" >/dev/null; then
          echo " up"
          exit 0
        fi
        echo -n "."
        sleep 3
      done
      echo " timed out"
      exit 1
    '';
  };
in
{
  systemd.services.orr-llm-proxy = {
    description = "Wake-on-demand proxy to Ollama on orr";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = lib.getExe proxy;
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  environment.systemPackages = [ wake-orr ];
}
