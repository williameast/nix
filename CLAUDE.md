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

Syncthing uses a **centralized topology configuration** that lets you toggle between hub-and-spoke and full-mesh with a single boolean.

### Architecture

**Base module** (`modules/core/syncthing.nix`):
- Enables syncthing service on all machines
- Uses declarative config (`overrideDevices` and `overrideFolders` set to `true`)

**Topology config** (`modules/syncthing-topology.nix`):
- **Single source of truth** for sync topology
- Define all machines and their device IDs
- Define shared folders (what to sync)
- **Toggle between hub-and-spoke and full-mesh** with `hubAndSpoke` boolean

**Host configs** automatically configure themselves based on topology mode.

### Topology Modes

**Hub-and-Spoke** (`hubAndSpoke = true`):
```
orr ←→ milo ←→ yossarian
```
- Milo is the central hub (always on server)
- orr and yossarian only sync with milo
- Simpler, cleaner, milo is single source of truth

**Full-Mesh** (`hubAndSpoke = false`):
```
orr ←→ milo ←→ yossarian
     ↖_______↗
```
- All machines sync with all other machines
- More resilient but more complex

### Setup Process

1. **Get device IDs** from each machine:
   ```bash
   syncthing --device-id
   ```

2. **Update topology config** (`modules/syncthing-topology.nix`):
   - Paste device IDs into the `machines` section
   - Set `hubAndSpoke = true` or `false` to choose topology mode

3. **Rebuild on all machines**:
   ```bash
   # On orr
   home-manager switch --flake .#weast@orr

   # On yossarian
   home-manager switch --flake .#weast@yossarian

   # On milo
   home-manager switch --flake .#weast@milo
   ```

4. **Access UI** at `http://localhost:8384`

### Adding/Removing Folders

Edit `sharedFolders` in `modules/syncthing-topology.nix`:

```nix
sharedFolders = {
  org = {
    path = "org";  # Relative to home directory
    ignorePerms = false;
  };
  # Add new folder
  documents = {
    path = "Documents";
    ignorePerms = false;
  };
};
```

All machines automatically sync the folders based on topology mode. No need to edit individual host configs!

### Switching Topologies

To switch between hub-and-spoke and full-mesh, just change one line in `modules/syncthing-topology.nix`:

```nix
hubAndSpoke = true;  # Change to false for full-mesh
```

Then rebuild on all machines. The sync topology updates automatically!

### Adding External Devices (Phone, Tablet, etc.)

**Important**: Nix can only manage Nix-based systems. External devices (Android, iOS, Windows) need manual Syncthing setup, but we can still add them to the topology config.

#### On the Nix Side (One-Time Setup)

1. **Add device to topology** (`modules/syncthing-topology.nix`):
   ```nix
   machines = {
     # ... existing machines ...
     phone = {
       deviceId = "XXX...";  # Get from phone (see below)
       managed = false;  # Not managed by Nix
     };
   };
   ```

2. **Configure which folders sync to phone**:
   ```nix
   sharedFolders = {
     org = {
       path = "org";
       ignorePerms = false;
       # Syncs to all devices (default)
     };
     music = {
       path = "Music";
       ignorePerms = false;
       # Don't sync huge music library to phone
       devices = [ "orr" "yossarian" "milo" ];
     };
   };
   ```

3. **Rebuild on all Nix machines** - they'll now know about the phone and be ready to sync.

#### On the Phone Side (GrapheneOS/Android)

1. **Install Syncthing**:
   - From F-Droid (recommended for GrapheneOS)
   - Or from Play Store/Aurora Store

2. **Get phone's device ID**:
   - Open Syncthing app
   - Go to: Menu → Show device ID
   - Copy and paste into topology config above

3. **Add computers as devices on phone**:
   - In Syncthing app: Devices tab → (+) button
   - For each computer (orr, yossarian, milo):
     - Tap the computer when it appears in "Nearby devices"
     - OR manually enter the device ID from topology config
   - Accept the connection

4. **Add folders on phone**:
   - Folders tab → (+) button
   - For `org` folder:
     - Folder path: `/storage/emulated/0/Syncthing/org` (or wherever you want)
     - Folder ID: `org` (MUST match the ID in topology config)
     - Share with devices: select the computers you want to sync with
   - The folder will appear as "Unshared" on computers until you accept it in the UI

5. **Accept folder sharing on computers**:
   - On each computer, open `http://localhost:8384`
   - Accept the folder share from phone
   - Folders will start syncing!

#### Per-Folder Device Control

You can control which devices get which folders:

```nix
sharedFolders = {
  # Syncs to everyone (including phone)
  org = {
    path = "org";
    ignorePerms = false;
  };

  # Only computers (no phone)
  music = {
    path = "Music";
    ignorePerms = false;
    devices = [ "orr" "yossarian" "milo" ];
  };

  # Only phone and one computer
  photos = {
    path = "Photos";
    ignorePerms = false;
    devices = [ "phone" "milo" ];
  };
};
```

All Nix-managed machines automatically configure themselves based on these rules!

### Advanced: File Filtering and Seedbox Integration

You can filter which files sync using Syncthing's ignore patterns. Example use case: torrent workflow with a seedbox.

#### Torrent Workflow Setup

```nix
sharedFolders = {
  # 1. Watch folder - only .torrent files go TO seedbox
  torrent-metainfo = {
    path = "torrentfiles";
    devices = [ "orr" "yossarian" "milo" "ultracc" ];
    patterns = [
      "!*.torrent"  # Include .torrent files
      "*"           # Exclude everything else
    ];
    # On ultracc (seedbox): set folder type to "Receive Only"
  };

  # 2. Completed downloads come FROM seedbox
  downloads = {
    path = "Downloads/torrents";
    devices = [ "ultracc" "milo" ];
    # On ultracc: set folder type to "Send Only"
    # On milo: receives and archives completed downloads
  };
};
```

**Workflow:**
1. Drop .torrent file into `~/torrentfiles/` on any machine (orr/yossarian/milo)
2. Syncthing syncs it to ultracc seedbox
3. Ultracc's torrent client watches that folder and downloads
4. Completed download syncs from ultracc → milo
5. Milo archives the media

**Pattern Syntax:**
- `!pattern` - Include (whitelist)
- `pattern` - Exclude
- `*` - Match everything
- `*.ext` - Match file extension
- `**/` - Match any directory

When the first line starts with `!`, it's whitelist mode (only matched files sync).

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
