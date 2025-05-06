# Use HDMI-CEC (TV Remote) to Execute Linux Commands

## Keymap for Samsung TV

|Key|CEC|
|---|---|
|1|04:44:21|
|2|04:44:22|
|3|04:44:23|
|4|04:44:24|
|5|04:44:25|
|6|04:44:26|
|7|04:44:27|
|8|04:44:28|
|9|04:44:29|
|0|04:44:20|
|up|04:44:01|
|down|04:44:02|
|left|04:44:03|
|right|04:44:04|
|enter|04:44:00|
|return|04:44:0d|
|exit|04:44:0c|
|red|04:44:72|
|green|04:44:73|
|yellow|04:44:74|
|blue|04:44:71|
|previous|04:44:48|
|play|04:44:44|
|pause|04:44:46|
|next|04:44:49|

---

## cec-listener Functionality & Usage

### Overview

`cec-listener.sh` allows you to use your TV remote (via HDMI-CEC) to trigger Linux desktop actions and scripts. It listens for CEC keypresses and maps them to system commands, notifications, and display management actions.

### Key Actions

- **Shutdown (Next button)**: Press the `Next` button (`44:49`) to trigger a shutdown confirmation. Confirm with `Next` or `Enter` within 10 seconds to proceed, or press any other button to cancel.
- **Test Prompt (Blue button)**: Press the `Blue` button (`44:71`) to show a test confirmation dialog. Confirm with `Blue` or `Enter` within 10 seconds.
- **Yellow Button (Single/Double Press)**:
  - *Single press* (`44:74`): Runs the `panelswitch` command.
  - *Double press* (two `Yellow` presses within 3 seconds): Toggles the DP-3 display (off/on). When re-enabled, geometry, scale, and priority are restored. (Wayland compatible via `kscreen-doctor`.)
- **Other keys**: Up, Down, Left, Right, Red, Green, etc., are logged and can be mapped to custom actions in the script.

### Setup & Installation

1. **Install dependencies** (if not already):

   ```sh
   sudo apt-get install kscreen-doctor

   ```

2. **Run the setup script:**

   ```sh
   ./setup.sh

   ```
   
   This will:
   - Create a symlink `/usr/local/bin/cec-listener`
   - Install a user systemd service (`~/.config/systemd/user/cec-listener.service`)
   - Enable and start the service in your user session

3. **Check service status:**

   ```sh
   systemctl --user status cec-listener.service
   ```

### Notes & Caveats

- The service runs as your user and requires a graphical session (Wayland or X11).
- Display management (enabling/disabling/toggling outputs) is handled via `kscreen-doctor` for Wayland compatibility.
- The script is always running in your user session; no udev rules are required.
- You can customize key actions by editing `cec-listener.sh`.
