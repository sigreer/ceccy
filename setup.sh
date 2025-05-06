#!/bin/bash

# Installs dependencies, creates a symlink from /usr/local/bin/cec-listener
# to the $(pwd)/cec-listener.sh script, and sets up a user systemd service.

set -e

# Optionally install dependencies (uncomment if needed)
# sudo apt-get update
# sudo apt-get install -y kscreen-doctor

# Create a symlink from /usr/local/bin/cec-listener to the cec-listener.sh script
sudo ln -sf $(pwd)/cec-listener.sh /usr/local/bin/cec-listener

echo "[setup] Symlink created: /usr/local/bin/cec-listener -> $(pwd)/cec-listener.sh"

# Create the user systemd service directory if it doesn't exist
mkdir -p ~/.config/systemd/user

# Create the user systemd service file
SERVICE_FILE=~/.config/systemd/user/cec-listener.service
cat > $SERVICE_FILE <<EOF
[Unit]
Description=HDMI-CEC Listener

[Service]
Type=simple
ExecStart=/usr/local/bin/cec-listener
Restart=on-failure

[Install]
WantedBy=default.target
EOF

echo "[setup] User systemd service created: $SERVICE_FILE"

echo "[setup] Enabling and starting the user service..."
systemctl --user daemon-reload
systemctl --user enable cec-listener.service
systemctl --user start cec-listener.service

echo "[setup] User service enabled and started."
echo "[setup] The cec-listener will now run in your user session."
echo "[setup] To check status: systemctl --user status cec-listener.service"
echo "[setup] To stop: systemctl --user stop cec-listener.service"
