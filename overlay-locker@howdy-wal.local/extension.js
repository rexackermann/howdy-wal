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
        this._overlay = null;
        this._entry = null;
        this._isLocked = false;
        this._escapeCount = 0;
        this._lastEscapeTime = 0;

        this._dbusImpl = Gio.DBusExportedObject.wrapJSObject(DBUS_XML, this);
        this._dbusImpl.export(Gio.DBus.session, '/org/gnome/Shell/Extensions/HowdyWalOverlay');
    }

    disable() {
        this.HideLock();
        if (this._dbusImpl) {
            this._dbusImpl.unexport();
            this._dbusImpl = null;
        }
    }

    ShowLock() {
        if (this._isLocked) return true;

        this._overlay = new St.Widget({
            name: 'howdy-wal-overlay',
            style: 'background-color: #000000;',
            reactive: true,
            can_focus: true,
        });

        this._overlay.set_position(0, 0);
        this._overlay.set_size(global.screen_width, global.screen_height);

        Main.layoutManager.addChrome(this._overlay, {
            affectsInputRegion: true,
            trackFullscreen: true,
        });

        if (Main.pushModal(this._overlay)) {
            this._isLocked = true;
            this._setupInputMonitoring();
            return true;
        } else {
            this._cleanup();
            return false;
        }
    }

    ShowPasswordPrompt() {
        if (!this._isLocked || this._entry) return false;

        this._entry = new St.Entry({
            style: 'font-size: 24px; padding: 10px; width: 400px; color: #00FF00; background-color: #111; border: 2px solid #00FF00; border-radius: 5px;',
            hint_text: 'Enter Password...',
            can_focus: true,
        });

        let monitor = Main.layoutManager.primaryMonitor;
        this._entry.set_position(
            monitor.x + (monitor.width - 400) / 2,
            monitor.y + (monitor.height - 50) / 2
        );

        this._overlay.add_child(this._entry);
        this._entry.grab_focus();

        this._entry.clutter_text.connect('activate', () => {
            let password = this._entry.get_text();
            this._dbusImpl.emit_signal('PasswordSubmitted', GLib.Variant.new('(s)', [password]));
            this._entry.destroy();
            this._entry = null;
        });

        return true;
    }

    HideLock() {
        this._cleanup();
        return true;
    }

    _setupInputMonitoring() {
        this._eventId = this._overlay.connect('event', (actor, event) => {
            let type = event.type();

            // EMERGENCY BYPASS: Triple-Escape in 1 second
            if (type === Clutter.EventType.KEY_PRESS && event.get_key_symbol() === Clutter.KEY_Escape) {
                let now = Date.now();
                if (now - this._lastEscapeTime < 1000) {
                    this._escapeCount++;
                } else {
                    this._escapeCount = 1;
                }
                this._lastEscapeTime = now;

                if (this._escapeCount >= 3) {
                    this.HideLock();
                    return Clutter.EVENT_STOP;
                }
            }

            if (this._entry)
                return Clutter.EVENT_PROPAGATE;

            if (type === Clutter.EventType.KEY_PRESS ||
                type === Clutter.EventType.BUTTON_PRESS ||
                type === Clutter.EventType.TOUCH_BEGIN) {

                this._dbusImpl.emit_signal('InputDetected', null);
            }
            return Clutter.EVENT_STOP;
        });
    }

    _cleanup() {
        if (this._overlay) {
            if (this._isLocked) {
                Main.popModal(this._overlay);
            }
            if (this._entry) {
                this._entry.destroy();
                this._entry = null;
            }
            Main.layoutManager.removeChrome(this._overlay);
            this._overlay.destroy();
            this._overlay = null;
        }
        this._isLocked = false;
        this._escapeCount = 0;
    }
}
