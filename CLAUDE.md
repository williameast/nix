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

**User:** weast

## Commands
```bash
# Build and switch (orr)
home-manager switch --flake .#weast@orr

# Build and switch (yossarian)
home-manager switch --flake .#weast@yossarian

# Test build without switching
home-manager build --flake .#weast@orr

# Debug
home-manager switch --flake .#weast@orr --show-trace
```

## Syncthing Configuration

Syncthing is configured declaratively with a base module + machine-specific settings.

**Base module** (`modules/core/syncthing.nix`):
- Enables syncthing service on all machines
- Uses declarative config (`overrideDevices` and `overrideFolders` set to `true`)
- Includes syncthing CLI tool

**Machine-specific configs** (`hosts/{orr,yossarian}/default.nix`):
- Define devices (other machines to sync with)
- Define folders (what to sync and where)

### Setup Process

1. **Get device IDs** from each machine:
   ```bash
   syncthing --device-id
   ```

2. **Update host configs** with device IDs:
   - `hosts/orr/default.nix` - paste yossarian's device ID
   - `hosts/yossarian/default.nix` - paste orr's device ID

3. **Rebuild configuration**:
   ```bash
   home-manager switch --flake .#weast@orr
   # Or on yossarian:
   home-manager switch --flake .#weast@yossarian
   ```

4. **Access UI** at `http://localhost:8384`

### Adding/Removing Folders

Edit the `services.syncthing.settings.folders` section in the respective host config:

```nix
services.syncthing.settings = {
  devices = { ... };
  folders = {
    "org" = {
      path = "${config.home.homeDirectory}/org";
      devices = [ "yossarian" ];
      ignorePerms = false;
    };
    # Add more folders as needed
  };
};
```

## Workflow
- **Changelog:** Use `git log --oneline` to see what changed
- **Status:** Check git status and the modules to understand current state
- **Old config:** `~/.config/home-manager/` (legacy, being migrated from)

## Current Status
**Last updated:** 2026-01-24

### Completed
- [x] Phase 1: Bootstrap - flake.nix with inputs (nixpkgs, home-manager, nixgl, nur)
- [x] Module structure created (core, desktop, dev, media, machines)
- [x] Switched to new flake-based config
- [x] Shell (zsh) working with XDG-compliant paths (~/.config/zsh/)
- [x] Core packages available (firefox, emacs, bat, fzf, etc.)
- [x] Firefox WebGL 1 & 2 working via nixGL wrapper (~/.local/bin/firefox)
- [x] Syncthing with declarative config (base module + machine-specific folders/devices)

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
