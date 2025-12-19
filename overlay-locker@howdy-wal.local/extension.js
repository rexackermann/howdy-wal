import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const DBUS_XML = `
<node>
  <interface name="org.gnome.Shell.Extensions.HowdyWalOverlay">
    <method name="ShowLock">
      <arg type="b" direction="out" name="success"/>
    </method>
    <method name="ShowPasswordPrompt">
      <arg type="b" direction="out" name="success"/>
    </method>
    <method name="HideLock">
      <arg type="b" direction="out" name="success"/>
    </method>
    <signal name="InputDetected"/>
    <signal name="PasswordSubmitted">
      <arg type="s" name="password"/>
    </signal>
  </interface>
</node>`;

export default class HowdyWalOverlayExtension {
    enable() {
        this._dbusImpl = Gio.DBusExportedObject.wrapJSObject(DBUS_XML, this);
        this._dbusImpl.export(Gio.DBus.session, '/org/gnome/Shell/Extensions/HowdyWalOverlay');

        this._overlay = null;
        this._entry = null;
        this._statusLabel = null;
        this._isLocked = false;

        this._escapeCount = 0;
        this._lastEscapeTime = 0;
    }

    disable() {
        this._cleanup();
        if (this._dbusImpl) {
            this._dbusImpl.unexport();
            this._dbusImpl = null;
        }
    }

    ShowLock() {
        console.log('HowdyWal: ShowLock requested');
        if (this._isLocked) return true;

        try {
            this._overlay = new St.Widget({
                name: 'howdy-wal-overlay',
                style: 'background-color: black;',
                reactive: true,
                can_focus: true,
                x: 0,
                y: 0,
                width: global.screen_width,
                height: global.screen_height,
            });

            Main.layoutManager.addChrome(this._overlay, {
                affectsInputRegion: true,
                trackFullscreen: true,
            });

            if (Main.pushModal(this._overlay)) {
                this._isLocked = true;
                this._setupInputMonitoring();
                this._createStatusLabel();
                return true;
            } else {
                console.error('HowdyWal: Failed to push modal');
                this._cleanup();
                return false;
            }
        } catch (e) {
            console.error('HowdyWal Error in ShowLock: ' + e);
            this._cleanup();
            return false;
        }
    }

    _createStatusLabel() {
        if (!this._overlay) return;
        this._statusLabel = new St.Label({
            text: 'HOWDY-WAL PROTECTED',
            style: 'font-family: monospace; font-size: 12px; color: #003300;',
        });

        // Primary monitor corner
        let monitor = Main.layoutManager.primaryMonitor;
        this._statusLabel.set_position(
            monitor.x + monitor.width - 200,
            monitor.y + monitor.height - 30
        );

        this._overlay.add_child(this._statusLabel);
    }

    _showScanning() {
        if (!this._statusLabel) return;
        this._statusLabel.set_text('SCANNING...');
        this._statusLabel.set_style('font-family: monospace; font-size: 24px; color: #00FF00; font-weight: bold;');

        let monitor = Main.layoutManager.primaryMonitor;
        this._statusLabel.set_position(
            monitor.x + (monitor.width - 150) / 2,
            monitor.y + monitor.height - 100
        );
    }

    ShowPasswordPrompt() {
        if (!this._isLocked || this._entry) return false;

        try {
            if (this._statusLabel) {
                this._statusLabel.set_text('PASSWORD REQUIRED:');
                this._statusLabel.set_style('font-family: monospace; font-size: 16px; color: #FF0000;');
            }

            this._entry = new St.Entry({
                style: 'font-size: 24px; color: white; background-color: #111; border: 2px solid #555; padding: 10px;',
                hint_text: 'Enter Password...',
                can_focus: true,
            });

            let monitor = Main.layoutManager.primaryMonitor;
            this._entry.set_size(400, 60);
            this._entry.set_position(
                monitor.x + (monitor.width - 400) / 2,
                monitor.y + (monitor.height - 60) / 2
            );

            this._overlay.add_child(this._entry);
            this._entry.grab_focus();

            this._entry.clutter_text.connect('activate', () => {
                let pass = this._entry.get_text();
                this._dbusImpl.emit_signal('PasswordSubmitted', GLib.Variant.new('(s)', [pass]));
                this._entry.set_text('');
            });
            return true;
        } catch (e) {
            console.error('HowdyWal: Password prompt failed: ' + e);
            return false;
        }
    }

    HideLock() {
        console.log('HowdyWal: HideLock requested');
        this._cleanup();
        return true;
    }

    _setupInputMonitoring() {
        if (!this._overlay) return;

        this._overlay.connect('event', (actor, event) => {
            let type = event.type();

            // Triple Escape Panic
            if (type === Clutter.EventType.KEY_PRESS && event.get_key_symbol() === Clutter.KEY_Escape) {
                let now = Date.now();
                if (now - this._lastEscapeTime < 1000) this._escapeCount++;
                else this._escapeCount = 1;
                this._lastEscapeTime = now;

                if (this._escapeCount >= 3) {
                    this._cleanup();
                    return Clutter.EVENT_STOP;
                }
            }

            // Propagate input to entry if it exists
            if (this._entry) return Clutter.EVENT_PROPAGATE;

            // Trigger wake on any substantial interaction
            if (type === Clutter.EventType.KEY_PRESS ||
                type === Clutter.EventType.BUTTON_PRESS ||
                type === Clutter.EventType.TOUCH_BEGIN) {

                this._showScanning();
                this._dbusImpl.emit_signal('InputDetected', null);
            }
            return Clutter.EVENT_STOP;
        });
    }

    _cleanup() {
        console.log('HowdyWal: Executing Cleanup (isLocked: ' + this._isLocked + ')');

        try {
            // 1. Force release modal first
            if (this._isLocked) {
                Main.popModal(this._overlay);
            }
        } catch (e) { console.error('HowdyWal: Modal pop failed: ' + e); }

        this._isLocked = false;
        this._escapeCount = 0;

        // 2. Destroy and remove children
        try { if (this._entry) { this._entry.destroy(); this._entry = null; } } catch (e) { }
        try { if (this._statusLabel) { this._statusLabel.destroy(); this._statusLabel = null; } } catch (e) { }

        // 3. Remove chrome and destroy overlay actor
        try {
            if (this._overlay) {
                Main.layoutManager.removeChrome(this._overlay);
                this._overlay.destroy();
                this._overlay = null;
            }
        } catch (e) { console.error('HowdyWal: Overlay destruction failed: ' + e); }

        console.log('HowdyWal: Cleanup Finished');
    }
}
