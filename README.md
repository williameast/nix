# nix-config

Personal Home Manager configuration for multiple machines. Flake-based, modular, and designed for non-NixOS systems (Pop!_OS, Ubuntu, etc.).

Machine names from Catch-22: **orr** (workstation), **yossarian** (laptop), **milo** (server).

## Machines

| Machine | Type | OS | GPU | Description |
|---------|------|-----|-----|-------------|
| **orr** | Workstation | Pop!_OS | AMD R9 290 | Full desktop with games, 3D modelling, dev tools |
| **yossarian** | Laptop | Pop!_OS | Intel CometLake | Portable desktop setup |
| **milo** | Server | NixOS | None | Headless server, Jellyfin/Navidrome, Syncthing hub |

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
│   ├── home/                 # Home Manager modules (all systems)
│   │   ├── core/             # Always included on desktop machines
│   │   │   ├── default.nix
│   │   │   ├── shell.nix     # Zsh + Oh-My-Zsh
│   │   │   ├── git.nix
│   │   │   ├── cli-tools.nix # bat, fzf, ripgrep, etc.
│   │   │   └── xdg.nix       # XDG directories
│   │   │
│   │   ├── desktop/
│   │   │   ├── default.nix
│   │   │   └── firefox.nix   # Firefox + WebGL + extensions via nixGL
│   │   │
│   │   ├── dev/
│   │   │   ├── default.nix
│   │   │   ├── emacs.nix
│   │   │   ├── direnv.nix
│   │   │   └── languages.nix
│   │   │
│   │   ├── media/
│   │   │   ├── default.nix
│   │   │   └── audio-video.nix   # VLC, ffmpeg, etc.
│   │   │
│   │   ├── games/
│   │   │   └── default.nix       # Steam with nixGL
│   │   │
│   │   ├── modelling/
│   │   │   └── default.nix       # OpenSCAD, Bambu Studio (FreeCAD TODO)
│   │   │
│   │   ├── io/               # I/O devices (printers, monitors, etc.)
│   │   │   └── receipt-printer.nix  # Network receipt printing client
│   │   │
│   │   ├── machines/         # Machine-specific overrides
│   │   │   ├── orr.nix
│   │   │   ├── yossarian.nix
│   │   │   └── milo.nix
│   │   │
│   │   └── secrets.nix       # KeePassXC integration
│   │
│   └── nixos/                # NixOS system modules (milo only)
│       ├── services/
│       │   ├── syncthing.nix
│       │   ├── jellyfin.nix
│       │   ├── navidrome.nix
│       │   └── docker.nix
│       ├── storage/
│       │   ├── btrfs-vault.nix
│       │   ├── usb-mounts.nix
│       │   └── backups.nix
│       └── io/               # I/O devices
│           └── cups-printing.nix  # CUPS print server for network printers
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

### Comms
- **Mail and calendars** - Purelymail accounts via Thunderbird, mbsync/notmuch/msmtp and vdirsyncer, passwords in agenix; add a mailbox with `mail-add` (see "Mail" below)

### I/O Devices
- **Receipt Printer** - Network printing to Epson TM-T88V via milo
  - Server: CUPS on milo with raw queue for ESC/POS
  - Client: `print-receipt-network` and `mietzahlungsquittung-network` commands
  - See "Receipt Printer Setup" section below

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

<<<<<<< Updated upstream
## Syncthing

Hub-and-spoke topology. Milo is the central hub and the only ingress point for external data.

```
  [trusted internal network]
  ┌──────────────────────────────────┐
  │  orr ───────┐                    │
  │             ├──── milo           │
  │  yossarian ─┘      │             │
  │                    │             │
  │  phone ────────────┘             │
  └───────────────────────┬──────────┘
                          │ (controlled ingress)
                     ultracc (seedbox)
```

**Security model:**
- Spokes (orr, yossarian, phone) only know milo — ultracc is invisible to them
- ultracc connects to milo only — cannot reach any internal device
- All external data enters via milo and is served internally (Jellyfin, Navidrome)

**Configuration:** `modules/home/syncthing-topology.nix` — edit device IDs and folder lists there. Everything else is computed automatically.

**Torrent workflow:** Drop `.torrent` into `~/torrentfiles/` → syncs to milo → milo forwards to ultracc → completed download syncs back to `/mnt/vault-new/`.

## Mail

All mailboxes are Purelymail accounts, declared once in `modules/home/comms/accounts.nix`. Gmail, Outlook.com and McGill are not synced; they forward to a Purelymail address.

| Tool | Role | Password from |
|------|------|---------------|
| Thunderbird | Main client | Its own password store (entered once per account) |
| mbsync + notmuch | Fetch every 5 min (`sync-mail` timer), index for Emacs | agenix |
| msmtp | Send from Emacs | agenix |
| vdirsyncer + khal | Calendars → org-agenda | agenix |

Passwords are agenix secrets in `secrets/`, named after the address (`hello@aquaveen.com` → `secrets/hello_at_aquaveen_com.age`), encrypted to `~/.ssh/id_ed25519.pub` and decrypted at login to `/run/user/1000/agenix/`. No keyring or KeePassXC is involved, so background sync works while KeePassXC is locked.

**Files** (`modules/home/comms/`):
- `accounts.nix` - every mailbox and calendar
- `providers.nix` - how to talk to Purelymail, Google Calendar, ICS links
- `mail.nix` - mbsync, msmtp, notmuch, the `sync-mail` timer and `mail-add`
- `secrets.nix` - agenix; mailbox secrets are derived from `accounts.nix`
- `default.nix` - Thunderbird

### Adding a mailbox

```bash
mail-add
```

It asks for the address, an account name (default `<domain>-<user>`, e.g. `weast-studios-oldmail`) and the password, then:
1. encrypts the password to `secrets/<address>.age` and `git add`s it
2. adds `<name> = p.purelymail "<address>";` to `accounts.nix`
3. optionally runs `nixos-rebuild switch`

Then restart Thunderbird and enter the password once when it asks (tick "remember"):
```bash
wl-copy < /run/user/1000/agenix/<user>_at_<domain>_<tld>
```

Running `mail-add` for an address that already exists only replaces its password (Thunderbird keeps its old one until you change it there too).

### Removing a mailbox

Delete its line from `accounts.nix` and its `.age` file from `secrets/`, then rebuild.

### Troubleshooting

- **Thunderbird stuck on "Loading message" or "Copying message to Sent folder":** an account has no saved password, and Thunderbird queues every account behind that password prompt. Right-click each account → Get Messages and enter the missing password. To see which one, start it with logging and look for accounts that stop after `CAPABILITY`:
  ```bash
  MOZ_LOG=IMAP:5,timestamp MOZ_LOG_FILE=/tmp/tb.log thunderbird
  ```
- **Check a password against the server:**
  ```bash
  curl -u "you@domain:$(cat /run/user/1000/agenix/you_at_domain_tld)" imaps://imap.purelymail.com/ -X 'LIST "" "*"'
  ```
- **Background sync:** `systemctl --user start sync-mail` and `journalctl --user -u sync-mail`.
=======
## Receipt Printer Setup

Network printing to Epson TM-T88V thermal receipt printer connected to milo server.

### Server Setup (milo)

The printer is connected via USB to milo and shared over the network using CUPS.

**Initial setup:**
```bash
# On milo, rebuild to enable CUPS
cd ~/.config/nix-config
sudo nixos-rebuild switch --flake .#milo

# Connect printer via USB, then configure
sudo setup-tm-t88v
```

The `setup-tm-t88v` script auto-detects the USB printer and configures it as a raw queue (no driver needed - scripts generate ESC/POS commands directly).

**Web interface:** `http://milo.local:631`

### Client Setup (orr, yossarian)

Add the receipt printer module to your host config:

```nix
# In hosts/orr/default.nix or hosts/yossarian/default.nix
imports = [
  # ... other imports ...
  ../../modules/home/io/receipt-printer.nix
];
```

Then rebuild:
```bash
home-manager switch --flake .#weast@orr
```

### Usage

**Print a pre-generated .prn file:**
```bash
print-receipt-network receipt.prn
```

**Generate and print Mietzahlungsquittung:**
```bash
mietzahlungsquittung-network \
  --date 2025-01-15 \
  --amount 850.00 \
  --name "Your Name" \
  --number 001
```

**Manual network printing:**
```bash
# From any machine with CUPS
lp -h milo.local:631 -d EPSON_TM-T88V receipt.prn
```

### Troubleshooting

**Check printer status on milo:**
```bash
lpstat -p EPSON_TM-T88V
```

**Re-configure printer:**
```bash
lpadmin -x EPSON_TM-T88V  # Remove
sudo setup-tm-t88v        # Re-add
```

**Test connectivity:**
```bash
ping milo.local
curl http://milo.local:631
```
>>>>>>> Stashed changes

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
