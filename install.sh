#!/bin/bash
set -euxo pipefail

# Update system
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https unzip build-essential libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext zlib1g-dev tcl tk

# --- Node.js (via NodeSource) ---
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
apt-get update -y
apt-get install -y nodejs
npm install -g pm2@5.4.3

# --- NVM ---
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
export NVM_DIR="/root/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install 20.18.3
nvm alias default 20.18.3
nvm use default

# --- Tailscale ---
curl -fsSL https://tailscale.com/install.sh | sh

# --- MySQL ---
apt-get install -y mysql-server=8.0.44-0ubuntu0.24.04.2 mysql-client=8.0.44-0ubuntu0.24.04.2 mysql-server-core-8.0=8.0.44-0ubuntu0.24.04.2 mysql-client-core-8.0=8.0.44-0ubuntu0.24.04.2
apt-mark hold mysql-server mysql-client mysql-server-core-8.0 mysql-client-core-8.0
systemctl enable --now mysql

# --- MongoDB ---
curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-8.0.list
apt-get update -y
apt-get install -y mongodb-org=8.0.13 mongodb-org-server=8.0.13 mongodb-org-shell=8.0.13 mongodb-org-mongos=8.0.13 mongodb-org-tools=8.0.13
apt-mark hold mongodb-org mongodb-org-server mongodb-org-tools
wget https://github.com/mongodb-js/mongosh/releases/download/v2.5.7/mongodb-mongosh_2.5.7_amd64.deb
apt-get install -y ./mongodb-mongosh_2.5.7_amd64.deb
systemctl enable --now mongod

# --- Nginx ---
apt-get install -y nginx=1.24.0-2ubuntu7.5
systemctl enable --now nginx

# --- Git (from source) ---
wget https://www.kernel.org/pub/software/scm/git/git-2.43.0.tar.gz
tar -xzf git-2.43.0.tar.gz && cd git-2.43.0
make prefix=/usr/local all
make prefix=/usr/local install
git --version

# --- AWS CLI ---
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && ./aws/install
aws --version

# --- Project setup (BACKEND) ---
mkdir -p /var/www/html/bh_docs /opt/node /root/node_checkouts ~/bluhatch_web
cd /root/node_checkouts
git clone https://github.com/ambrotechs/api_material_management_service
git clone https://github.com/ambrotechs/api_gateway
git clone https://github.com/ambrotechs/api_bluhatch
git clone https://github.com/ambrotechs/api_notification
git clone https://github.com/ambrotechs/api_trading_community
git clone https://github.com/ambrotechs/api_aqua_master
git clone https://github.com/ambrotechs/bluhatch_web

# --- Build frontend ---
cd bluhatch_web
npm install
./node_modules/.bin/ng build --base-href '/'
cp -r dist/BluHatch/ /var/www/html/

# --- Final touches ---
hostnamectl hostname pre-transitionv3
