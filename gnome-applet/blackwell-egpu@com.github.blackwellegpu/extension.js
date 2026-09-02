import GObject from 'gi://GObject';
import St from 'gi://St';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Clutter from 'gi://Clutter';
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

            this._buildQuickMenu();

            this._timeoutSource = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
                this._fetchStatusAsync();
                return GLib.SOURCE_CONTINUE;
            });

            this._fetchStatusAsync();
        }

        _buildQuickMenu() {
            this._section = new PopupMenu.PopupMenuSection();
            this.menu.addMenuItem(this._section);

            const rootBox = new St.BoxLayout({
                vertical: true,
                style_class: 'blackwell-panel',
            });
            this._section.actor.add_child(rootBox);

            // ==================== KARTA iGPU ====================
            const igpuCard = new St.BoxLayout({
                vertical: true,
                style_class: 'blackwell-card',
            });

            const igpuHeader = new St.BoxLayout({
                style_class: 'blackwell-card-header',
                y_align: Clutter.ActorAlign.CENTER,
            });
            const igpuIcon = new St.Icon({
                icon_name: 'computer-symbolic',
                icon_size: 22,
            });
            this._lblIgpuName = new St.Label({
                text: 'AMD Radeon Graphics',
                style_class: 'blackwell-section-title',
            });
            igpuHeader.add_child(igpuIcon);
            igpuHeader.add_child(this._lblIgpuName);

            this._lblIgpuDevice = new St.Label({
                text: 'Device: Scanning...',
                style_class: 'blackwell-sub-text',
            });
            this._lblIgpuStatus = new St.Label({
                text: 'Status: Active',
                style_class: 'blackwell-sub-text',
            });

            igpuCard.add_child(igpuHeader);
            igpuCard.add_child(this._lblIgpuDevice);
            igpuCard.add_child(this._lblIgpuStatus);
            rootBox.add_child(igpuCard);

            // ==================== KARTA eGPU ====================
            const egpuCard = new St.BoxLayout({
                vertical: true,
                style_class: 'blackwell-card',
            });

            const egpuBodyRow = new St.BoxLayout({
                vertical: false,
                x_expand: true,
            });

            // Lewa kolumna: identyfikacja i parametry połączenia
            const egpuLeftCol = new St.BoxLayout({
                vertical: true,
                x_expand: true,
            });
            const egpuHeader = new St.BoxLayout({
                style_class: 'blackwell-card-header',
                y_align: Clutter.ActorAlign.CENTER,
            });
            const egpuIcon = new St.Icon({
                icon_name: 'video-display-symbolic',
                icon_size: 22,
            });
            this._lblEgpuName = new St.Label({
                text: 'AORUS RTX AI BOX',
                style_class: 'blackwell-section-title',
            });
            egpuHeader.add_child(egpuIcon);
            egpuHeader.add_child(this._lblEgpuName);

            this._lblEgpuBox = new St.Label({
                text: 'Box: Scanning...',
                style_class: 'blackwell-sub-text',
            });
            this._lblEgpuAuth = new St.Label({
                text: 'Authorized: yes',
                style_class: 'blackwell-sub-text',
            });
            this._lblEgpuSpeed = new St.Label({
                text: 'Speed: N/A',
                style_class: 'blackwell-link-pill',
            });
            this._lblEgpuStatus = new St.Label({
                text: 'Status: Standby (Ready)',
                style_class: 'blackwell-sub-text',
            });

            egpuLeftCol.add_child(egpuHeader);
            egpuLeftCol.add_child(this._lblEgpuBox);
            egpuLeftCol.add_child(this._lblEgpuAuth);
            egpuLeftCol.add_child(this._lblEgpuSpeed);
            egpuLeftCol.add_child(this._lblEgpuStatus);

            // Prawa kolumna: telemetria + paski postępu
            this._metricsBox = new St.BoxLayout({
                vertical: true,
                style_class: 'blackwell-metrics-box',
                y_align: Clutter.ActorAlign.CENTER,
            });

            // Usage + pasek
            this._lblUsage = new St.Label({ text: 'Usage: 0% (0W)', style_class: 'blackwell-metric-row' });
            this._barUsageBg = new St.BoxLayout({ style_class: 'blackwell-bar-bg', x_expand: true });
            this._barUsageFill = new St.BoxLayout({ style_class: 'blackwell-bar-fill' });
            this._barUsageBg.add_child(this._barUsageFill);

            // VRAM + pasek
            this._lblVram = new St.Label({ text: 'VRAM: 0 / 16 GB', style_class: 'blackwell-metric-row' });
            this._barVramBg = new St.BoxLayout({ style_class: 'blackwell-bar-bg', x_expand: true });
            this._barVramFill = new St.BoxLayout({ style_class: 'blackwell-bar-fill' });
            this._barVramBg.add_child(this._barVramFill);

            this._lblBus = new St.Label({ text: '↓ 0 MB/s  ↑ 0 MB/s', style_class: 'blackwell-metric-row' });
            this._lblTemp = new St.Label({ text: 'Temp: --°C', style_class: 'blackwell-metric-row' });

            this._metricsBox.add_child(this._lblUsage);
            this._metricsBox.add_child(this._barUsageBg);
            this._metricsBox.add_child(this._lblVram);
            this._metricsBox.add_child(this._barVramBg);
            this._metricsBox.add_child(this._lblBus);
            this._metricsBox.add_child(this._lblTemp);

            egpuBodyRow.add_child(egpuLeftCol);
            egpuBodyRow.add_child(this._metricsBox);
            egpuCard.add_child(egpuBodyRow);

            // ==================== KONTENER PRZYCISKÓW ====================
            const btnContainer = new St.BoxLayout({
                vertical: true,
                style_class: 'blackwell-btn-container',
            });

            // Wiersz 1
            this._row1 = new St.BoxLayout({ style_class: 'blackwell-btn-row', x_expand: true });
            
            this._btnConnect = new St.Button({
                label: 'Connect eGPU',
                style_class: 'blackwell-action-btn',
                x_expand: true,
                can_focus: true,
            });
            this._btnConnect.connect('clicked', () => {
                const currentMode = this._lastMode || 0;
                if (currentMode === 1) {
                    this._runCli(['set', '2']);
                } else if (currentMode === 4) {
                    this._runCli(['set', '5']);
                } else {
                    this._runCli(['set', '3']);
                }
            });

            this._btnScreenMgr = new St.Button({
                label: 'Screen Manager',
                style_class: 'blackwell-action-btn',
                x_expand: true,
                can_focus: true,
            });
            this._btnScreenMgr.connect('clicked', () => {
                try {
                    Gio.AppInfo.create_from_commandline('gnome-control-center display', null, Gio.AppInfoCreateFlags.NONE).launch([], null);
                } catch (e) {}
            });

            this._row1.add_child(this._btnConnect);
            this._row1.add_child(this._btnScreenMgr);

            // Wiersz 2
            this._row2 = new St.BoxLayout({ style_class: 'blackwell-btn-row', x_expand: true });

            this._btnEgpuOnly = new St.Button({
                label: 'eGPU Only (disconnect iGPU)',
                style_class: 'blackwell-action-btn',
                x_expand: true,
                can_focus: true,
            });
            this._btnEgpuOnly.connect('clicked', () => this._runCli(['set', '4']));

            this._btnDisconnect = new St.Button({
                label: 'Safely Remove eGPU',
                style_class: 'blackwell-action-btn',
                x_expand: true,
                can_focus: true,
            });
            this._btnDisconnect.connect('clicked', () => this._runCli(['set', '6']));

            this._row2.add_child(this._btnEgpuOnly);
            this._row2.add_child(this._btnDisconnect);

            this._lblWarning = new St.Label({
                text: 'Warning: Disabling the iGPU is experimental. Proceed at your own risk.',
                style_class: 'blackwell-warning-note',
            });

            btnContainer.add_child(this._row1);
            btnContainer.add_child(this._row2);
            btnContainer.add_child(this._lblWarning);
            egpuCard.add_child(btnContainer);

            rootBox.add_child(egpuCard);
        }

        _fetchStatusAsync() {
            try {
                const proc = new Gio.Subprocess({
                    argv: [CLI_PATH, 'status'],
                    flags: Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE,
                });
                proc.init(null);

                proc.communicate_utf8_async(null, null, (obj, res) => {
                    try {
                        const [, stdout] = obj.communicate_utf8_finish(res);
                        if (stdout) {
                            const data = JSON.parse(stdout.trim());
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
            const mode = Number(data.mode ?? 0);
            const isWaiting = Number(data.wait ?? 0) === 1;
            this._lastMode = mode;

            // iGPU
            this._lblIgpuName.text = data.igpu2 || data.igpu || 'Integrated Graphics';
            this._lblIgpuDevice.text = `Device: ${data.igpu || 'AMD Radeon Graphics'}`;

            if (mode === 4) {
                this._lblIgpuStatus.text = 'Status: Inactive';
            } else if (mode === 5) {
                this._lblIgpuStatus.text = 'Status: Active (Restored)';
            } else if (mode === 3) {
                this._lblIgpuStatus.text = 'Status: Primary Display';
            } else {
                this._lblIgpuStatus.text = 'Status: Active';
            }

            // eGPU
            if (mode >= 3 && mode <= 5) {
                this._lblEgpuName.text = data.egpu2 || 'NVIDIA GeForce RTX';
                this._lblEgpuBox.text = `Box: ${data.egpu || 'eGPU Enclosure'}`;
                this._lblEgpuBox.visible = true;
            } else {
                this._lblEgpuName.text = data.egpu2 || data.egpu || 'NVIDIA GeForce RTX';
                this._lblEgpuBox.visible = false;
            }

            this._lblEgpuAuth.text = mode >= 2 ? 'Authorized: yes' : 'Authorized: no';
            this._lblEgpuSpeed.text = `Speed: ${data.link || 'N/A'}`;

            let statusText = 'Status: Standby (Ready)';
            if (isWaiting) statusText = 'Status: Transitioning...';
            else if (mode === 3 || mode === 5) statusText = 'Status: Hybrid Offload';
            else if (mode === 4) statusText = 'Status: Dedicated Primary';
            else if (mode <= 1) statusText = 'Status: Disconnected';
            this._lblEgpuStatus.text = statusText;

            // Telemetria po prawej (Mode 3, 4, 5)
            if (mode >= 3 && mode <= 5) {
                this._metricsBox.visible = true;

                // Usage bar (0-100%)
                const utilInt = Math.min(100, Math.max(0, parseInt(data.gpu_util || '0', 10) || 0));
                this._lblUsage.text = `Usage: ${data.gpu_util || '0%'} (${data.pwr_curr || 0}W)`;
                this._barUsageFill.set_width(Math.round((utilInt / 100) * 165));

                // VRAM bar (0-100%)
                const vramUsed = data.vram_used || 0;
                const vramTotal = data.vram_total || 16380;
                const vramPct = Math.min(100, Math.max(0, (vramUsed / vramTotal) * 100));
                const vramGb = (vramUsed / 1024).toFixed(1);
                const totalGb = Math.round(vramTotal / 1024);
                this._lblVram.text = `VRAM: ${vramGb} / ${totalGb} GB`;
                this._barVramFill.set_width(Math.round((vramPct / 100) * 165));

                // tx z lewej (↓), rx z prawej (↑)
                this._lblBus.text = `↓ ${data.pcie_tx || 0} MB/s  ↑ ${data.pcie_rx || 0} MB/s`;
                this._lblTemp.text = `Temp: ${data.temp || 0}°C`;
            } else {
                this._metricsBox.visible = false;
            }

            // Stany przycisków
            const locked = isWaiting || mode === 0;

            if (mode === 1) {
                this._btnConnect.label = 'Authorize';
                this._btnConnect.reactive = !locked;
                this._btnConnect.visible = true;

                this._btnScreenMgr.visible = false;
                this._row2.visible = false;
                this._lblWarning.visible = false;

            } else if (mode === 2) {
                this._btnConnect.label = 'Connect eGPU';
                this._btnConnect.reactive = !locked;
                this._btnConnect.visible = true;

                this._btnScreenMgr.visible = false;
                this._row2.visible = false;
                this._lblWarning.visible = false;

            } else if (mode === 3) {
                this._btnConnect.label = 'eGPU Active';
                this._btnConnect.reactive = false;
                this._btnConnect.visible = true;

                this._btnScreenMgr.visible = true;
                this._row2.visible = true;
                this._lblWarning.visible = true;

                this._btnEgpuOnly.visible = true;
                this._btnEgpuOnly.reactive = !locked;
                this._btnDisconnect.reactive = !locked;

            } else if (mode === 4) {
                this._btnConnect.label = 'Connect iGPU';
                this._btnConnect.reactive = !locked;
                this._btnConnect.visible = true;

                this._btnScreenMgr.visible = true;
                this._row2.visible = false;
                this._lblWarning.visible = false;

            } else if (mode === 5) {
                this._btnConnect.label = 'eGPU Active';
                this._btnConnect.reactive = false;
                this._btnConnect.visible = true;

                this._btnScreenMgr.visible = true;
                this._row2.visible = false;
                this._lblWarning.visible = false;

            } else {
                this._btnConnect.label = 'eGPU Disconnected';
                this._btnConnect.reactive = false;
                this._btnConnect.visible = true;

                this._btnScreenMgr.visible = false;
                this._row2.visible = false;
                this._lblWarning.visible = false;
            }
        }

        _setOfflineUi() {
            this._lblIgpuStatus.text = 'Status: Active';
            this._lblEgpuStatus.text = 'Status: Disconnected';
            this._lblEgpuSpeed.text = 'Speed: N/A';
            this._lblEgpuBox.visible = false;
            this._metricsBox.visible = false;
            this._barUsageFill.set_width(0);
            this._barVramFill.set_width(0);
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
