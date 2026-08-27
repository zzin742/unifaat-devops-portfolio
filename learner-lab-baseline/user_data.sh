#!/bin/bash
# Bootstrap da instância TechNova. Roda como root no primeiro boot.
set -euo pipefail

LOG=/var/log/technova-setup.log
exec > >(tee -a "$LOG") 2>&1
echo "=== TechNova User Data — início: $(date) ==="

# --- 1. Sistema e dependências ---------------------------------------------
# Amazon Linux 2023 usa dnf. O nodejs dos repositórios oficiais já é 18+,
# então evitamos depender do script da NodeSource, que às vezes quebra em AL2023.
dnf update -y
dnf install -y git nodejs npm

echo "node: $(node --version)"
echo "npm:  $(npm --version)"
echo "git:  $(git --version)"

# --- 2. Aplicação -----------------------------------------------------------
APP_DIR=/home/ec2-user/app
mkdir -p "$APP_DIR"
cd "$APP_DIR"

cat > package.json <<'EOF'
{
  "name": "technova-api",
  "version": "1.0.0",
  "description": "TechNova API - Deploy na AWS via Terraform",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.18.0" }
}
EOF

cat > server.js <<'EOF'
const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'TechNova API - Rodando na AWS!',
    aluno: 'Jose Henrique Teixeira Luiz',
    ra: '3225002',
    disciplina: 'DevOps - UniFAAT 2026-2',
    aula: '04 - VPC + EC2 Multi-AZ',
    hostname: os.hostname(),
    platform: os.platform(),
    uptime: Math.floor(os.uptime()) + ' segundos',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'technova-api' });
});

app.get('/orders', (req, res) => {
  res.json({
    orders: [
      { id: 1, product: 'Widget A', status: 'shipped' },
      { id: 2, product: 'Widget B', status: 'processing' }
    ]
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`TechNova API ouvindo na porta ${PORT}`);
});
EOF

npm install --omit=dev
chown -R ec2-user:ec2-user "$APP_DIR"

# --- 3. systemd -------------------------------------------------------------
# Rodar com "npm start &" morre quando o user data termina e não volta depois
# de um reboot. Com unit de systemd, a API sobe no boot e reinicia se cair.
cat > /etc/systemd/system/technova-api.service <<'EOF'
[Unit]
Description=TechNova API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/app
ExecStart=/usr/bin/node /home/ec2-user/app/server.js
Restart=always
RestartSec=5
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now technova-api

sleep 5
systemctl is-active technova-api && echo "API ativa"
curl -s --max-time 10 http://localhost:3000/health || echo "aviso: health ainda nao respondeu"

echo "=== TechNova User Data — fim: $(date) ==="
