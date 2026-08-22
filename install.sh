#!/usr/bin/env bash
set -e

# ==============================================================================
# iGPU / Blackwell eGPU Universal Manager - CLI & Plasma Applet Installer
# Target: CachyOS / Arch Linux
# ==============================================================================

if [ "$EUID" -eq 0 ]; then
  echo "[-] Błąd: Uruchom ten skrypt jako zwykły użytkownik (bez sudo)."
  echo "    Instalator sam poprosi o uprawnienia root w odpowiednich momentach."
  exit 1
fi

CURRENT_USER="$USER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_SRC="$SCRIPT_DIR/blackwell-egpu"
APPLET_SRC="$SCRIPT_DIR/plasma-applet/com.github.blackwellegpu"
PLASMA_PLASMOIDS_DIR="$HOME/.local/share/plasma/plasmoids"

# 1. Weryfikacja obecności pliku źródłowego backendu
if [ ! -f "$BACKEND_SRC" ]; then
    echo "[-] Błąd: Nie znaleziono pliku '$BACKEND_SRC'."
    echo "    Upewnij się, że 'blackwell-egpu' znajduje się w tym samym katalogu co 'install.sh'."
    exit 1
fi

echo "=== 1. Sprawdzanie modułu jądra NVIDIA Open ==="
if ! pacman -Qs "nvidia-open" >/dev/null 2>&1 && ! modinfo nvidia 2>/dev/null | grep -iq "license.*dual"; then
    echo "----------------------------------------------------------------------"
    echo "[!] OSTRZEŻENIE: Nie wykryto modułu jądra NVIDIA Open!"
    echo "    Karty Blackwell (RTX 50xx) wymagają modułów open-source."
    echo "    Zainstaluj: 'nvidia-open-dkms' (lub 'nvidia-open') oraz kernel headers."
    echo "----------------------------------------------------------------------"
    read -r -p "Naciśnij [Enter], aby kontynuować mimo to, lub Ctrl+C, aby przerwać..."
else
    echo "[+] Wykryto moduł jądra NVIDIA Open."
fi

echo "=== 2. Kopiowanie backendu CLI do /usr/local/bin/blackwell-egpu ==="
sudo cp "$BACKEND_SRC" /usr/local/bin/blackwell-egpu
sudo chmod +x /usr/local/bin/blackwell-egpu
echo "[+] Zainstalowano /usr/local/bin/blackwell-egpu"

echo "=== 3. Konfiguracja uprawnień sudoers ==="
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/local/bin/blackwell-egpu" | sudo tee "/etc/sudoers.d/blackwell-egpu" > /dev/null
sudo chmod 0440 "/etc/sudoers.d/blackwell-egpu"
echo "[+] Skonfigurowano /etc/sudoers.d/blackwell-egpu"

echo "=== 4. Konfiguracja reguł udev ==="
read -r -p "Zainstalować reguły udev blokujące automatyczny rozruch modułów na USB4/TB? [Y/n]: " UDEV_CHOICE
UDEV_CHOICE=${UDEV_CHOICE:-Y}

if [[ "$UDEV_CHOICE" =~ ^[YyTt]$ ]]; then
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
    echo "[+] Reguły udev zostały zainstalowane."
else
    echo "[*] Pominięto instalację reguł udev."
fi

echo "=== 5. Instalacja apletu KDE Plasma 6 ==="
if [ -d "$APPLET_SRC" ]; then
    mkdir -p "$PLASMA_PLASMOIDS_DIR"
    rm -rf "$PLASMA_PLASMOIDS_DIR/com.github.blackwellegpu"
    cp -r "$APPLET_SRC" "$PLASMA_PLASMOIDS_DIR/"
    echo "[+] Aplet został skopiowany do $PLASMA_PLASMOIDS_DIR/com.github.blackwellegpu"

    # Czyszczenie pamięci podręcznej QML
    rm -rf "$HOME/.cache/plasma"* "$HOME/.cache/qmlcache"*

    read -r -p "Zrestartować Plasmashell, aby załadować nowy aplet? [Y/n]: " RESTART_CHOICE
    RESTART_CHOICE=${RESTART_CHOICE:-Y}
    if [[ "$RESTART_CHOICE" =~ ^[YyTt]$ ]]; then
        killall plasmashell 2>/dev/null || true
        sleep 1
        nohup plasmashell >/dev/null 2>&1 &
        echo "[+] Plasmashell został zrestartowany."
    fi
else
    echo "[-] Nie znaleziono katalogu '$APPLET_SRC'. Pominięto instalację apletu."
fi

echo -e "\n[+] Instalacja zakończona pomyślnie!"
