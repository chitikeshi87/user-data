#!/bin/bash
set -euxo pipefail

# --- Configuration & Versions ---
NODE_MAJOR=20
PM2_VERSION="5.4.3"
NVM_VERSION="v0.40.0"
NODE_USER_VERSION="20.18.3"
MYSQL_VERSION_PKG="mysql-server-8.0" # Using meta-package for better compatibility or specific if strict pinning needed
MONGODB_VERSION="8.0"
MONGODB_FULL_VERSION="8.0.13"
MONGOSH_VERSION="2.5.7"
NGINX_VERSION="1.24.0" # Note: Ubuntu repos might enforce specific versions
GIT_VERSION="2.43.0"

# --- Error Handling ---
error_handler() {
    echo "Error occurred in script at line: ${1}"
    echo "Command: ${2}"
}
trap 'error_handler ${LINENO} "$BASH_COMMAND"' ERR

# --- Helpers ---
wait_for_apt_lock() {
    echo "Waiting for apt lock..."
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        sleep 5
    done
}

# --- System Update ---
wait_for_apt_lock
apt-get update -y
wait_for_apt_lock
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https unzip build-essential libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext zlib1g-dev tcl tk

# --- Node.js (System-wide via NodeSource) ---
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg --yes
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
wait_for_apt_lock
apt-get update -y
wait_for_apt_lock
apt-get install -y nodejs
npm install -g pm2@$PM2_VERSION

# --- NVM (User-specific) ---
# Note: This installs for root. If you need it for a specific user (e.g. ubuntu), run as that user.
export NVM_DIR="/root/.nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install $NODE_USER_VERSION
nvm alias default $NODE_USER_VERSION
nvm use default

# --- Tailscale ---
curl -fsSL https://tailscale.com/install.sh | sh

# --- MySQL ---
# Removing strict version string to avoid package not found errors on different updates, 
# or ensure these versions definitely exist in the repo for the OS version.
# Reverting to safer package names for robustness unless strict pinning is required.
wait_for_apt_lock
apt-get install -y mysql-server mysql-client
systemctl enable --now mysql

# --- MongoDB ---
curl -fsSL https://pgp.mongodb.com/server-$MONGODB_VERSION.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-$MONGODB_VERSION.gpg --yes
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-$MONGODB_VERSION.gpg] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/$MONGODB_VERSION multiverse" | tee /etc/apt/sources.list.d/mongodb-org-$MONGODB_VERSION.list
wait_for_apt_lock
apt-get update -y
wait_for_apt_lock
apt-get install -y mongodb-org=$MONGODB_FULL_VERSION mongodb-org-server=$MONGODB_FULL_VERSION mongodb-org-shell=$MONGODB_FULL_VERSION mongodb-org-mongos=$MONGODB_FULL_VERSION mongodb-org-tools=$MONGODB_FULL_VERSION
apt-mark hold mongodb-org mongodb-org-server mongodb-org-tools
wget -O mongodb-mongosh.deb "https://github.com/mongodb-js/mongosh/releases/download/v$MONGOSH_VERSION/mongodb-mongosh_${MONGOSH_VERSION}_amd64.deb"
apt-get install -y ./mongodb-mongosh.deb
rm mongodb-mongosh.deb
systemctl enable --now mongod

# --- Nginx ---
wait_for_apt_lock
apt-get install -y nginx
systemctl enable --now nginx

# --- Git (Source Build) ---
# Check if git is already installed from source to avoid rebuilding
if ! git --version | grep -q "$GIT_VERSION"; then
    wget -O git.tar.gz "https://www.kernel.org/pub/software/scm/git/git-$GIT_VERSION.tar.gz"
    tar -xzf git.tar.gz
    cd "git-$GIT_VERSION"
    make prefix=/usr/local all
    make prefix=/usr/local install
    cd ..
    rm -rf "git-$GIT_VERSION" git.tar.gz
else
    echo "Git $GIT_VERSION already installed."
fi
git --version

# --- AWS CLI ---
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -o awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
else
    echo "AWS CLI already installed."
fi
aws --version

# --- Final touches ---
hostnamectl hostname pre-transitionv3
echo "System installation completed successfully. Please run setup.sh for project setup."
