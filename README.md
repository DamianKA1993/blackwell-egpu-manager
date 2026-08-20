# ⚡ Blackwell eGPU Manager (USB4 / TB4 / TB5)

Automated PCIe Gen4/Gen5 link training, clock stabilization, and display mode manager for **NVIDIA Blackwell (RTX 50xx)** eGPUs on Linux (KDE Plasma 6 Wayland / CachyOS / Arch).

![Preview](assets/preview.png)

---

## 🚀 Key Features

* **Dynamic Hardware Discovery**: Automatically detects GPU address, PCIe bridge topology, and GDDR7 VRAM limits in real-time. Zero hardcoded PCI addresses.
* **PCIe Gen4/Gen5 Retraining**: Overrides USB4 Link Training state machines to negotiate full 16 GT/s (PCIe 4.0 x4) or 32 GT/s (PCIe 5.0) links.
* **Zero-Idle-Crash Architecture**: Locks GSP firmware into P0 state with dynamic base/boost clock capping to prevent PCIe desyncs during idle.
* **3-State GPU Switching Engine**:
  * **State 0 (iGPU Only)**: Completely detaches eGPU from the bus and unloads drivers for pure integrated graphics.
  * **State 1 (Hybrid)**: Active iGPU + eGPU render-offload for internal laptop/mini-PC screens.
  * **State 2 (eGPU Dedicated)**: Dynamically unbinds AMD iGPU for zero display latency and maximum performance on external monitors.
* **Native KDE Plasma 6 Applet**: Compact tray icon with real-time hardware status and one-click mode switching.

---

## 📋 Requirements

* **OS**: Arch Linux, CachyOS, or other rolling-release distributions with Linux Kernel >= 6.10.
* **Desktop**: KDE Plasma 6 (Wayland recommended).
* **Driver**: `nvidia-open-dkms` or `nvidia-open`.
* **Hardware**:
  * NVIDIA RTX 50xx Series (Blackwell eGPU)
  * USB4 / Thunderbolt 4 / Thunderbolt 5 host & enclosure (Intel Barlow Ridge, Goshen Ridge, ASMedia ASM2464PD, etc.)
  * AMD Ryzen APU (Radeon 780M / 890M) or Intel Core Ultra.

---

## 🛠️ Quick Installation

Clone the repository and run the installer as a regular user:

```bash
git clone [https://github.com/DamianKA1993/blackwell-egpu-manager.git](https://github.com/DamianKA1993/blackwell-egpu-manager.git)
cd blackwell-egpu-manager
chmod +x install.sh uninstall.sh
./install.sh


🖥️ CLI Usage
The system can be controlled directly via terminal commands or automated scripts:

Bash
# Switch to Dedicated eGPU Mode (State 2: External Display, zero latency)
sudo blackwell-egpu mode2

# Switch to Hybrid Mode (State 1: Internal Display / Render-offload)
sudo blackwell-egpu mode1

# Detach eGPU (State 0: Pure iGPU Mode)
sudo blackwell-egpu mode0

# Query active state (returns mode0, mode1, or mode2)
blackwell-egpu status
🗑️ Uninstallation
To remove all installed scripts, udev rules, sudoers configurations, and the Plasma applet:

Bash
./uninstall.sh
📄 License
Distributed under the MIT License. See LICENSE for more information.
