# Known Issues & Hardware Quirks

This document tracks known limitations, hardware-specific edge cases, and in-progress fixes for the Blackwell eGPU Manager.

---

### 1. Mode 5 (iGPU Restore): Black screen on Intel internal laptop panels (eDP)
* **Status:** In Progress / Open
* **Affected Platforms:** Laptops with Intel integrated graphics (e.g., Tiger Lake / Iris Xe / Core Ultra) running Wayland (KWin).
* **Unaffected Platforms:** Desktop / Mini PC setups (e.g., AMD HawkPoint) with external DP/HDMI monitors.
* **Symptom:**
  After executing `Mode 5` (iGPU Restore) from `Mode 4` (eGPU-only), the internal laptop display (`eDP-1`) is enumerated and marked as active in Display Settings, but the physical panel remains dark/black.
* **Root Cause (Hypothesis):**
  The driver rebind / PCIe rescan sequence properly restores the device node and pipeline in KWin, but fails to re-initialize the panel power sequencing or backlight PWM duty cycle (`intel_backlight`) via the embedded DisplayPort (eDP) AUX channel.
* **Current Workaround:**
  A full system reboot is currently required to wake up and restore display output on the internal laptop panel after executing `Mode 5`.

---

### 2. Audio Endpoint Priority Shift (Mode 3) & Disappearance (Mode 6)
* **Status:** Under Observation
* **Affected Platforms:** Laptops with built-in ALSA/SoundWire endpoints.
* **Symptom:**
  When entering `Mode 3`, the appearance of the NVIDIA HDMI/DP audio controller may cause PipeWire/WirePlumber to switch default sink routing or rename active speaker endpoints, though the internal audio device remains active and fully functional throughout `Mode 3`. Subsequently, after executing `Mode 6` (Safe Detach), the internal laptop audio device disappears entirely from the system's output list.
* **Current Workaround:**
  A full system reboot is currently required to restore the internal audio device after detaching the eGPU.
