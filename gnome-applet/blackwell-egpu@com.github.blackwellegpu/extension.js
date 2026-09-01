import GObject from 'gi://GObject';
import St from 'gi://St';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const CLI_PATH = '/usr/local/bin/blackwell-egpu';

const BlackwellIndicator = GObject.registerClass(
    class BlackwellIndicator extends PanelMenu.Button {
        _init() {
            super._init(0.0, 'Blackwell eGPU Indicator');

            this._icon = new St.Icon({
                icon_name: 'video-display-symbolic',
                style_class: 'system-status-icon',
            });
            this.add_child(this._icon);

            this._buildMenu();

            // Asynchroniczne odpytywanie co 2 sekundy
            this._timeoutSource = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
                this._fetchStatusAsync();
                return GLib.SOURCE_CONTINUE;
            });

            this._fetchStatusAsync();
        }

        _buildMenu() {
            // Nagłówek
            const titleItem = new PopupMenu.PopupMenuItem('--- Blackwell eGPU Manager ---', { reactive: false });
            this.menu.addMenuItem(titleItem);
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            // Pozycje statusu / telemetrii
            this._lblGpu = new PopupMenu.PopupMenuItem('GPU: Checking...', { reactive: false });
            this._lblMode = new PopupMenu.PopupMenuItem('Mode: --', { reactive: false });
            this._lblPcie = new PopupMenu.PopupMenuItem('PCIe Link: --', { reactive: false });
            this._lblVram = new PopupMenu.PopupMenuItem('VRAM: --', { reactive: false });
            this._lblMetrics = new PopupMenu.PopupMenuItem('Temp / Power: --', { reactive: false });
            this._lblClocks = new PopupMenu.PopupMenuItem('Clocks / Fan: --', { reactive: false });

            this.menu.addMenuItem(this._lblGpu);
            this.menu.addMenuItem(this._lblMode);
            this.menu.addMenuItem(this._lblPcie);
            this.menu.addMenuItem(this._lblVram);
            this.menu.addMenuItem(this._lblMetrics);
            this.menu.addMenuItem(this._lblClocks);
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            // Przełączniki trybów
            this._actIgpu = new PopupMenu.PopupMenuItem('Integrated GPU Only (iGPU)');
            this._actIgpu.connect('activate', () => this._runCli(['set', 'igpu']));
            this.menu.addMenuItem(this._actIgpu);

            this._actOffload = new PopupMenu.PopupMenuItem('Hybrid Mode (Render Offload)');
            this._actOffload.connect('activate', () => this._runCli(['set', 'offload']));
            this.menu.addMenuItem(this._actOffload);

            this._actEgpuOnly = new PopupMenu.PopupMenuItem('⚠ Dedicated eGPU Only ⚠');
            this._actEgpuOnly.connect('activate', () => this._runCli(['set', 'egpu']));
            this.menu.addMenuItem(this._actEgpuOnly);

            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            this._actDisconnect = new PopupMenu.PopupMenuItem('Safely Disconnect / Remove eGPU');
            this._actDisconnect.connect('activate', () => this._runCli(['set', 'disconnect']));
            this.menu.addMenuItem(this._actDisconnect);
        }

        _fetchStatusAsync() {
            try {
                const proc = new Gio.Subprocess({
                    argv: [CLI_PATH, 'status', '--json'],
                    flags: Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE,
                });
                proc.init(null);

                proc.communicate_utf8_async(null, null, (obj, res) => {
                    try {
                        const [, stdout] = obj.communicate_utf8_finish(res);
                        if (stdout) {
                            const data = JSON.parse(stdout);
                            this._updateUi(data);
                        }
                    } catch (e) {
                        this._setOfflineUi();
                    }
                });
            } catch (e) {
                this._setOfflineUi();
            }
        }

        _updateUi(data) {
            const mode = (data.mode || 'unknown').toLowerCase();
            const connected = data.connected || false;

            this._lblGpu.label.text = `GPU: ${data.gpu_name || 'NVIDIA Graphics Device'}`;
            this._lblMode.label.text = `Current Mode: ${data.mode ? data.mode.toUpperCase() : 'N/A'}`;

            if (connected) {
                this._lblPcie.label.text = `PCIe: ${data.pcie_gen || 'Gen?'} x${data.pcie_width || '?'} (ASPM: ${data.aspm || 'N/A'})`;
                this._lblVram.label.text = `VRAM: ${data.vram_used_mb || 0} / ${data.vram_total_mb || 0} MB`;
                this._lblMetrics.label.text = `Temp: ${data.temp_c || '--'}°C  |  Power: ${data.power_w || '--'}W`;
                this._lblClocks.label.text = `Clock: ${data.gpu_clock_mhz || '--'}MHz  |  Fan: ${data.fan_speed_pct || 0}%`;
            } else {
                this._lblPcie.label.text = 'PCIe Link: Disconnected';
                this._lblVram.label.text = 'VRAM: --';
                this._lblMetrics.label.text = 'Temp / Power: --';
                this._lblClocks.label.text = 'Clocks / Fan: --';
            }

            // Aktualizacja stanów przycisków
            this._actIgpu.label.text = (mode === 'igpu' ? '● ' : '   ') + 'Integrated GPU Only (iGPU)';
            this._actIgpu.reactive = mode !== 'igpu';

            this._actOffload.label.text = (mode === 'offload' ? '● ' : '   ') + 'Hybrid Mode (Render Offload)';
            this._actOffload.reactive = mode !== 'offload';

            this._actEgpuOnly.label.text = (mode === 'egpu' ? '● ' : '   ') + '⚠ Dedicated eGPU Only ⚠';
            this._actEgpuOnly.reactive = mode !== 'egpu';

            this._actDisconnect.reactive = connected;
        }

        _setOfflineUi() {
            this._lblGpu.label.text = 'eGPU: Disconnected';
            this._lblMode.label.text = 'Mode: Offline / Standby';
            this._lblPcie.label.text = 'PCIe Link: --';
            this._lblVram.label.text = 'VRAM: --';
            this._lblMetrics.label.text = 'Temp / Power: --';
            this._lblClocks.label.text = 'Clocks / Fan: --';
        }

        _runCli(args) {
            const cmd = ['sudo', CLI_PATH, ...args];
            try {
                const proc = new Gio.Subprocess({
                    argv: cmd,
                    flags: Gio.SubprocessFlags.NONE,
                });
                proc.init(null);
            } catch (e) {
                logError(e, 'Failed to execute blackwell-egpu command');
            }
        }

        destroy() {
            if (this._timeoutSource) {
                GLib.Source.remove(this._timeoutSource);
                this._timeoutSource = null;
            }
            super.destroy();
        }
    });

export default class BlackwellExtension extends Extension {
    enable() {
        this._indicator = new BlackwellIndicator();
        Main.panel.addToStatusArea(this.uuid, this._indicator);
    }

    disable() {
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }
}
