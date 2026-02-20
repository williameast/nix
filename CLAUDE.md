# Nix Home Manager Config - Claude Context

## Quick Context
This is weast's flake-based Home Manager configuration for Pop!_OS (non-NixOS).
See `AGENT_PROMPT.md` for full details on principles, structure, and preferences.

## Key Goals
1. **XDG compliance** - Keep home directory clean, all config in `~/.config/`
2. **Flakes only** - No channels, no `builtins.fetchTarball`
3. **WebGL working** - Firefox must have hardware acceleration (AMD R9 290 + nixGL)
4. **Modular** - Self-contained modules, easy to enable/disable features

## Machines
### orr (desktop)
- **OS:** Pop!_OS 22.04 (Ubuntu-based, NOT NixOS)
- **GPU:** AMD Radeon R9 290 (radeonsi driver)
- **Modules:** core, desktop, dev, media, games, modelling

### yossarian (laptop)
- **OS:** Pop!_OS 22.04 (Ubuntu-based, NOT NixOS)
- **GPU:** Intel CometLake-U GT2 (iHD driver)
- **Modules:** core, desktop, dev, media

### milo (server)
- **OS:** Pop!_OS 22.04 (Ubuntu-based, NOT NixOS)
- **Role:** Headless server (Proxmox/Docker host)
- **Modules:** core (minimal: shell, git, cli-tools, syncthing), secrets

**User:** weast

## Commands
```bash
# Build and switch (orr)
home-manager switch --flake .#weast@orr

# Build and switch (yossarian)
home-manager switch --flake .#weast@yossarian

# Build and switch (milo)
home-manager switch --flake .#weast@milo

# Test build without switching
home-manager build --flake .#weast@orr

# Debug
home-manager switch --flake .#weast@orr --show-trace
```

## Syncthing Configuration

**Single source of truth:** `modules/home/syncthing-topology.nix`

### Network Diagram

```
  [trusted internal network]
  ┌─────────────────────────────────┐
  │  orr ──────┐                    │
  │            ├──── milo           │
  │  yossarian─┘      │             │
  │                   │             │
  │  phone ───────────┘             │
  └──────────────────────┬──────────┘
                         │ (controlled ingress only)
                    ultracc (seedbox)
```

- **Spokes** (orr, yossarian, phone) only know about milo — they have no knowledge of ultracc
- **ultracc** only connects to milo — it cannot reach orr, yossarian, or phone
- **milo** is the security boundary: all external data enters here and never propagates outward as raw files

### Folders

| Folder | Participants | Notes |
|--------|-------------|-------|
| `org` | orr, yossarian, milo, phone | Personal notes/org files |
| `torrent-metainfo` | orr, yossarian, milo, ultracc | `.torrent` files only; spokes → milo → ultracc |
| `music-staging` | ultracc, milo | Incoming music; milo path: `/mnt/vault-new/staging/music` |
| `tv-shows` | ultracc, milo | Incoming TV; milo path: `/mnt/vault-new/tv-shows` |
| `movies` | ultracc, milo | Incoming movies; milo path: `/mnt/vault-new/movies` |
| `program-staging` | ultracc, milo | Incoming software; milo path: `/mnt/vault-new/staging/programs` |
| `misc` | ultracc, milo | Other files; milo path: `/mnt/vault-new/misc` |

### Torrent Workflow

1. Drop `.torrent` file into `~/torrentfiles/` on orr or yossarian
2. Syncs to milo (hub routing)
3. Milo forwards to ultracc — torrent client picks it up
4. Completed download syncs back: ultracc → milo (`/mnt/vault-new/`)
5. Jellyfin / Navidrome serve the media from milo

### How It Works

`buildSyncthingConfig { hostname, homeDir }` computes per-host config:
- **Spokes**: Syncthing device config contains only milo. Folders list milo as sole peer.
- **Hub (milo)**: Device config contains all direct peers. Folders list all their participants.

This means orr's Syncthing config is completely unaware ultracc exists — it cannot be reached.

### Setup

```bash
# Get device ID on any machine
syncthing --device-id

# Rebuild after editing topology
home-manager switch --flake .#weast@orr       # or yossarian
sudo nixos-rebuild switch --flake .#milo      # for milo (NixOS)

# Access web UI
http://localhost:8384
```

### Ultracc Manual Setup (not managed by Nix)

In the Syncthing web UI on ultracc, add milo as the only device, then:

| Folder | Type | Path |
|--------|------|------|
| `torrent-metainfo` | Receive Only | torrent client watch folder |
| `tv-shows` | Send Only | `~/media/TV Shows` |
| `movies` | Send Only | `~/media/Movies` |
| `music-staging` | Send Only | `~/media/Music` |
| `program-staging` | Send Only | `~/media/Programs` |
| `misc` | Send Only | `~/media/Misc` |

Do **not** add orr or yossarian as devices on ultracc.

### Adding a New Folder

Edit `sharedFolders` in `modules/home/syncthing-topology.nix`:

```nix
documents = {
  path = "Documents";
  devices = [ "orr" "yossarian" "milo" ];
  # pathOverrides.milo = "/some/absolute/path";  # optional
};
```

Rebuild on all participating machines. No other files need editing.

### Adding a New Machine

1. Add its device ID to `machines` in `modules/home/syncthing-topology.nix`
2. Add its name to `devices` lists in any folders it should sync
3. Create a host config that calls `buildSyncthingConfig`
4. Rebuild

### Phone Setup (GrapheneOS/Android)

Phone connects to milo only — same security model as other spokes.

1. Install Syncthing from F-Droid
2. Get device ID: Menu → Show device ID → add to `machines.phone.deviceId` in topology
3. In Syncthing app: add milo as a device (enter milo's device ID)
4. Add folders (e.g. `org`): Folder ID must match the key in `sharedFolders` exactly
5. Accept the folder share on milo at `http://milo:8384`

## Workflow
- **Changelog:** Use `git log --oneline` to see what changed
- **Status:** Check git status and the modules to understand current state
- **Old config:** `~/.config/home-manager/` (legacy, being migrated from)

## Current Status
**Last updated:** 2026-02-20

### Completed
- [x] Phase 1: Bootstrap - flake.nix with inputs (nixpkgs, home-manager, nixgl, nur)
- [x] Module structure created (core, desktop, dev, media, machines)
- [x] Switched to new flake-based config
- [x] Shell (zsh) working with XDG-compliant paths (~/.config/zsh/)
- [x] Core packages available (firefox, emacs, bat, fzf, etc.)
- [x] Firefox WebGL 1 & 2 working via nixGL wrapper (~/.local/bin/firefox)
- [x] Syncthing with declarative hub-and-spoke config (security-isolated, milo as ingress)

### In Progress
- [ ] Verify all packages from old config are migrated
- [ ] Test other apps that may need nixGL wrapping

### Not Started
- [ ] Phase 5: Full XDG audit and cleanup
- [ ] Document any programs that can't be XDG-compliant
- [ ] Remove old config at ~/.config/home-manager/ once verified

## Session Start Checklist
1. Run `git log --oneline -5` to see recent changes
2. Run `git status` to check for uncommitted work
3. Ask what the user wants to work on
