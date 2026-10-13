#!/bin/bash
# EC2 user-data for the CDE 1.26 HOL without Docker (Amazon Linux 2023, x86_64).
# Installs Python 3.11, JupyterLab, the CDE CLI and the CDE 1.26 Spark Connect tarballs
# directly on the instance and serves JupyterLab on port 80.

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Redirect all output to a log file for easy debugging later
exec > /var/log/user-data.log 2>&1

# Optional: set a JupyterLab password. Leave empty for token-less access (restrict the security group!)
JUPYTER_PASSWORD=""

REPO_URL="https://github.com/pdefusco/CDE_126_HOL.git"
ASSETS_URL="https://github.com/pdefusco/CDE_126_HOL/releases/download/v1.26-assets"
CDE_CLI_ASSET="cde-linux-amd64"
PYSPARK_TARBALL="pyspark-3.5.4.tar.gz"

HOL_USER="ec2-user"
HOL_HOME="/home/${HOL_USER}"
VENV="/opt/cde-hol/venv"

echo "================ Starting Bootstrap Script ================"

# 1. System Updates & Dependencies
dnf update -y
dnf install -y python3.11 python3.11-pip python3.11-devel gcc make git jq tar vim-minimal

# 2. Python 3.11 virtual environment with JupyterLab
python3.11 -m venv "$VENV"
"$VENV/bin/pip" install --no-cache-dir --upgrade pip
"$VENV/bin/pip" install --no-cache-dir jupyter jupyterlab numpy pandas matplotlib scikit-learn
chown -R "$HOL_USER:$HOL_USER" /opt/cde-hol

# 3. Clone the lab repository into the user's home (the JupyterLab root)
git clone "$REPO_URL" /tmp/CDE_126_HOL
cp -a /tmp/CDE_126_HOL/. "$HOL_HOME/"
rm -rf /tmp/CDE_126_HOL

# 4. CDE CLI and Spark Connect tarballs (cdeconnect is in the repo, pyspark is a release asset)
curl -fL -o /usr/local/bin/cde "$ASSETS_URL/$CDE_CLI_ASSET"
chmod 755 /usr/local/bin/cde
cp "$HOL_HOME"/spark-connect/*.tar.gz "$HOL_HOME/"
curl -fL -o "$HOL_HOME/$PYSPARK_TARBALL" "$ASSETS_URL/$PYSPARK_TARBALL"

# 5. CDE and CDP config templates, completed by participants in the lab
mkdir -p "$HOL_HOME/.cde" "$HOL_HOME/.cdp"
cp "$HOL_HOME/config.yaml" "$HOL_HOME/.cde/config.yaml"
cp "$HOL_HOME/credentials" "$HOL_HOME/.cdp/credentials"
chmod 700 "$HOL_HOME/.cde" "$HOL_HOME/.cdp"
chmod 600 "$HOL_HOME/.cde/config.yaml" "$HOL_HOME/.cdp/credentials"

# Make the venv's python/pip the default in login shells and JupyterLab terminals
echo "export PATH=\"$VENV/bin:$HOL_HOME/.local/bin:\$PATH\"" > /etc/profile.d/cde-hol.sh
echo "export PATH=\"$VENV/bin:$HOL_HOME/.local/bin:\$PATH\"" >> "$HOL_HOME/.bashrc"

chown -R "$HOL_USER:$HOL_USER" "$HOL_HOME"

# 6. JupyterLab as a systemd service on port 80
# Auth goes in a config file: hashed passwords contain '$', which systemd would expand in ExecStart
mkdir -p "$HOL_HOME/.jupyter"
{
  echo "c.ServerApp.token = ''"
  if [ -n "$JUPYTER_PASSWORD" ]; then
    HASHED=$(JUPYTER_PASSWORD="$JUPYTER_PASSWORD" "$VENV/bin/python" -c \
      "import os; from jupyter_server.auth import passwd; print(passwd(os.environ['JUPYTER_PASSWORD']))")
    echo "c.PasswordIdentityProvider.hashed_password = '$HASHED'"
  else
    echo "c.ServerApp.password = ''"
  fi
} > "$HOL_HOME/.jupyter/jupyter_server_config.py"
chown -R "$HOL_USER:$HOL_USER" "$HOL_HOME/.jupyter"

cat > /etc/systemd/system/jupyterlab.service <<EOF
[Unit]
Description=JupyterLab for the CDE 1.26 HOL
After=network-online.target
Wants=network-online.target

[Service]
User=$HOL_USER
WorkingDirectory=$HOL_HOME
Environment=PATH=$VENV/bin:$HOL_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=SHELL=/bin/bash
AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStart=$VENV/bin/jupyter lab --ip=0.0.0.0 --port=80 --no-browser --ServerApp.root_dir=$HOL_HOME
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now jupyterlab

echo "================ Bootstrap Script Completed ================"
