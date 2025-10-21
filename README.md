# HNG Stage 1 — deploy.sh

This repository contains `deploy.sh`, a production-grade Bash script to deploy Dockerized apps to a remote Linux host.

## Features
- Clone / pull repo (supports PAT)
- Remote install of Docker, Docker Compose, Nginx (idempotent)
- Rsync project to `~/app_deploy`, build/run containers
- Configure Nginx reverse proxy (/etc/nginx/sites-available/app_deploy.conf)
- Validation checks and timestamped logs
- `--cleanup` to remove deployed artifacts

## Quick start
1. Make script executable:
   chmod +x deploy.sh

2. Interactive:
   ./deploy.sh

3. Non-interactive:
   ./deploy.sh --repo https://github.com/docker/getting-started.git --user ubuntu --host 1.2.3.4 --ssh-key ~/.ssh/id_rsa --app-port 3000

4. Cleanup:
   ./deploy.sh --cleanup --user ubuntu --host 1.2.3.4 --ssh-key ~/.ssh/id_rsa

## Notes & assumptions
- Uses rsync over SSH; local machine must have `rsync`, `ssh`, `git`.
- Remote must allow incoming HTTP (port 80); open firewall / security groups accordingly.
- Example repo: docker/getting-started (app typical port 3000). :contentReference[oaicite:4]{index=4}
