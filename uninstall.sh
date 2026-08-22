#!/usr/bin/env bash
set -e

# ==============================================================================
# iGPU / Blackwell eGPU Universal Manager - Uninstaller
# Target: CachyOS / Arch Linux
# ==============================================================================

if [ "$EUID" -eq 0 ]; then
  echo "[-] Błąd: Uruchom ten skrypt jako zwykły użytkownik (bez sudo)."
  echo "    Skrypt sam poprosi o uprawnienia root w odpowiednich momentach."
  exit 1
fi

PLASMA_APPLET_DIR="$HOME/.local/share/plasma/plasmoids/com.github.blackwellegpu"

echo "=== 1. Usuwanie backendu CLI i konfiguracji uprawnień ==="
if [ -f "/usr/local/bin/blackwell-egpu" ]; then
    sudo rm -f "/usr/local/bin/blackwell-egpu"
    echo "[+] Usunięto /usr/local/bin/blackwell-egpu"
fi

if [ -f "/etc/sudoers.d/blackwell-egpu" ]; then
    sudo rm -f "/etc/sudoers.d/blackwell-egpu"
    echo "[+] Usunięto /etc/sudoers.d/blackwell-egpu"
fi

echo "=== 2. Usuwanie reguł udev ==="
if [ -f "/etc/udev/rules.d/99-blackwell-egpu.rules" ]; then
    sudo rm -f "/etc/udev/rules.d/99-blackwell-egpu.rules"
    sudo udevadm control --reload-rules
    echo "[+] Usunięto reguły udev i przeładowano konfigurację."
fi

# Usuwanie ewentualnych flag tymczasowych
rm -f /tmp/egpu_allow /tmp/egpu_wait

echo "=== 3. Usuwanie apletu KDE Plasma 6 ==="
if [ -d "$PLASMA_APPLET_DIR" ]; then
    rm -rf "$PLASMA_APPLET_DIR"
    echo "[+] Usunięto aplet: $PLASMA_APPLET_DIR"

    # Czyszczenie pamięci podręcznej QML
    rm -rf "$HOME/.cache/plasma"* "$HOME/.cache/qmlcache"*
    echo "[+] Wyczyszczono pamięć podręczną Plasmy."

    read -r -p "Zrestartować Plasmashell, aby odświeżyć interfejs? [Y/n]: " RESTART_CHOICE
    RESTART_CHOICE=${RESTART_CHOICE:-Y}
    if [[ "$RESTART_CHOICE" =~ ^[YyTt]$ ]]; then
        killall plasmashell 2>/dev/null || true
        sleep 1
        nohup plasmashell >/dev/null 2>&1 &
        echo "[+] Plasmashell został zrestartowany."
    fi
else
    echo "[*] Aplet Plasmy nie był zainstalowany w katalogu użytkownika."
fi

echo -e "\n[+] Deinstalacja zakończona pomyślnie!"
