# Nix Home Manager Config - Claude Context

## Quick Context
This is weast's flake-based Home Manager configuration for Pop!_OS (non-NixOS).
See `AGENT_PROMPT.md` for full details on principles, structure, and preferences.

## Key Goals
1. **XDG compliance** - Keep home directory clean, all config in `~/.config/`
2. **Flakes only** - No channels, no `builtins.fetchTarball`
3. **WebGL working** - Firefox must have hardware acceleration (AMD R9 290 + nixGL)
4. **Modular** - Self-contained modules, easy to enable/disable features

## Machine
- **Hostname:** orr
- **OS:** Pop!_OS 22.04 (Ubuntu-based, NOT NixOS)
- **GPU:** AMD Radeon R9 290 (radeonsi driver)
- **User:** weast

## Commands
```bash
# Build and switch
home-manager switch --flake .#weast@orr

# Test build without switching
home-manager build --flake .#weast@orr

# Debug
home-manager switch --flake .#weast@orr --show-trace
```

## Workflow
- **Changelog:** Use `git log --oneline` to see what changed
- **Status:** Check git status and the modules to understand current state
- **Old config:** `~/.config/home-manager/` (legacy, being migrated from)

## Current Status
**Last updated:** 2026-01-20

### Completed
- [x] Phase 1: Bootstrap - flake.nix with inputs (nixpkgs, home-manager, nixgl, nur)
- [x] Module structure created (core, desktop, dev, media, machines)
- [x] Initial build successful
- [x] Switched to new flake-based config (generation 15)
- [x] Shell (zsh) working with XDG-compliant paths (~/.config/zsh/)
- [x] Core packages available (firefox, emacs, bat, fzf, etc.)

### In Progress
- [ ] Run GPU setup for nixGL/WebGL: `sudo /nix/store/0336984d983pkkrh38r9ld73ains7za5-non-nixos-gpu/bin/non-nixos-gpu-setup`
- [ ] Test Firefox WebGL at https://webglreport.com/
- [ ] Verify all packages from old config are migrated

### Not Started
- [ ] Phase 5: Full XDG audit and cleanup
- [ ] Document any programs that can't be XDG-compliant
- [ ] Remove old config at ~/.config/home-manager/ once verified

## Session Start Checklist
1. Run `git log --oneline -5` to see recent changes
2. Run `git status` to check for uncommitted work
3. Ask what the user wants to work on
