# Changelog

All notable changes to the Blackwell eGPU Universal Manager project will be documented in this file.

## [1.5.5] - 2026-09-05

### Added
* **Mode 6 (Safe Detach) – Selective Application Termination:** Implemented two-stage detection and termination for client processes actively rendering or computing on the eGPU using `nvidia-smi pmon` (`SIGTERM`, followed by `SIGKILL` on subsequent invocation).
* **Two-Step Detach Protection:** When invoking Safe Detach (via applet or CLI), a graceful `SIGTERM` is issued first. If applications fail to exit in time, the card **is not removed** from the PCIe bus; a second invocation of `set 6` is required to force termination via `SIGKILL` and safely complete the detach sequence.
* **Compositor & Session Safety:** Targeted process handling strictly isolates client applications running on the eGPU without terminating Wayland, KWin, or the user desktop session.

### Changed
* **Mode 6 (Safe Detach) Audio Teardown Removal:** Completely removed the automatic eGPU audio teardown routine — it did not resolve quirks on Intel platforms and could cause audio output drops (such as USB DACs and soundbars disappearing) on other hardware configurations.

## [1.5.4] - 2026-09-04

### 🔧 Fixes & Improvements

* **Reliable Wayland Safe Detach (Mode 6 Architectural Fix):**
  * Replaced passive DRM `change` uevents and problematic runtime module unloading (`modprobe -r`) with targeted synthetic DRM device removal (`udevadm trigger --action=remove`).
  * Explicitly triggers removal directly on NVIDIA DRM sysfs nodes (`/sys/bus/pci/devices/$GPU_FULL_PCI/drm/*`), forcing the Wayland compositor (KWin) and `libseat` to gracefully revoke access and close open DRM file descriptors (`/dev/dri/cardX`, `renderD12X`).
  * Completely eliminates Wayland compositor freezes, SIGBUS aborts, and unkillable kernel D-state I/O hangs when transitioning from Mode 3 back to Mode 2.
  * Verified rock-solid stability and zero-crash hot-unplug transitions across both AMD (HawkPoint) and Intel mobile platforms.

* **Targeted eGPU Function Removal with Vendor Guard:**
  * Replaced indiscriminate PCIe sub-function teardown with a strict vendor-checked removal loop (`cat $dev/vendor == "0x10de"`).
  * Ensures that only eGPU-owned auxiliary hardware (such as NVIDIA HDMI/DP Audio endpoints) is unlinked from the PCIe bus during teardown, leaving host motherboard controllers and processor bridge hierarchies completely untouched.

* **Synchronized Teardown Handshake:**
  * Introduced explicit settling barriers (`udevadm settle` + 200 ms timing window) between DRM node revocation and physical PCIe device removal (`$dev/remove`).
  * Guarantees the compositor has fully migrated rendering pipelines and buffers back to the internal GPU before the hardware link is severed.

## [1.5.3] - 2026-09-03

### 🔧 Fixes & Improvements

* **Hardware-based GPU presence check (`lspci` over `lsmod`):**
  * Replaced module loading verification (`lsmod | grep "^nvidia "`) with direct PCI bus detection: `lspci -d 10de: -nn | grep -iE "VGA|3D"`.
  * Prevents erroneously skipping the bus rescan and `setpci` retraining sequence when NVIDIA kernel modules are loaded prematurely into RAM during cold boot.

* **Direct Root Port wake-up via sysfs:**
  * Added a targeted rescan loop for processor Root Ports (`/sys/bus/pci/devices/0000:00:*.*/rescan`) executed prior to the global bus rescan.
  * Forces host controller ports from the runtime `suspended` state (D3) to `active` (D0), resolving missing USB4/Thunderbolt tunnel enumeration during cold boot on Intel platforms (e.g., Tiger Lake).

* **Preserved AMD Mini PC & Hot-Plug compatibility:**
  * Uses the flexible `0000:00:*.*/rescan` pattern guarded by `[ -f "$rp" ]`, avoiding any hardcoded Intel bus IDs (such as `00:07.*`).
  * Retains the fallback `echo 1 > /sys/bus/pci/rescan`, ensuring seamless enumeration on AMD systems and immediate device detection during on-the-fly Hot-Plug events.

* **Zero kernel boot parameters (Zero Kernel Flags):**
  * Fully functional on the default stock kernel without requiring any custom flags or parameters in the bootloader cmdline.
  * Port wake-up,link retraining, and runtime power management are stil handled entirely within user space.

## [1.5.2] - 2026-09-02

### Changed
* **GNOME Extension Polling Interval Alignment:**
  * Adjusted the telemetry polling timer from 1 second to 2 seconds (`GLib.timeout_add_seconds`).
  * Aligns the GNOME Shell update rate with the KDE Plasmoid and Universal Tray while preventing overlapping 2-second `nvidia-smi dmon` sampling cycles executed by the backend.

## [1.5.1] - 2026-09-02

### Changed
* **GNOME Shell Extension Architectural Rewrite (Full Rewrite):**
  * The legacy v1.5.0 extension had critical architectural flaws and API incompatibilities that prevented it from functioning; the module was rewritten from scratch.
  * **Dynamic State Engine (Modes 0–6):** Introduced dynamic view handling responding to bus states: disconnected (`Mode 0`), authorization (`Mode 1`), ready (`Mode 2`), active profiles (`Modes 3–5`), and safe disconnect preparation (`Mode 6`).
  * **Real-Time Telemetry:** Implemented live eGPU hardware metrics: core load (`gpu_util`), board power draw (`pwr_curr`), memory footprint (`vram_used` / `vram_total`), and PCIe bus throughput.
  * **PCIe Bus Metric Direction:** Standardized PCIe telemetry direction — download/read (`↓ RX`) on the left, upload/write (`↑ TX`) on the right, matching the native KDE Plasma plasmoid layout.
  * **Dedicated Stylesheet (`stylesheet.css`):** Added a dedicated CSS stylesheet establishing uniform margins, fixed label widths, and clean panel typography.
  * Tested on GNOME 50.4 with no stability or compatibility issues detected.

* **Universal System Tray Architecture:**
  * Replaced `PySide6` with native `PyGObject` bindings (`gi.repository` with `AyatanaAppIndicator3` / `AppIndicator3` and `Gtk 3.0`).
  * Removed all `pip` and Qt-related dependencies — the tray runs out-of-the-box on clean GTK-based desktops (Cinnamon, XFCE, MATE, Ubuntu).
  * Standardized PCIe bus rate indicators (`↓ RX` / `↑ TX`) to match the GNOME and KDE implementations.
  * Tested and confirmed working reliably on Cinnamon and XFCE.
  * Potentially compatible with other desktop environments supporting AppIndicator/SNI (MATE, LXQt, Budgie, COSMIC, Deepin/DDE, and tiling window manager bars like i3bar, Polybar, Waybar in Sway/Hyprland) — untested.

* **Installer (`install.sh`) Improvements:**
  * Replaced PySide6 validation logic with reliable `AyatanaAppIndicator3` / `Gtk 3.0` dependency checks.
  * Streamlined GUI selection under KDE Plasma (native QML Plasmoid vs. headless CLI mode).
  * Automated UUID registration into `dconf`/`gsettings` for new GNOME extension installations.
  * Displayed a post-install prompt noting that a GNOME Shell restart (or session log out) is required for the new extension to appear on the top bar; the prompt warns about open application closures and defaults safely to "No".

* **Uninstaller (`uninstall.sh`) Improvements:**
  * Added instant extension deactivation (`gnome-extensions disable`), automated UUID removal from `org.gnome.shell enabled-extensions`, and a clean reset of the extension's dconf schema path.

## [1.5.0] - 2026-09-01

> **Notice:** The GNOME Shell extension and Universal Tray applets are currently **experimental / test-only components**. Until comprehensive real-world validation across targeted environments is completed, these components are omitted from the main `README.md` documentation. Users should strictly follow the existing `README.md` instructions and rely exclusively on the **KDE Plasma applet** or the **core CLI backend** for stable operation.

### Added
- **Dedicated GNOME Shell Extension (`gnome-applet`) [EXPERIMENTAL / UNTESTED]:** Native GJS extension targeting GNOME 45, 46, and 47 with asynchronous telemetry polling via `Gio.Subprocess`. *Note: This component has not been even tested in a live environment yet and is likely **unstable** or non-functional in its current state.*
- **Standalone Universal Tray (`universal-applet`):** PySide6-based system tray application targeting XFCE, Cinnamon, MATE, LXQt, and standalone window managers/Wayland compositors. *Note: Verified on CachyOS/KDE; requires further validation on other desktop environments. Not intended for out-of-the-box GNOME use without AppIndicator support.*
- **Dedicated udev Directory (`udev/`):** Extracted `99-blackwell-egpu.rules` into a separate directory for cleaner repository modularity and independent configuration maintenance.
- **Smart Desktop Environment Detection:** `install.sh` automatically detects the active desktop environment (KDE Plasma, GNOME Shell, or generic) and suggests the appropriate native integration by default.
- **Mutual Desktop Component Collision Handling:** Automated detection and optional cleanup of existing or alternative applets during fresh installations and environment transitions.
- **XDG Autostart Management:** Standardized `.desktop` service deployment for non-KDE/non-GNOME desktop sessions.

### Changed
- **Modular Repository Architecture:** Restructured GUI applets and system rules into isolated subdirectories (`plasma-applet/`, `gnome-applet/`, `universal-applet/`, `udev/`).
- **Standardized Domain Namespace:** Updated extension metadata and D-Bus integration identifiers to `blackwell-egpu@com.github.blackwellegpu`.
- **Enhanced Dependency Diagnostics:** Explicit runtime validation for `PySide6` with per-distribution package management hints (`pacman`, `apt`, `dnf`, `zypper`) and opt-in automated installation.
- **Installer Refactoring:** `install.sh` streamlined to copy discrete assets from `udev/` and applet subdirectories instead of embedding inline rule blocks.
- **Comprehensive Uninstaller (`uninstall.sh`):** Updated the uninstaller to detect and cleanly purge all newly introduced components, including GNOME extension files, standalone tray binaries, and XDG autostart entries alongside legacy Plasma assets.

### Fixed
- **PCIe Rescan Enumeration Race Condition (`set3`):** Added a polling retry loop to wait for NVIDIA PCIe identifiers (`10de:`) to settle following bus rescan, preventing premature fallback to Mode 2 caused by silent subprocess execution.
- **Subshell Stream & State Leaks:** Fully silenced `boltctl` and `setpci` calls (`>/dev/null 2>&1`) across Modes 2 and 3, preventing status tree output from corrupting state cache.
- **Non-Blocking Telemetry Acquisition:** Eliminated main UI thread hangs during CLI status queries in the GNOME Shell extension.
- **Clean Migration Cleanup:** Fixed residual autostart entries and leftover binaries when switching between different applet types using `install.sh`.

## [1.4.1] - 2026-09-01

### Fixed
- **Process ID Leakage into State Cache:** Fully redirected stdout and stderr (`>/dev/null 2>&1`) across all `fuser` calls in `set3` and `set4`, preventing killed process IDs from corrupting `/tmp/blackwell_egpu/mode`.
- **Safe Detach Bus Teardown Guard:** Added explicit write and directory validation (`[ -w "$dev/remove" ]`) before triggering PCIe function removal in `set6`.
- **State File Output Sanitization:** Added deterministic numeric filtering (`tr -dc '0-9'`) and fallback handling when dispatching Mode 6 transitions.
- **Telemetry Cache Invalidation:** Ensured stale PCIe traffic metrics cache (`$TRAFFIC_CACHE`) is immediately cleared upon executing safe eGPU detach.

## [1.4.0] - 2026-08-31

### Added
- **Wayland Safe eGPU Detach (Mode 6):** Introduced a non-destructive hardware detaching procedure (`set6`) designed specifically for Wayland session compositors. Safely unbinds NVIDIA PCIe device functions, synchronizes DRM change events, and unloads kernel driver modules. **Note:** Operates strictly from Mode 3 (Hybrid Mode) prior to disabling the internal GPU, ensuring the compositor never loses its active rendering display controller.
- **Targeted iGPU Restoration (Mode 5):** Added full restoration routine (`set5`) for the integrated graphics adapter via selective PCIe parent bridge rescan (`igpu_parent_bridge`) and DRM uevent triggers.
- **Parent Bridge Tracking:** Integrated dynamic discovery and caching of the iGPU parent bridge address (`IGPU_PARENT_FILE`) prior to hardware node removal, ensuring deterministic sysfs rescans.
- **UI Safely Remove Action:** Added a dedicated "Safely Remove eGPU" action button inside the Plasmoid desktop widget for one-click hardware detachment directly from Mode 3.

### Changed & Fixed
- **Eliminated Kernel Deadlocks & D-State Hangs (set4):** Resolved severe kernel lockups (`kworker/usb_hub_wq`, `i2c_del_adapter`) during iGPU bus disconnects. Implemented a strict teardown sequence: clearing I2C/DRM file descriptor locks (`fuser`), emitting DRM change uevents, executing explicit `driver/unbind`, and then removing the PCI bus device node.
- **Dynamic Context-Aware UI Buttons:** The primary connect button in the Plasmoid widget dynamically switches between "Connect eGPU" and "Connect iGPU" depending on whether Mode 4 is currently active.
- **Refined Status Reporting:** Streamlined telemetry badges across all modes; returning from Mode 4 cleanly labels the iGPU as "Active (Restored)" while preserving standard "Hybrid Offload" status formatting for the eGPU.
- **Cascading State Machine Extension:** Updated the backend dispatch pipeline to handle mode escalations from 2 through 6, incorporating direct short-circuit jumps for Mode 6.
- **Full Multilingual Localization:** Synchronized and updated localization dictionaries (`i18n.js`) across all 9 supported languages (PL, DE, ES, FR, IT, PT, UK, CS, JA, ZH).

## [1.3.2] - 2026-08-30

### Performance & Telemetry Optimization
* **Non-Blocking Asynchronous Telemetry Pipeline**: Decoupled PCIe throughput sampling from the main status query loop. The `status` action now immediately serves cached metrics from `/tmp/blackwell_egpu/traffic` in ~25 ms (down from ~1200 ms), completely eliminating Plasma shell UI stutter and timer blocking.
* **Gapless 2-Second Background PCIe Sampling**: Configured background `nvidia-smi dmon` subshells with `-d 2` to collect full 2-second telemetry windows concurrently with QML timer ticks, ensuring continuous, gapless bandwidth tracking without UI latency.
* **Atomic File Updates**: Integrated atomic file replacement (`mv -f`) for cached telemetry data to prevent race conditions and partial reads during rapid status polling.
* **Codebase & Documentation Standardization**: Fully refactored the `ACTION="status"` command handler with structured bilingual code comments (English & Polish) and optimized indentation.

## [1.3.1] - 2026-08-30

### Bug Fixes & Reliability
* **Safe Enrolled eGPU Device Name Fallback in Standby (Mode 2)**: Resolved a driver query failure (`NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver`) occurring during system startup or hot-plug with persistent enrollment (`boltctl enroll`). In Mode 2, when NVIDIA kernel modules are not yet loaded, the backend now safely retrieves the hardware enclosure identity from `boltctl` metadata instead of attempting premature `nvidia-smi` queries. Full GPU model identification and telemetry remain cleanly deferred until driver initialization in Mode 3 / 4.

## [1.3.0] - 2026-08-30

### Hardware Management & Security
* **Persistent USB4/Thunderbolt Enrollment (`boltctl enroll`)**: Migrated the authorization mechanism from transient authorization (`boltctl authorize`) to persistent enrollment (`boltctl enroll`). Enrolled eGPU enclosures are now permanently trusted by the `boltd` daemon, enabling seamless automatic connection on system boot and hot-plug without requiring manual re-authorization.

### Telemetry & Real-Time Monitoring (Modes 3 & 4)
* **Real-Time eGPU Telemetry Engine**: Integrated live telemetry polling via `nvidia-smi dmon` backend parsing into the CLI daemon and QML UI.
* **Faster Polling Interval**: Reduced the main telemetry and UI refresh interval from 3000 ms to 2000 ms (2 seconds), providing snappier real-time responsiveness under dynamic workloads.
* **Core & Power Utilization**: Real-time monitoring of GPU core load percentage and dynamic package power draw in Watts (`Usage: X% (YW)`) with visual threshold-based load bar styling (warning color transition at ≥ 90%).
* **VRAM Tracking**: Added live dedicated video memory allocation display (`VRAM: X.X / Y GB`) with interactive capacity indicator bar (highlight/negative color transition at ≥ 90%).
* **Bidirectional PCIe Bus Throughput**: Real-time monitoring of active USB4/PCIe bus traffic relative to the host CPU:
  * `↓ TX (Host to Device)`: Real-time download/context feeding throughput with automatic dynamic highlighting when bandwidth exceeds 100 MB/s.
  * `↑ RX (Device to Host)`: Real-time upload/frame return throughput with automatic dynamic highlighting when bandwidth exceeds 100 MB/s.
* **Thermal Monitoring**: Dynamic GPU core temperature reporting (`Temp: X°C`) with multi-stage color thresholds for normal, warm (≥ 70°C), and critical (≥ 80°C) states.

### KDE Plasma 6 Applet (`com.github.blackwellegpu`)
* **Interactive Header & Pin Control**: Added a dedicated top navigation header featuring an interactive keep-open pin toggle (`Plasmoid.configuration.pin`) and back-navigation support, standardizing window behavior with native Plasma system dialogs.
* **Mode 2 Warning Visibility Fix**: Resolved an issue where the experimental iGPU disablement safety warning was erroneously hidden in Mode 2 (`Standby / Ready`), ensuring critical safety notices are consistently displayed across Modes 2, 3, and 4 when the `eGPU Only` toggle is accessible.
* **Responsive Anchor Layout**: Replaced rigid horizontal layouts (`RowLayout`) in the telemetry panel with anchor-based `Item` containers. Values and labels are locked to container margins (`anchors.left` / `anchors.right`), preventing text clipping and horizontal window expansion during multi-digit readouts (e.g. 4-digit throughput spikes).
* **Refined Right-Aligned Telemetry Column**: Set an optimized minimum width layout anchored to the right, ensuring clean aesthetic separation between hardware info and live telemetry metrics.
* **Metadata Alignment**: Synchronized `metadata.json` versioning to 1.3.0.


## [1.2.0] - 2026-08-23

### Core Features & Hardware Management
* **Experimental iGPU Disablement (Mode 4 / eGPU Only)**: Added full support for hot-unbinding and removing the host iGPU (and its associated processor audio endpoints) directly from the PCI bus tree to force dedicated eGPU operation. 
  * *Notice: Disabling the iGPU at runtime is highly experimental. Proceed with caution.*
* **Screen Management Integration**: Integrated a direct shortcut to KDE Display Settings (`kcmshell6 kcm_kscreen`) for seamless monitor layout configuration when entering dedicated modes.

### Internationalization & Localization (i18n)
* **Custom Lightweight i18n Engine (`i18n.js`)**: Implemented an in-applet JavaScript localization system (`.pragma library`) for Plasma 6, avoiding external Gettext/compiled `.mo` catalog issues.
* **Multi-Language Support**: Added built-in translation dictionaries for 10 languages:
  * Polish (`pl`), German (`de`), Spanish (`es`), French (`fr`), Italian (`it`), Portuguese (`pt`), Ukrainian (`uk`), Czech (`cs`), Japanese (`ja`), and Simplified Chinese (`zh`).
* **System Locale Auto-Detection**: Configured `i18n.js` to automatically detect the host desktop locale via `Qt.locale().name` with seamless English fallback for unlisted locales.
* **Bilingual Backend Documentation**: Updated the `blackwell-egpu` core CLI script with structured bilingual (English & Polish) code comments across all initialization, hardware verification, bus retraining, and mode-switching blocks.

### Installer (`install.sh`)
* **Interactive Localization Prompt**: Added an interactive step listing all supported languages and allowing users to enable auto-detected multi-language UI or enforce default English.
* **Streamlined English Translation**: Fully translated all terminal logs, setup notices, error prompts, and warnings to standard English for upstream GitHub compatibility.

### KDE Plasma 6 Applet (`com.github.blackwellegpu`)
* **Dynamic String Wrapping**: Integrated `root.tr()` wrappers across all UI components, status headers, buttons, and safety alerts in `main.qml`.

---

## [1.1.1] - 2026-08-22
fixed authorization

---

## [1.1.0] - 2026-08-22

### Architecture & Installation
* **Modular Installer (`install.sh`)**: Refactored the installer into an interactive, step-by-step wizard.
* **Decoupled KDE Plasma 6 Applet**: The Plasmoid is now completely optional; the backend CLI (`blackwell-egpu`) works fully independently in headless or pure terminal environments.
* **Automated Environment Setup**: Added automated checks for `nvidia-open` kernel modules, udev rule installation, `sudoers` rule generation, and Plasmashell cache reloading.

### KDE Plasma 6 Applet (`com.github.blackwellegpu`)
* **Fixed Geometry & Aspect Ratio**: Locked the root `fullRepresentation` bounds to a fixed 24x24 `gridUnit` container, completely resolving the dynamic window shrinking/collapsing bug.
* **Modern Plasma 6 System Layout**: Redesigned UI to match native system widgets (such as the Plasma Network & Bluetooth applets), including styled category separators and medium hardware icons.
* **Centrally Stacked Control Buttons**: Redesigned action buttons from a wide horizontal layout to a clean, vertically stacked list centered in the lower container area.
* **Text Wrapping & Typography**: Enabled multi-line text wrapping (`Text.Wrap`) on verbose device strings (such as long iGPU/eGPU PCI naming) to prevent UI overflow.

### Hardware State Detection & Backend
* **Eliminated Ghost Devices (Hot-Unplug)**: Replaced stale caching with direct, synchronous `/sys/bus/pci/devices/` queries and `boltctl` link checks. When disconnected, the applet immediately falls back to Mode 0 (`Disconnected`) without leaving leftover device traces.
* **Verified Dual-Platform Support**: Successfully validated Mode 0–4 switching, hot-plugging, cold boot, and real-time PCIe speed reporting (16GT/s) across AMD APU (HawkPoint) and Intel (Tiger Lake / Iris Xe) host systems.
* **Driver & Offload Integration**: Verified PRIME Render Offload (`Mode 3`) and Dedicated Mode (`Mode 4`) compatibility with `linux-cachyos-nvidia-open` (NVIDIA 610.xx driver series).

---

## [1.0.0] - 2026-08-20

### Initial Release
* Initial monolithic release of the `blackwell-egpu` CLI manager for RTX 50-series (Blackwell) eGPUs.
* Basic udev rules for Barlow Ridge (TB5), Goshen Ridge (TB4), and ASMedia ASM2464PD (USB4).
* Basic Plasma 6 applet prototype.
