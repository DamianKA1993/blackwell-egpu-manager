# ⚡ Blackwell eGPU Universal Manager (USB4 / TB4 / TB5)

Automated PCIe Gen4/Gen5 hardware state management, USB4 link negotiation, and display switching for **NVIDIA Blackwell (RTX 50xx)** eGPUs on Linux (KDE Plasma 6 Wayland / CachyOS / Arch Linux).

![Preview](assets/preview.png)

---

## 🚀 Key Features

* **Dynamic Multi-Platform Discovery**: Real-time detection of host iGPU (AMD Phoenix/HawkPoint/Strix APUs and Intel 11th Gen+ Tiger Lake / Iris Xe / Core Ultra) and NVIDIA RTX 50-series Blackwell eGPUs with zero hardcoded PCI paths.
* **Ghost-Free Hardware State Engine**: Direct synchronous querying of `/sys/bus/pci/devices/` and `boltctl` connection states, eliminating phantom devices during hot-unplug events.
* **PCIe 4.0 / USB4 Link Negotiation**: Real-time link speed detection and display (up to 16 GT/s PCIe 4.0 x4) across Intel Barlow Ridge, Goshen Ridge, and ASMedia ASM2464PD bridges.
* **5-Mode Hardware State Switching Engine**:
  * **Mode 0 (Disconnected)**: USB4 / PCIe bus detached; zero power draw.
  * **Mode 1 (Unauthorized)**: Device detected via USB4/Thunderbolt, awaiting host authorization.
  * **Mode 2 (Standby / Ready)**: Controller authorized, card recognized on PCIe bus and kept in low-power standby (D3cold).
  * **Mode 3 (Hybrid Offload / PRIME)**: Active iGPU runs desktop displays while RTX 5060 Ti handles on-demand GPU offloading (`prime-run` / CUDA / Vulkan).
  * **Mode 4 (Dedicated Primary)**: Dedicated GPU rendering session for external display setups.
* **Modular Interactive Installer**: Interactive setup script with independent steps for udev rules, sudoers privileges, and desktop widget deployment.
* **Native KDE Plasma 6 Applet**: Standalone Plasmoid with fixed proportions ($24 \times 24\ \text{gridUnit}$), live link-speed badge, and vertically centered control buttons.

---

## 📋 Requirements

* **OS**: CachyOS, Arch Linux, or other rolling-release distributions with Linux Kernel >= 6.10 (tested on Linux 7.2.0-cachyos).
* **Desktop**: KDE Plasma 6 (Wayland recommended; purely optional for standalone CLI usage).
* **Driver & Dependencies**:
  * NVIDIA Open Kernel Modules: `linux-cachyos-nvidia-open`, `nvidia-open-dkms`, or `nvidia-open` (610.xx+ driver series).
  * System tools: `nvidia-utils` (for NVML / `nvidia-smi`) and `bolt` (for Thunderbolt/USB4 device authorization).
* **Supported Hardware**:
  * **eGPU**: NVIDIA RTX 50-series (Blackwell architecture, e.g. AORUS RTX 5060 Ti AI BOX).
  * **USB4 / TB Bridges**: Intel Barlow Ridge (`0x5786`), Goshen Ridge / Titan Ridge (`0x15eb`, `0x0b26`), ASMedia ASM2464PD (`0x2464`).
  * **Host CPU / iGPU**:
    * AMD Ryzen APU (Phoenix, HawkPoint, Strix Point with Radeon 780M / 890M).
    * Intel Core / Core Ultra (11th Gen Tiger Lake with Iris Xe up to Meteor Lake / Arrow Lake).

---

## 🛠️ Quick Installation

Clone the repository and run the interactive installer as a regular user:

```bash
git clone [https://github.com/DamianKA1993/blackwell-egpu-manager.git](https://github.com/DamianKA1993/blackwell-egpu-manager.git)
cd blackwell-egpu-manager
chmod +x install.sh uninstall.sh
./install.sh
The installer will interactively guide you through:

Verifying NVIDIA Open kernel module presence.

Installing the /usr/local/bin/blackwell-egpu backend CLI.

Setting up passwordless sudoers permissions for state switching.

(Optional) Deploying udev rules to prevent PCIe link stalls during hot-plug.

(Optional) Deploying the KDE Plasma 6 widget to ~/.local/share/plasma/plasmoids.

🖥️ CLI Usage
The backend CLI can be managed independently from scripts, keybindings, or terminals:

Bash
# Query current state (returns JSON formatted status)
blackwell-egpu status

# Authorize USB4/TB connection (Mode 1 -> Mode 2)
sudo blackwell-egpu set 2

# Switch to Hybrid Offload (Mode 3: PRIME render offload)
sudo blackwell-egpu set 3

# Switch to Dedicated eGPU Mode (Mode 4: Primary eGPU display)
sudo blackwell-egpu set 4

# Put eGPU into Standby / Detach (Mode 2)
sudo blackwell-egpu set 2
🗑️ Uninstallation
To cleanly remove all installed binaries, udev configurations, sudoers rules, and the Plasma applet:

Bash
./uninstall.sh
📄 License
Distributed under the MIT License. See LICENSE for more information.
