# nix-config

Personal Home Manager configuration for multiple machines. Flake-based, modular, and designed for non-NixOS systems (Pop!_OS, Ubuntu, etc.).

Machine names from Catch-22: **orr** (workstation), **yossarian** (laptop), **milo** (server).

## Machines

| Machine | Type | OS | GPU | Description |
|---------|------|-----|-----|-------------|
| **orr** | Workstation | Pop!_OS | AMD R9 290 | Full desktop with games, 3D modelling, dev tools |
| **yossarian** | Laptop | Pop!_OS | Intel CometLake | Portable desktop setup |
| **milo** | Server | Proxmox/Linux | None | Minimal headless, Docker, secrets |

## Quick Start

### Prerequisites

Install Nix with flakes enabled:
```bash
curl -L https://nixos.org/nix/install | sh
```

Add to `~/.config/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

### Deploy

```bash
# Clone
git clone git@github.com:williameast/nix.git ~/.config/nix-config
cd ~/.config/nix-config

# Switch to your machine's config
home-manager switch --flake .#weast@orr        # workstation
home-manager switch --flake .#weast@yossarian  # laptop
home-manager switch --flake .#weast@milo       # server
```

## Project Structure

```
~/.config/nix-config/
├── flake.nix                 # Entry point, defines all machines
├── flake.lock                # Pinned dependencies
├── CLAUDE.md                 # Context for Claude Code sessions
├── AGENT_PROMPT.md           # Detailed principles and preferences
│
├── hosts/
│   ├── common.nix            # Shared: username, home dir, stateVersion
│   ├── orr/default.nix       # Workstation config
│   ├── yossarian/default.nix # Laptop config
│   └── milo/default.nix      # Server config
│
├── modules/
│   ├── core/                 # Always included on desktop machines
│   │   ├── default.nix
│   │   ├── shell.nix         # Zsh + Oh-My-Zsh
│   │   ├── git.nix
│   │   ├── cli-tools.nix     # bat, fzf, ripgrep, etc.
│   │   └── xdg.nix           # XDG directories
│   │
│   ├── desktop/
│   │   ├── default.nix
│   │   └── firefox.nix       # Firefox + WebGL + extensions via nixGL
│   │
│   ├── dev/
│   │   ├── default.nix
│   │   ├── emacs.nix
│   │   ├── direnv.nix
│   │   └── languages.nix
│   │
│   ├── media/
│   │   ├── default.nix
│   │   └── audio-video.nix   # VLC, ffmpeg, etc.
│   │
│   ├── games/
│   │   └── default.nix       # Steam with nixGL
│   │
│   ├── modelling/
│   │   └── default.nix       # OpenSCAD, Bambu Studio (FreeCAD TODO)
│   │
│   ├── machines/             # Machine-specific overrides
│   │   ├── orr.nix
│   │   ├── yossarian.nix
│   │   └── milo.nix
│   │
│   └── secrets.nix           # KeePassXC integration
│
└── overlays/
    └── default.nix
```

## Modules

### Core
- **shell.nix** - Zsh with Oh-My-Zsh, robbyrussell theme, plugins (git, sudo, web-search, etc.)
- **git.nix** - Git config with emacs as editor
- **cli-tools.nix** - bat, fzf, ripgrep, and other CLI essentials
- **xdg.nix** - XDG base directories, keeps home clean

### Desktop
- **firefox.nix** - Firefox with:
  - WebGL 1 & 2 via nixGL wrapper
  - Hardware acceleration for AMD/Intel
  - Extensions from NUR (uBlock, KeePassXC, DarkReader, Sidebery, ClearURLs)
  - Privacy-focused settings
  - Custom desktop entry for launcher

### Games
- **Steam** with nixGL wrapper for GPU access

### Modelling
- **OpenSCAD** - Parametric 3D CAD
- **Bambu Studio** - 3D printer slicer
- ~~FreeCAD~~ - Currently broken in nixpkgs (openturns dependency)

### Secrets
- **KeePassXC** integration with helper aliases:
  - `kxp <db> <entry>` - Get password
  - `kxu <db> <entry>` - Get username
  - `kxa <db> <entry> <attr>` - Get custom attribute

## nixGL (Non-NixOS GPU Support)

On non-NixOS systems, Nix apps can't access system GPU drivers. We solve this with [nixGL](https://github.com/nix-community/nixGL) wrappers.

**How it works:**
1. GPU apps (Firefox, Steam, OpenSCAD, etc.) are wrapped with `nixGLIntel`
2. Wrappers live in `~/.local/bin/` and take precedence over nix-profile
3. Custom desktop entries point to the wrappers

**Wrapped apps:**
- Firefox → `~/.local/bin/firefox`
- Steam → `~/.local/bin/steam`
- OpenSCAD → `~/.local/bin/openscad`
- Bambu Studio → `~/.local/bin/bambu-studio`

**Manual wrapping:**
```bash
nixGLIntel <any-nix-app>
```

## Commands

```bash
# Switch to configuration
home-manager switch --flake ~/.config/nix-config#weast@orr

# Build without activating (test)
home-manager build --flake ~/.config/nix-config#weast@orr

# Show trace on errors
home-manager switch --flake .#weast@orr --show-trace

# Dry run (see what would change)
home-manager switch --flake .#weast@orr --dry-run

# Update all flake inputs
nix flake update

# Update single input
nix flake lock --update-input nixpkgs

# List generations
home-manager generations

# Garbage collect old generations
nix-collect-garbage -d

# Enter repl with flake loaded
nix repl
:lf .
```

## Adding a New Machine

1. Create host directory:
   ```bash
   mkdir -p hosts/newmachine
   ```

2. Create `hosts/newmachine/default.nix`:
   ```nix
   { config, pkgs, lib, inputs, ... }:
   {
     imports = [
       ../common.nix
       ../../modules/core
       # Add modules as needed
       ../../modules/machines/newmachine.nix
     ];

     targets.genericLinux.enable = true;

     # GPU settings if needed
     home.sessionVariables = {
       LIBVA_DRIVER_NAME = "iHD";  # or "radeonsi" for AMD
     };
   }
   ```

3. Create `modules/machines/newmachine.nix`:
   ```nix
   { config, pkgs, lib, ... }:
   {
     home.packages = with pkgs; [
       # Machine-specific packages
     ];
   }
   ```

4. Add to `flake.nix`:
   ```nix
   homeConfigurations."weast@newmachine" = home-manager.lib.homeManagerConfiguration {
     inherit pkgs;
     extraSpecialArgs = { inherit inputs; };
     modules = [ ./hosts/newmachine/default.nix ];
   };
   ```

5. Deploy:
   ```bash
   home-manager switch --flake .#weast@newmachine
   ```

## Secrets Management

Secrets are managed via KeePassXC - they stay in your `.kdbx` file and are fetched at runtime.

**Setup:**
1. Sync your `.kdbx` file to the machine (Syncthing, manual copy, etc.)
2. Set the path in `modules/secrets.nix` or export:
   ```bash
   export KEEPASSXC_DB=~/Sync/passwords.kdbx
   ```

**Usage in scripts:**
```bash
# Get password for Docker container
DB_PASS=$(keepassxc-cli show -s -a password $KEEPASSXC_DB "Docker/Postgres")

# Use in docker-compose
docker run -e POSTGRES_PASSWORD=$DB_PASS postgres
```

## Troubleshooting

### Firefox extensions not showing
Close Firefox completely, then delete extension cache:
```bash
pkill firefox
rm ~/.mozilla/firefox/default/extensions.json
firefox
```

### WebGL not working
Ensure you're running the nixGL-wrapped version:
```bash
which firefox  # Should show ~/.local/bin/firefox
```

### Build fails with "path does not exist"
Add new files to git (flakes only see tracked files):
```bash
git add -A
home-manager build --flake .#weast@orr
```

### GPU apps broken after system update
Rebuild nixGL wrappers:
```bash
home-manager switch --flake .#weast@orr
```

## Principles

1. **Flakes only** - No channels, no `builtins.fetchTarball`
2. **XDG compliance** - Keep home directory clean
3. **Modular** - Each module is self-contained
4. **nixGL for GPU** - Wrap OpenGL apps on non-NixOS
5. **Secrets out of git** - KeePassXC for runtime secrets

---

*"They're trying to kill me," Yossarian told him calmly.
"No one's trying to kill you," Clevinger cried.
"Then why are they shooting at me?" Yossarian asked.
"They're shooting at everyone," Clevinger answered. "They're trying to kill everyone."
"And what difference does that make?"*

— Joseph Heller, Catch-22
