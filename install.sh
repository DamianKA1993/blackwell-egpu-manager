#!/usr/bin/env bash
set -e

# ==============================================================================
# iGPU / Blackwell eGPU Universal Manager - CLI & Plasma Applet Installer
# Target: CachyOS / Arch Linux
# ==============================================================================

if [ "$EUID" -eq 0 ]; then
  echo "[-] Error: Run this script as a normal user (without sudo)."
  echo "    The installer will request root privileges when necessary."
  exit 1
fi

CURRENT_USER="$USER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_SRC="$SCRIPT_DIR/blackwell-egpu"
APPLET_SRC="$SCRIPT_DIR/plasma-applet/com.github.blackwellegpu"
PLASMA_PLASMOIDS_DIR="$HOME/.local/share/plasma/plasmoids"
TARGET_APPLET_DIR="$PLASMA_PLASMOIDS_DIR/com.github.blackwellegpu"
UDEV_RULE_FILE="/etc/udev/rules.d/99-blackwell-egpu.rules"

# Track if udev rules were newly installed in this run to determine if reboot is needed
UDEV_NEWLY_INSTALLED=false

# 1. Verify presence of backend source file
if [ ! -f "$BACKEND_SRC" ]; then
    echo "[-] Error: File '$BACKEND_SRC' not found."
    echo "    Make sure 'blackwell-egpu' is in the same directory as 'install.sh'."
    exit 1
fi

echo "=== 1. Checking NVIDIA Open kernel module ==="
if ! pacman -Qs "nvidia-open" >/dev/null 2>&1 && ! modinfo nvidia 2>/dev/null | grep -iq "license.*dual"; then
    echo "----------------------------------------------------------------------"
    echo "[!] WARNING: NVIDIA Open kernel module not detected!"
    echo "    Blackwell GPUs (RTX 50xx) require open-source kernel modules."
    echo "    Install: 'nvidia-open-dkms' (or 'nvidia-open') and kernel headers."
    echo "----------------------------------------------------------------------"
    read -r -p "Press [Enter] to continue anyway, or Ctrl+C to abort..."
else
    echo "[+] Detected NVIDIA Open kernel module."
fi

echo "=== 2. Copying CLI backend to /usr/local/bin/blackwell-egpu ==="
sudo cp "$BACKEND_SRC" /usr/local/bin/blackwell-egpu
sudo chmod +x /usr/local/bin/blackwell-egpu
echo "[+] Installed /usr/local/bin/blackwell-egpu"

echo "=== 3. Configuring sudoers permissions ==="
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/local/bin/blackwell-egpu" | sudo tee "/etc/sudoers.d/blackwell-egpu" > /dev/null
sudo chmod 0440 "/etc/sudoers.d/blackwell-egpu"
echo "[+] Configured /etc/sudoers.d/blackwell-egpu"

echo "=== 4. Configuring udev rules ==="
install_udev_rule() {
    sudo bash -c 'cat << "EOF" > /etc/udev/rules.d/99-blackwell-egpu.rules
# Intel Barlow Ridge (AORUS TB5)
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x5786", TEST!="/tmp/egpu_allow", ATTR{remove}="1"

# ASMedia ASM2464PD (USB4)
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1b21", ATTR{device}=="0x2464", TEST!="/tmp/egpu_allow", ATTR{remove}="1"

# Intel Goshen / Titan Ridge (TB3/TB4)
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x15eb", TEST!="/tmp/egpu_allow", ATTR{remove}="1"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x0b26", TEST!="/tmp/egpu_allow", ATTR{remove}="1"
EOF'
    sudo udevadm control --reload-rules
}

if [ -f "$UDEV_RULE_FILE" ]; then
    echo "[+] Existing udev rules detected. Updating rules automatically..."
    install_udev_rule
    echo "[+] Udev rules updated successfully."
else
    read -r -p "Install udev rules to prevent automatic driver attachment on USB4/TB? [Y/n]: " UDEV_CHOICE
    UDEV_CHOICE=${UDEV_CHOICE:-Y}

    if [[ "$UDEV_CHOICE" =~ ^[Yy]$ ]]; then
        install_udev_rule
        UDEV_NEWLY_INSTALLED=true
        echo "[+] Udev rules installed successfully."
    else
        echo "[*] Skipped udev rules installation."
    fi
fi

echo "=== 5. Installing KDE Plasma 6 applet ==="
if [ -d "$APPLET_SRC" ]; then
    APPLET_EXISTS=false
    if [ -d "$TARGET_APPLET_DIR" ]; then
        APPLET_EXISTS=true
        echo "[+] Existing KDE Plasma applet detected. Updating automatically..."
    else
        read -r -p "Install KDE Plasma 6 applet widget? [Y/n]: " APPLET_CHOICE
        APPLET_CHOICE=${APPLET_CHOICE:-Y}
        if [[ ! "$APPLET_CHOICE" =~ ^[Yy]$ ]]; then
            echo "[*] Skipped KDE Plasma 6 applet installation."
        fi
    fi

    if [ "$APPLET_EXISTS" = true ] || [[ "$APPLET_CHOICE" =~ ^[Yy]$ ]]; then
        mkdir -p "$PLASMA_PLASMOIDS_DIR"
        rm -rf "$TARGET_APPLET_DIR"
        cp -r "$APPLET_SRC" "$PLASMA_PLASMOIDS_DIR/"

        echo ""
        echo "Available translations:"
        echo "  - Polish (pl)"
        echo "  - German (de)"
        echo "  - Spanish (es)"
        echo "  - French (fr)"
        echo "  - Italian (it)"
        echo "  - Portuguese (pt)"
        echo "  - Ukrainian (uk)"
        echo "  - Czech (cs)"
        echo "  - Japanese (ja)"
        echo "  - Chinese Simplified (zh)"
        echo ""
        read -r -p "Enable multi-language auto-detection? [Y/n]: " LOCALE_CHOICE
        LOCALE_CHOICE=${LOCALE_CHOICE:-Y}
        if [[ "$LOCALE_CHOICE" =~ ^[Nn]$ ]]; then
            sed -i 's/var enabled = true;/var enabled = false;/' "$TARGET_APPLET_DIR/contents/ui/i18n.js"
            echo "[*] Translations disabled. Using default English UI."
        else
            echo "[+] Multi-language support enabled (system locale auto-detection)."
        fi

        echo "[+] Applet deployed to $TARGET_APPLET_DIR"

        # Clear QML cache
        rm -rf "$HOME/.cache/plasma"* "$HOME/.cache/qmlcache"*

        read -r -p "Restart Plasmashell to load the new applet? [Y/n]: " RESTART_CHOICE
        RESTART_CHOICE=${RESTART_CHOICE:-Y}
        if [[ "$RESTART_CHOICE" =~ ^[Yy]$ ]]; then
            killall plasmashell 2>/dev/null || true
            sleep 1
            nohup plasmashell >/dev/null 2>&1 &
            echo "[+] Plasmashell restarted."
        fi

        echo "----------------------------------------------------------------------"
        echo "[+] Applet installation/update completed successfully!"
        if [ "$APPLET_EXISTS" = false ]; then
            echo "[*] To add the widget to your panel:"
            echo "    1. Right-click your Plasma panel or desktop."
            echo "    2. Select 'Add Widgets...'."
            echo "    3. Locate 'Blackwell eGPU Manager' and drag it onto your panel."
            echo "----------------------------------------------------------------------"
            read -r -p "Press [Enter] to continue..."
        fi
    fi
else
    echo "[-] Applet directory '$APPLET_SRC' not found. Skipping applet installation."
fi

echo ""
if [ "$UDEV_NEWLY_INSTALLED" = true ]; then
    echo "======================================================================"
    echo "[!] IMPORTANT SETUP NOTICE"
    echo "    Custom udev rules were installed for the first time."
    echo ""
    echo "    A system reboot is strongly recommended before connecting your eGPU"
    echo "    to ensure the kernel properly initializes the fixed link."
    echo "======================================================================"

    read -r -p "Reboot system now? [y/N]: " REBOOT_CHOICE
    REBOOT_CHOICE=${REBOOT_CHOICE:-N}

    if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
        echo "[*] Rebooting system..."
        sudo reboot
    else
        echo -e "\n[+] Installation completed successfully! Please remember to reboot before attaching eGPU."
    fi
else
    echo "[+] Installation/Update completed successfully!"
fi
