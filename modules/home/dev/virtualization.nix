# Virtualization tools (QEMU for testing NixOS VMs)
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    qemu_kvm
    qemu
    OVMF  # UEFI firmware for QEMU
  ];

  # Helper script to run NixOS test VM
  home.file.".local/bin/nixos-test-vm" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Helper script to test NixOS in QEMU before migrating

      set -e

      VM_DIR="$HOME/.local/share/nixos-test-vm"
      DISK_IMG="$VM_DIR/nixos-test.qcow2"
      ISO_PATH="$VM_DIR/nixos.iso"
      DISK_SIZE="40G"

      # Colors for output
      GREEN='\033[0;32m'
      BLUE='\033[0;34m'
      YELLOW='\033[1;33m'
      NC='\033[0m' # No Color

      usage() {
        echo "Usage: nixos-test-vm [command]"
        echo ""
        echo "Commands:"
        echo "  init       - Create VM disk and download NixOS ISO"
        echo "  run        - Run VM (boots from disk)"
        echo "  install    - Run VM with ISO attached for installation"
        echo "  clean      - Remove VM disk (keeps ISO)"
        echo "  clean-all  - Remove everything (disk and ISO)"
        echo ""
        echo "VM Directory: $VM_DIR"
      }

      init_vm() {
        mkdir -p "$VM_DIR"

        if [ ! -f "$DISK_IMG" ]; then
          echo -e "''${BLUE}Creating virtual disk ($DISK_SIZE)...''${NC}"
          qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
        else
          echo -e "''${YELLOW}Virtual disk already exists at $DISK_IMG''${NC}"
        fi

        if [ ! -f "$ISO_PATH" ]; then
          echo -e "''${BLUE}Downloading NixOS ISO...''${NC}"
          echo -e "''${YELLOW}This may take a few minutes...''${NC}"

          # Get latest unstable ISO (matches your flake)
          ISO_URL="https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso"

          curl -L -o "$ISO_PATH" "$ISO_URL"
          echo -e "''${GREEN}ISO downloaded to $ISO_PATH''${NC}"
        else
          echo -e "''${YELLOW}ISO already exists at $ISO_PATH''${NC}"
        fi

        echo -e "''${GREEN}VM initialized! Run 'nixos-test-vm install' to start installation''${NC}"
      }

      run_vm() {
        if [ ! -f "$DISK_IMG" ]; then
          echo -e "''${YELLOW}No VM disk found. Run 'nixos-test-vm init' first''${NC}"
          exit 1
        fi

        echo -e "''${BLUE}Starting NixOS VM...''${NC}"
        echo -e "''${YELLOW}Press Ctrl+Alt+G to release mouse, Ctrl+Alt+F to toggle fullscreen''${NC}"

        qemu-system-x86_64 \
          -enable-kvm \
          -m 4G \
          -smp 4 \
          -cpu host \
          -drive file="$DISK_IMG",format=qcow2,if=virtio \
          -nic user,model=virtio-net-pci \
          -vga virtio \
          -display sdl,gl=on \
          "$@"
      }

      run_install() {
        if [ ! -f "$ISO_PATH" ]; then
          echo -e "''${YELLOW}No ISO found. Run 'nixos-test-vm init' first''${NC}"
          exit 1
        fi

        if [ ! -f "$DISK_IMG" ]; then
          echo -e "''${YELLOW}No VM disk found. Run 'nixos-test-vm init' first''${NC}"
          exit 1
        fi

        echo -e "''${BLUE}Starting NixOS installation...''${NC}"
        echo -e "''${YELLOW}Press Ctrl+Alt+G to release mouse, Ctrl+Alt+F to toggle fullscreen''${NC}"
        echo -e "''${GREEN}Tip: You can test your flake config during install!''${NC}"
        echo -e "''${GREEN}      Mount your home dir with: mount -t 9p -o trans=virtio,version=9p2000.L host0 /mnt/host''${NC}"

        qemu-system-x86_64 \
          -enable-kvm \
          -m 4G \
          -smp 4 \
          -cpu host \
          -drive file="$DISK_IMG",format=qcow2,if=virtio \
          -cdrom "$ISO_PATH" \
          -boot order=d \
          -nic user,model=virtio-net-pci \
          -vga virtio \
          -display sdl,gl=on \
          -virtfs local,path="$HOME/.config/nix-config",mount_tag=host0,security_model=passthrough,id=host0 \
          "$@"
      }

      clean_vm() {
        if [ -f "$DISK_IMG" ]; then
          echo -e "''${YELLOW}Removing VM disk...''${NC}"
          rm "$DISK_IMG"
          echo -e "''${GREEN}VM disk removed''${NC}"
        else
          echo -e "''${YELLOW}No VM disk to remove''${NC}"
        fi
      }

      clean_all() {
        if [ -d "$VM_DIR" ]; then
          echo -e "''${YELLOW}Removing entire VM directory...''${NC}"
          rm -rf "$VM_DIR"
          echo -e "''${GREEN}All VM files removed''${NC}"
        else
          echo -e "''${YELLOW}No VM directory to remove''${NC}"
        fi
      }

      case "''${1:-}" in
        init)
          init_vm
          ;;
        run)
          shift
          run_vm "$@"
          ;;
        install)
          shift
          run_install "$@"
          ;;
        clean)
          clean_vm
          ;;
        clean-all)
          clean_all
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
  };
}
