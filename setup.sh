#!/bin/bash
set -euxo pipefail

# --- Configuration ---
BASE_DIR="/root/node_checkouts"
WEB_DIR="/var/www/html"

# --- Error Handling ---
error_handler() {
    echo "Error occurred in script at line: ${1}"
    echo "Command: ${2}"
}
trap 'error_handler ${LINENO} "$BASH_COMMAND"' ERR

# --- Helpers ---
clone_or_pull() {
    local repo_url=$1
    local dest_dir=$2
    if [ -d "$dest_dir/.git" ]; then
        echo "Repository exists at $dest_dir. Updating..."
        git -C "$dest_dir" pull || echo "Failed to pull $dest_dir, continuing..."
    else
        echo "Cloning $repo_url into $dest_dir..."
        git clone "$repo_url" "$dest_dir"
    fi
}

echo "Starting project setup..."

# --- Project setup (BACKEND) ---
mkdir -p "$WEB_DIR/bh_docs" /opt/node "$BASE_DIR" /root/bluhatch_web

# Note: These git operations might prompt for password/credentials if repositories are private and no creds are cached.
clone_or_pull "https://github.com/ambrotechs/api_material_management_service" "$BASE_DIR/api_material_management_service"
clone_or_pull "https://github.com/ambrotechs/api_gateway" "$BASE_DIR/api_gateway"
clone_or_pull "https://github.com/ambrotechs/api_bluhatch" "$BASE_DIR/api_bluhatch"
clone_or_pull "https://github.com/ambrotechs/api_notification" "$BASE_DIR/api_notification"
clone_or_pull "https://github.com/ambrotechs/api_trading_community" "$BASE_DIR/api_trading_community"
clone_or_pull "https://github.com/ambrotechs/api_aqua_master" "$BASE_DIR/api_aqua_master"
clone_or_pull "https://github.com/ambrotechs/bluhatch_web" "$BASE_DIR/bluhatch_web"

# --- Build frontend ---
cd "$BASE_DIR/bluhatch_web"

# Ensure NVM is loaded if available (just in case this is run nicely in a shell with NVM)
export NVM_DIR="/root/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    nvm use default || true
fi

echo "Installing npm dependencies..."
npm install

echo "Building Angular app..."
./node_modules/.bin/ng build --base-href '/'

if [ -d "dist/BluHatch/" ]; then
    echo "Copying build artifacts..."
    cp -r dist/BluHatch "$WEB_DIR/"
else
    echo "Build failed or dist directory not found!"
    exit 1
fi

echo "Project setup completed successfully."
