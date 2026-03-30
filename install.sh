#!/bin/bash
# ============================================
# Panel Myxsi - Instalación para Kali Linux
# Solución: elimina repositorio Docker inválido
# ============================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                     PANEL MYXSI - INSTALACIÓN KALI LINUX                    ║"
echo "║                     Terminal REAL + Immich + Gestor Archivos                ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ==================== LIMPIAR REPOSITORIO DOCKER INVÁLIDO ====================
echo -e "${BLUE}🧹 1. LIMPIANDO REPOSITORIOS DOCKER INVÁLIDOS...${NC}"
if [ -f /etc/apt/sources.list.d/docker.list ]; then
    echo -e "${YELLOW}Eliminando repositorio Docker problemático...${NC}"
    sudo rm -f /etc/apt/sources.list.d/docker.list
fi
if [ -f /etc/apt/sources.list.d/docker.list.save ]; then
    sudo rm -f /etc/apt/sources.list.d/docker.list.save
fi
# También eliminar cualquier otro repositorio Docker que pueda estar presente
sudo rm -f /etc/apt/sources.list.d/docker*.list 2>/dev/null || true

echo -e "${GREEN}✅ Repositorios Docker limpiados${NC}"

# ==================== ACTUALIZAR SISTEMA ====================
echo -e "${BLUE}📦 2. ACTUALIZANDO SISTEMA...${NC}"
sudo apt update

# ==================== INSTALAR DEPENDENCIAS BASE ====================
echo -e "${BLUE}📦 3. INSTALANDO DEPENDENCIAS BASE...${NC}"
sudo apt install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-pam \
    gcc \
    g++ \
    make \
    curl \
    wget \
    git \
    htop \
    net-tools \
    nginx \
    ufw \
    openssl \
    ca-certificates \
    libpam0g-dev \
    libffi-dev \
    libssl-dev \
    build-essential \
    libjpeg-dev \
    zlib1g-dev

echo -e "${GREEN}✅ Dependencias base instaladas${NC}"

# ==================== INSTALAR DOCKER DESDE REPOSITORIOS KALI ====================
echo -e "${BLUE}🐳 4. INSTALANDO DOCKER DESDE REPOSITORIOS KALI...${NC}"

# Verificar si Docker ya está instalado
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✅ Docker ya está instalado${NC}"
else
    echo -e "${YELLOW}Instalando Docker desde repositorios de Kali...${NC}"
    sudo apt install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✅ Docker instalado correctamente${NC}"
fi

# Verificar Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Instalando Docker Compose...${NC}"
    sudo apt install -y docker-compose
fi

# ==================== INSTALAR NODE.JS ====================
echo -e "${BLUE}📦 5. INSTALANDO NODE.JS...${NC}"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
    echo -e "${GREEN}✅ Node.js instalado${NC}"
else
    echo -e "${GREEN}✅ Node.js ya está instalado${NC}"
fi

# ==================== INSTALAR DEPENDENCIAS PYTHON ====================
echo -e "${BLUE}📦 6. INSTALANDO DEPENDENCIAS PYTHON...${NC}"
pip3 install --upgrade pip setuptools wheel

pip3 install \
    flask \
    flask-socketio \
    python-socketio \
    eventlet \
    psutil \
    requests \
    python-dotenv \
    gunicorn \
    python-pam

# ==================== CONFIGURAR FIREWALL ====================
echo -e "${BLUE}🔥 7. CONFIGURANDO FIREWALL...${NC}"
sudo ufw --force enable 2>/dev/null || true
sudo ufw allow 22/tcp 2>/dev/null || true
sudo ufw allow 80/tcp 2>/dev/null || true
sudo ufw allow 443/tcp 2>/dev/null || true
sudo ufw allow 5000/tcp 2>/dev/null || true
sudo ufw allow 2283/tcp 2>/dev/null || true
echo -e "${GREEN}✅ Firewall configurado${NC}"

# ==================== CREAR DIRECTORIOS ====================
echo -e "${BLUE}📁 8. CREANDO DIRECTORIOS...${NC}"
mkdir -p ~/panel-myxsi
mkdir -p ~/panel-myxsi/scripts
mkdir -p ~/panel-myxsi/logs
mkdir -p ~/immich
mkdir -p ~/backups
echo -e "${GREEN}✅ Directorios creados${NC}"

# ==================== CONFIGURAR IMMICH ====================
echo -e "${BLUE}📸 9. CONFIGURANDO IMMICH...${NC}"
cd ~/immich
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${YELLOW}Descargando configuración de Immich...${NC}"
    wget -q -O docker-compose.yml https://raw.githubusercontent.com/immich-app/immich/main/docker-compose.yml
    wget -q -O .env https://raw.githubusercontent.com/immich-app/immich/main/example.env
    echo -e "${GREEN}✅ Immich configurado${NC}"
else
    echo -e "${GREEN}✅ Immich ya está configurado${NC}"
fi

# ==================== CREAR ENTORNO VIRTUAL ====================
echo -e "${BLUE}🐍 10. CREANDO ENTORNO VIRTUAL...${NC}"
cd ~/panel-myxsi
python3 -m venv venv
source venv/bin/activate

# Instalar dependencias en el entorno virtual
pip install --upgrade pip
pip install \
    flask \
    flask-socketio \
    python-socketio \
    eventlet \
    psutil \
    requests \
    python-dotenv \
    gunicorn \
    python-pam

# ==================== CREAR ARCHIVO .ENV ====================
echo -e "${BLUE}🔐 11. CREANDO ARCHIVO DE CONFIGURACIÓN...${NC}"
cat > ~/panel-myxsi/.env << 'EOF'
FLASK_APP=app.py
FLASK_ENV=production
SECRET_KEY=myxsi_panel_secret_key_2024
PORT=5000
IMMICH_URL=http://localhost:2283
EOF

# ==================== CREAR SCRIPT DE INICIO ====================
echo -e "${BLUE}🚀 12. CREANDO SCRIPT DE INICIO...${NC}"
cat > ~/panel-myxsi/start.sh << 'EOF'
#!/bin/bash
cd ~/panel-myxsi
source venv/bin/activate
export FLASK_APP=app.py
exec gunicorn --worker-class eventlet -w 1 --bind 0.0.0.0:5000 app:app
EOF

chmod +x ~/panel-myxsi/start.sh

# ==================== CREAR SCRIPT DE PARADA ====================
cat > ~/panel-myxsi/stop.sh << 'EOF'
#!/bin/bash
pkill -f gunicorn 2>/dev/null || true
echo "Panel detenido"
EOF

chmod +x ~/panel-myxsi/stop.sh

# ==================== CREAR SCRIPT DE REINICIO ====================
cat > ~/panel-myxsi/restart.sh << 'EOF'
#!/bin/bash
~/panel-myxsi/stop.sh
sleep 2
~/panel-myxsi/start.sh
EOF

chmod +x ~/panel-myxsi/restart.sh

# ==================== CREAR SCRIPT PARA IMMICH ====================
echo -e "${BLUE}📸 13. CREANDO SCRIPT PARA IMMICH...${NC}"
cat > ~/immich/start.sh << 'EOF'
#!/bin/bash
cd ~/immich
docker-compose up -d
echo "Immich iniciado en http://localhost:2283"
EOF

cat > ~/immich/stop.sh << 'EOF'
#!/bin/bash
cd ~/immich
docker-compose down
echo "Immich detenido"
EOF

chmod +x ~/immich/start.sh ~/immich/stop.sh

# ==================== CONFIGURAR NGINX ====================
echo -e "${BLUE}🌐 14. CONFIGURANDO NGINX...${NC}"
sudo tee /etc/nginx/sites-available/myxsi << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_read_timeout 86400;
    }
}

server {
    listen 2283;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:2283;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/myxsi /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
sudo nginx -t && sudo systemctl restart nginx
echo -e "${GREEN}✅ Nginx configurado${NC}"

# ==================== CREAR ALIAS EN .BASHRC ====================
echo -e "${BLUE}🔧 15. AGREGANDO ALIAS AL TERMINAL...${NC}"
if ! grep -q "myxsi-start" ~/.bashrc; then
    cat >> ~/.bashrc << 'EOF'

# Myxsi Panel Aliases
alias myxsi-start='~/panel-myxsi/start.sh'
alias myxsi-stop='~/panel-myxsi/stop.sh'
alias myxsi-restart='~/panel-myxsi/restart.sh'
alias myxsi-logs='tail -f ~/panel-myxsi/logs/panel.log'
alias immich-start='~/immich/start.sh'
alias immich-stop='~/immich/stop.sh'
alias immich-status='docker ps | grep immich || echo "Immich no está corriendo"'
alias myxsi-status='pgrep -f gunicorn && echo "Panel corriendo" || echo "Panel detenido"'
EOF
    echo -e "${GREEN}✅ Alias agregados${NC}"
fi

# ==================== CREAR ARCHIVO DE LOGS ====================
touch ~/panel-myxsi/logs/panel.log

# ==================== OBTENER IP ====================
IP=$(hostname -I | awk '{print $1}')
if [ -z "$IP" ]; then
    IP="IP-DE-TU-MAQUINA"
fi

# ==================== FINALIZAR ====================
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALACIÓN COMPLETADA EXITOSAMENTE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📦 PAQUETES INSTALADOS:${NC}"
echo "   ✓ Python 3 + pip + venv"
echo "   ✓ Flask + Flask-SocketIO + Eventlet"
echo "   ✓ Psutil + Python-PAM"
echo "   ✓ Docker.io + Docker-compose (repositorios Kali)"
echo "   ✓ Node.js"
echo "   ✓ Nginx + UFW"
echo "   ✓ Immich configurado"
echo ""
echo -e "${CYAN}🌐 URLS DE ACCESO:${NC}"
echo "   🔧 Panel Myxsi:      http://$IP:5000"
echo "   📸 Immich (fotos):   http://$IP:2283"
echo "   📁 Gestor Archivos:  http://$IP:5000/storage"
echo "   💻 Terminal REAL:    http://$IP:5000/terminal"
echo ""
echo -e "${CYAN}🔐 CREDENCIALES:${NC}"
echo "   Usuario: Tu usuario del sistema ($USER)"
echo "   Contraseña: La misma que usas para iniciar sesión"
echo ""
echo -e "${CYAN}⚙️  COMANDOS ÚTILES:${NC}"
echo "   myxsi-start      - Iniciar panel"
echo "   myxsi-stop       - Detener panel"
echo "   immich-start     - Iniciar Immich"
echo "   immich-stop      - Detener Immich"
echo "   immich-status    - Ver estado de Immich"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
echo "   1. Para que los alias funcionen: source ~/.bashrc"
echo "   2. Para iniciar Immich: immich-start (primera vez tarda unos minutos)"
echo "   3. Para iniciar el panel: myxsi-start"
echo "   4. Si Docker no funciona, cierra sesión y vuelve a entrar (para aplicar grupo docker)"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 PANEL MYXSI LISTO PARA USAR! 🎉${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
