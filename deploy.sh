#!/usr/bin/env bash
set -euo pipefail

# ============================
# 🚀 Automated Deployment Script (Production Grade)
# ============================
# Clones repo → installs dependencies → deploys Docker app + Nginx reverse proxy.

# ----------------------------
# Configuration Variables
# ----------------------------
REPO_URL=""
REMOTE_USER=""
REMOTE_HOST=""
SSH_KEY=""
APP_PORT=8000

# ----------------------------
# Utility Functions
# ----------------------------
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

usage() {
  echo "Usage: $0 --repo <repo_url> --user <remote_user> --host <remote_host> --ssh-key <path> [--app-port <port>]"
  exit 1
}

# ----------------------------
# Parse Arguments
# ----------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo) REPO_URL="$2"; shift 2 ;;
    --user) REMOTE_USER="$2"; shift 2 ;;
    --host) REMOTE_HOST="$2"; shift 2 ;;
    --ssh-key) SSH_KEY="$2"; shift 2 ;;
    --app-port) APP_PORT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "$REPO_URL" || -z "$REMOTE_USER" || -z "$REMOTE_HOST" || -z "$SSH_KEY" ]] && usage

SSH_OPTS="-o StrictHostKeyChecking=no -i ${SSH_KEY}"

# ----------------------------
# 1️⃣ Clone Repository
# ----------------------------
info "Cloning repository from $REPO_URL..."
rm -rf repo_temp || true
git clone --depth=1 "$REPO_URL" repo_temp || error "Failed to clone repo"

cd repo_temp
git checkout main || true
info "Checked out to branch: main"

if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; then
  info "Found Docker Compose configuration."
elif [ -f Dockerfile ]; then
  info "Found Dockerfile."
else
  error "No Dockerfile or docker-compose.yml found!"
fi
cd ..

# ----------------------------
# 2️⃣ Test Remote Connectivity
# ----------------------------
info "Testing SSH connectivity to ${REMOTE_USER}@${REMOTE_HOST}..."
if ! ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "echo Connection OK"; then
  error "Unable to SSH to remote host. Check key/permissions/network."
fi

# ----------------------------
# 3️⃣ Setup Environment on Remote (with proper Docker group fix)
# ----------------------------
info "Setting up Docker, Compose, and Nginx on remote host..."
ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" <<EOF
set -e

echo "[INFO] Updating packages..."
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common

# --- Install Docker if missing ---
if ! command -v docker >/dev/null 2>&1; then
  echo "[INFO] Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi

# --- Install Docker Compose plugin ---
if ! command -v docker compose >/dev/null 2>&1; then
  echo "[INFO] Installing Docker Compose plugin..."
  sudo apt-get install -y docker-compose-plugin
fi

# --- Ensure Docker group exists and add user ---
if ! getent group docker >/dev/null; then
  sudo groupadd docker
fi

echo "[INFO] Adding ${REMOTE_USER} to Docker group..."
sudo usermod -aG docker ${REMOTE_USER} || true
sudo chown ${REMOTE_USER}:${REMOTE_USER} /var/run/docker.sock || true

# --- Restart Docker and enable ---
sudo systemctl enable docker --now
sudo systemctl restart docker

# --- Install Nginx if missing ---
if ! command -v nginx >/dev/null 2>&1; then
  echo "[INFO] Installing Nginx..."
  sudo apt-get install -y nginx
  sudo systemctl enable nginx
  sudo systemctl start nginx
fi
EOF

info "✅ Remote environment setup complete (Docker + Nginx + user group fixed)"

# ----------------------------
# 4️⃣ Transfer Files
# ----------------------------
info "Transferring project files to remote host..."
rsync -avz -e "ssh $SSH_OPTS" repo_temp/ "${REMOTE_USER}@${REMOTE_HOST}:~/app_deploy"
info "✅ Rsync transfer complete"

# ----------------------------
# 5️⃣ Build & Deploy App
# ----------------------------
info "Building and running app on remote host..."
ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" <<EOF
set -e
cd ~/app_deploy

if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; then
  echo "[INFO] Deploying with Docker Compose..."
  docker compose down --remove-orphans || true
  docker compose pull || true
  docker compose up -d --build
else
  echo "[INFO] No Compose file — building manually..."
  IMAGE_NAME=app_deploy_image
  docker build -t "\$IMAGE_NAME" .
  if docker ps -a --format '{{.Names}}' | grep -q '^app_deploy\$'; then
    docker rm -f app_deploy || true
  fi
  docker run -d -p ${APP_PORT}:80 --name app_deploy "\$IMAGE_NAME"
fi
EOF

info "✅ Application deployed successfully!"

# ----------------------------
# 6️⃣ Configure Nginx Reverse Proxy
# ----------------------------
# ----------------------------
# 6️⃣ Configure Nginx Reverse Proxy
# ----------------------------
# ----------------------------
# 6️⃣ Configure Nginx Reverse Proxy
# ----------------------------
# ----------------------------
# 6️⃣ Configure Nginx Reverse Proxy (Dynamic internal port)
# ----------------------------
# ----------------------------
# 6️⃣ Configure Nginx Reverse Proxy
# ----------------------------
# ----------------------------
# 6️⃣ Configure Nginx Reverse Proxy
# ----------------------------
info "Setting up Nginx reverse proxy (port 80 → ${APP_PORT})..."
ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" <<EOF
set -e
sudo tee /etc/nginx/sites-available/app_proxy.conf > /dev/null <<NGINXCONF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINXCONF

sudo ln -sf /etc/nginx/sites-available/app_proxy.conf /etc/nginx/sites-enabled/app_proxy.conf

# --- Remove default Nginx config and reload ---
sudo rm -f /etc/nginx/sites-enabled/default /var/www/html/index.nginx-debian.html || true
sudo nginx -t
sudo systemctl reload nginx
EOF





# ----------------------------
# 7️⃣ Health Check
# ----------------------------
info "Running post-deploy health check..."
if ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "docker ps --format '{{.Names}}' | grep -q 'app_deploy'"; then
  info "✅ Container 'app_deploy' is running."
else
  error "❌ Container failed to start!"
fi

# ----------------------------
# 8️⃣ Cleanup
# ----------------------------
rm -rf repo_temp
info "🎉 Deployment complete and workspace cleaned up."
