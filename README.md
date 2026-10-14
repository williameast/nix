# nix-config

Personal NixOS + Home Manager configuration for multiple machines. Flake-based and modular; Home Manager runs as a NixOS module on every host.

Machine names from Catch-22: **orr** (workstation), **yossarian** (laptop), **milo** (server).

## Machines

| Machine | Type | OS | GPU | Description |
|---------|------|-----|-----|-------------|
| **orr** | Workstation | NixOS | AMD R9 290 | Hyprland desktop with games, 3D modelling, dev tools, mail |
| **yossarian** | Laptop | Pop!_OS (NixOS config is a draft) | Intel CometLake | Portable desktop setup |
| **milo** | Server | NixOS | None | Headless: Syncthing hub, Jellyfin, Navidrome, Immich, Paperless, Gitea, Büro |

## Deploy

```bash
git clone git@github.com:williameast/nix.git ~/.config/nix-config
cd ~/.config/nix-config

sudo nixos-rebuild switch --flake .#orr        # workstation
sudo nixos-rebuild switch --flake .#yossarian  # laptop (once migrated)
sudo nixos-rebuild switch --flake .#milo       # server
```

## Project Structure

```
~/.config/nix-config/
├── flake.nix                 # Inputs and nixosConfigurations for every host
├── flake.lock
├── CLAUDE.md                 # Context for Claude Code sessions
├── AGENT_PROMPT.md           # Principles and preferences
│
├── hosts/
│   ├── common.nix            # Shared Home Manager settings: username, home dir, stateVersion
│   └── <host>/
│       ├── configuration.nix         # NixOS system config (imports modules/nixos/*)
│       ├── hardware-configuration.nix
│       └── home.nix                  # Home Manager config (imports modules/home/*)
│
├── modules/
│   ├── home/                 # Home Manager modules
│   │   ├── core/             # Shell, git, CLI tools, XDG, Syncthing, torrent watcher
│   │   ├── desktop/          # Hyprland, waybar, rofi, Firefox, scanning, ntfy
│   │   ├── dev/              # Emacs, direnv, languages, QEMU
│   │   ├── media/            # Audio/video apps
│   │   ├── games/            # Gaming utilities (Steam itself is enabled at NixOS level)
│   │   ├── modelling/        # FreeCAD, Bambu Studio, OpenSCAD, Blender, Inkscape
│   │   ├── work/             # Work applications
│   │   ├── comms/            # Mail and calendars (see "Mail")
│   │   ├── machines/         # Per-machine packages and overrides
│   │   └── syncthing-topology.nix   # Syncthing devices and folders (see "Syncthing")
│   │
│   └── nixos/                # NixOS system modules
│       ├── common.nix, users.nix
│       ├── desktop/          # Hyprland (system side)
│       ├── networking/       # Tailscale, Avahi (Caddy: written, not enabled yet)
│       ├── services/         # milo's services (Jellyfin, Navidrome, Immich, Paperless, Büro, ...; Docker not enabled)
│       ├── storage/          # btrfs vault, USB mounts, backups
│       └── io/               # CUPS raw queue for the receipt printer (milo)
│
└── secrets/                  # agenix-encrypted secrets (*.age)
```

## Commands

```bash
# Switch / build without switching / debug
sudo nixos-rebuild switch --flake .#orr
sudo nixos-rebuild build --flake .#orr
sudo nixos-rebuild switch --flake .#orr --show-trace

# Update all flake inputs / a single input
nix flake update
nix flake update nixpkgs

# List and garbage-collect system generations
nixos-rebuild list-generations
sudo nix-collect-garbage -d

# REPL with the flake loaded
nix repl
:lf .
```

## Adding a New Machine

1. On the machine, install NixOS and copy its `/etc/nixos/hardware-configuration.nix` to `hosts/<name>/`.
2. Create `hosts/<name>/configuration.nix` (system: import `modules/nixos/common.nix`, `users.nix` and whatever else it needs; set `networking.hostName` and `system.stateVersion`) and `hosts/<name>/home.nix` (import `../common.nix`, the `modules/home/*` groups it needs, and `modules/home/machines/<name>.nix`). The existing hosts are the template.
3. Add it to `flake.nix`:
   ```nix
   nixosConfigurations.<name> = mkHost ./hosts/<name>/configuration.nix;
   ```
4. `git add` the new files (flakes only see tracked files) and run `sudo nixos-rebuild switch --flake .#<name>`.
5. For Syncthing, follow "Adding a New Machine" in `CLAUDE.md`.

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

**Configuration:** `modules/home/syncthing-topology.nix` — edit device IDs and folder lists there. Everything else is computed automatically. Folder list and setup steps are in `CLAUDE.md`.

**Torrent workflow:** Drop `.torrent` into `~/torrentfiles/` → syncs to milo → milo forwards to ultracc → completed download syncs back to `/mnt/vault-new/` or `/mnt/bulk/`.

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

## Printing

- **Brother DCP-L2520DW** (network): permanent CUPS queue on orr (`hosts/orr/configuration.nix`), default printer. Scanning is set up via `modules/nixos/services/scanning.nix`.
- **Epson TM-T88 receipt printer** (USB):
  - On orr, a udev rule lets the `lp` group write raw ESC/POS straight to the printer over libusb, bypassing CUPS.
  - milo has a CUPS raw queue for it (`modules/nixos/io/cups-printing.nix`); after plugging it into milo run `sudo setup-tm-t88v`, then print from any machine with `lp -h milo.local:631 -d EPSON_TM-T88V receipt.prn`. Web UI: `http://milo.local:631`.

## Secrets

Secrets are encrypted with [agenix](https://github.com/ryantm/agenix) into `secrets/*.age`, using the SSH key `~/.ssh/id_ed25519`, and decrypted at login to `/run/user/1000/agenix/`. Nothing secret is stored in plain text in git or the Nix store.

```bash
# Add or change a secret (type the value, then Ctrl-D)
cd ~/.config/nix-config/secrets
rage -e -R ~/.ssh/id_ed25519.pub -o NAME.age
git add NAME.age
```

Then reference it as `config.age.secrets.NAME.path` (see `modules/home/comms/secrets.nix`). Mailbox passwords have their own helper, `mail-add`.

KeePassXC remains the personal password manager on the desktop (app, Firefox extension, `kxc` alias for `keepassxc-cli`), but no Nix-managed service depends on it.

## Troubleshooting

### Build fails with "path does not exist"
Flakes only see tracked files. `git add` new files (including new `secrets/*.age`) before building.

### Firefox extensions not showing
Close Firefox completely, then delete the extension cache:
```bash
pkill firefox
rm ~/.mozilla/firefox/default/extensions.json
firefox
```

## Principles

1. **Flakes only** - No channels, no `builtins.fetchTarball`, no `<nixpkgs>`
2. **XDG compliance** - Keep the home directory clean
3. **Modular** - Each module is self-contained
4. **Declarative** - If it can live in this repo, it does
5. **Secrets via agenix** - Encrypted in git, decrypted at login

---

*"They're trying to kill me," Yossarian told him calmly.
"No one's trying to kill you," Clevinger cried.
"Then why are they shooting at me?" Yossarian asked.
"They're shooting at everyone," Clevinger answered. "They're trying to kill everyone."
"And what difference does that make?"*

— Joseph Heller, Catch-22
