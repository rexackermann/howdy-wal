import Gio from "gi://Gio";
import * as Main from "resource:///org/gnome/shell/ui/main.js";

export default class AudioFocusMonitor {
  enable() {
    this._file = Gio.File.new_for_path("/tmp/gnome-audio-status.json");
    this._players = new Map();

    // 1. Monitor Focus Changes
    this._focusId = global.display.connect("notify::focus-window", () =>
      this._update(),
    );

    // 2. Monitor Media Player (MPRIS) Changes
    this._dbusId = Gio.DBus.session.signal_subscribe(
      "org.freedesktop.DBus",
      "org.freedesktop.DBus",
      "NameOwnerChanged",
      null,
      null,
      Gio.DBusSignalFlags.NONE,
      (conn, sender, path, iface, signal, params) => {
        let [name, oldOwner, newOwner] = params.recursiveUnpack();
        if (name.startsWith("org.mpris.MediaPlayer2.")) {
          this._update();
        }
      },
    );

    this._update();
  }

  async _update() {
    let windows = global.get_window_actors().map((a) => a.meta_window);
    let focusedWin = global.display.focus_window;

    let report = {
      focused: focusedWin
        ? {
            pid: focusedWin.get_pid(),
            title: focusedWin.get_title(),
          }
        : null,
      audio_windows: [],
    };

    // Query all windows to see if they match a playing player
    // Note: For simplicity, we are capturing window list.
    // Real-time audio "level" is better handled by your bash script
    // but we can identify who IS a "Media Player" here.
    for (let win of windows) {
      report.audio_windows.push({
        pid: win.get_pid(),
        title: win.get_title(),
        is_focused: win === focusedWin,
      });
    }

    let bytes = new TextEncoder().encode(JSON.stringify(report, null, 2));
    this._file.replace_contents_async(
      bytes,
      null,
      false,
      Gio.FileCreateFlags.REPLACE_DESTINATION,
      null,
      null,
    );
  }

  disable() {
    if (this._focusId) global.display.disconnect(this._focusId);
    if (this._dbusId) Gio.DBus.session.signal_unsubscribe(this._dbusId);
  }
}
