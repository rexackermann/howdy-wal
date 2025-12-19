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

        // Escape panic state
        this._escapeCount = 0;
        this._lastEscapeTime = 0;
    }

    disable() {
        this.HideLock();
        if (this._dbusImpl) {
            this._dbusImpl.unexport();
            this._dbusImpl = null;
        }
    }

    ShowLock() {
        // Force cleanup of any stray overlays first (Stateless Defense)
        this._cleanupStrays();

        try {
            this._overlay = new St.Widget({
                name: 'howdy-wal-overlay-actor',
                style: 'background-color: black;',
                reactive: true,
                can_focus: true,
                x: 0,
                y: 0,
                width: global.screen_width,
                height: global.screen_height,
            });

            // Add to the Shell's UI Group (highest layer)
            Main.uiGroup.add_child(this._overlay);

            if (Main.pushModal(this._overlay)) {
                this._isLocked = true;
                this._setupInputMonitoring();
                this._createStatusLabel();
                return true;
            } else {
                this._cleanup();
                return false;
            }
        } catch (e) {
            this._cleanup();
            return false;
        }
    }

    _cleanupStrays() {
        // Scan the UI Group for anything named like our overlay and kill it
        let children = Main.uiGroup.get_children();
        for (let child of children) {
            if (child.name === 'howdy-wal-overlay-actor') {
                try {
                    Main.popModal(child);
                } catch (e) { }
                child.destroy();
            }
        }
    }

    _createStatusLabel() {
        if (!this._overlay) return;
        this._statusLabel = new St.Label({
            text: '🛡️ WAL SECURED',
            style: 'font-family: monospace; font-size: 11px; color: #003300;',
        });
        let monitor = Main.layoutManager.primaryMonitor;
        this._statusLabel.set_position(monitor.x + monitor.width - 120, monitor.y + monitor.height - 30);
        this._overlay.add_child(this._statusLabel);
    }

    _showScanning() {
        if (!this._statusLabel || this._entry) return;
        this._statusLabel.set_text('📸 SCANNING...');
        this._statusLabel.set_style('font-family: monospace; font-size: 20px; color: #00FF00; font-weight: bold;');
        let monitor = Main.layoutManager.primaryMonitor;
        this._statusLabel.set_position(monitor.x + (monitor.width - 150) / 2, monitor.y + monitor.height - 150);
    }

    ShowPasswordPrompt() {
        if (!this._isLocked || this._entry) return false;

        try {
            if (this._statusLabel) {
                this._statusLabel.set_text('⌨️ PASSWORD REQUIRED:');
                this._statusLabel.set_style('font-family: monospace; font-size: 16px; color: #FF0000;');
            }

            this._entry = new St.Entry({
                style: 'font-size: 24px; color: white; background-color: #111; border: 1px solid #333; padding: 10px;',
                hint_text: '...',
                can_focus: true,
            });

            let monitor = Main.layoutManager.primaryMonitor;
            this._entry.set_size(400, 60);
            this._entry.set_position(monitor.x + (monitor.width - 400) / 2, monitor.y + (monitor.height - 100) / 2);

            this._overlay.add_child(this._entry);
            this._entry.grab_focus();

            this._entry.clutter_text.connect('activate', () => {
                let pass = this._entry.get_text();
                this._dbusImpl.emit_signal('PasswordSubmitted', GLib.Variant.new('(s)', [pass]));
                this._entry.set_text('');
            });
            return true;
        } catch (e) { return false; }
    }

    HideLock() {
        this._cleanup();
        return true;
    }

    _setupInputMonitoring() {
        if (!this._overlay) return;

        // Listen to events on the stage to ensure we catch ESC even if modal is shaky
        this._overlay.connect('event', (actor, event) => {
            let type = event.type();

            // EMERGENCY BYPASS (Triple ESC)
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

            if (this._entry) return Clutter.EVENT_PROPAGATE;

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
        // Total Stateless Cleanup
        this._isLocked = false;
        this._escapeCount = 0;

        try {
            if (this._overlay) {
                Main.popModal(this._overlay);
            }
        } catch (e) { }

        // Proactively kill everything with our name
        this._cleanupStrays();

        this._overlay = null;
        this._entry = null;
        this._statusLabel = null;
    }
}
