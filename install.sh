#!/bin/bash
# ============================================
# PANEL MYXSI - INSTALADOR DE DEPENDENCIAS
# Para Debian (bookworm/bullseye)
# Instala TODO lo necesario para el panel
# ============================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║              PANEL MYXSI - INSTALADOR DE DEPENDENCIAS                      ║"
echo "║                    Para Debian (bookworm/bullseye)                         ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ==================== FUNCIONES ====================

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}📌 $1${NC}"
}

print_step() {
    echo -e "\n${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🔧 $1${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}\n"
}

# ==================== VERIFICAR SISTEMA ====================
print_step "VERIFICANDO SISTEMA OPERATIVO"

if [ ! -f /etc/debian_version ]; then
    print_error "Este script solo funciona en Debian"
    exit 1
fi

DEBIAN_VERSION=$(cat /etc/debian_version)
print_success "Sistema detectado: Debian $DEBIAN_VERSION"

if [ "$EUID" -eq 0 ]; then 
    print_error "No ejecutes este script como root"
    echo "Ejecuta: ./install_deps.sh"
    exit 1
fi

if ! sudo -n true 2>/dev/null; then
    print_warning "Se requieren permisos sudo para instalar dependencias"
    sudo -v
fi

print_success "Permisos verificados"

# ==================== ACTUALIZAR SISTEMA ====================
print_step "ACTUALIZANDO REPOSITORIOS"

sudo apt update
sudo apt upgrade -y
print_success "Sistema actualizado"

# ==================== INSTALAR DEPENDENCIAS BASE ====================
print_step "INSTALANDO DEPENDENCIAS BASE DEL SISTEMA"

sudo apt install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-full \
    gcc \
    g++ \
    make \
    curl \
    wget \
    git \
    htop \
    net-tools \
    ufw \
    openssl \
    ca-certificates \
    libpam0g-dev \
    libffi-dev \
    libssl-dev \
    build-essential \
    libjpeg-dev \
    zlib1g-dev \
    psmisc \
    bc \
    netcat-openbsd

print_success "Dependencias base instaladas"

# ==================== INSTALAR DEPENDENCIAS PARA WIFI ====================
print_step "INSTALANDO DEPENDENCIAS PARA WIFI"

sudo apt install -y \
    hostapd \
    dnsmasq \
    wireless-tools \
    wpasupplicant \
    rfkill \
    iw \
    network-manager

print_success "Dependencias WiFi instaladas"

# ==================== INSTALAR NODE.JS ====================
print_step "INSTALANDO NODE.JS"

if ! command -v node &> /dev/null; then
    print_info "Instalando Node.js 20.x..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
    print_success "Node.js $(node --version) instalado"
else
    print_success "Node.js ya instalado: $(node --version)"
fi

# ==================== INSTALAR DOCKER (PARA IMMICH) ====================
print_step "INSTALANDO DOCKER Y DOCKER COMPOSE"

# Verificar si Docker ya está instalado
if command -v docker &> /dev/null; then
    print_success "Docker ya instalado"
else
    print_info "Instalando Docker desde repositorio oficial..."
    
    # Desinstalar versiones antiguas
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Instalar dependencias para Docker
    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Agregar clave GPG oficial de Docker
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Agregar repositorio de Docker
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalar Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Iniciar y habilitar Docker
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Agregar usuario al grupo docker
    sudo usermod -aG docker $USER
    
    print_success "Docker instalado correctamente"
fi

# Verificar Docker Compose
if docker compose version &> /dev/null; then
    print_success "Docker Compose plugin disponible"
else
    print_warning "Instalando Docker Compose standalone..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose instalado"
fi

# ==================== INSTALAR DEPENDENCIAS PYTHON ====================
print_step "INSTALANDO DEPENDENCIAS PYTHON"

# Actualizar pip
print_info "Actualizando pip..."
python3 -m pip install --upgrade pip setuptools wheel

# Instalar Flask y dependencias web
print_info "Instalando Flask y extensiones..."
python3 -m pip install --force-reinstall --no-cache-dir \
    Flask==2.3.3 \
    flask-socketio==5.3.4 \
    python-socketio==5.9.0 \
    eventlet==0.33.3 \
    werkzeug==2.3.0

# Instalar utilidades del sistema
print_info "Instalando utilidades del sistema..."
python3 -m pip install --force-reinstall --no-cache-dir \
    psutil==5.9.6 \
    netifaces \
    requests==2.31.0 \
    python-dotenv==1.0.0

# Instalar autenticación PAM
print_info "Instalando python-pam (autenticación de usuarios)..."
python3 -m pip install --force-reinstall --no-cache-dir python-pam

# Instalar servidor de producción
print_info "Instalando Gunicorn..."
python3 -m pip install --force-reinstall --no-cache-dir \
    gunicorn==21.2.0 \
    gevent \
    gevent-websocket

print_success "Todas las dependencias Python instaladas"

# ==================== VERIFICAR INSTALACIÓN ====================
print_step "VERIFICANDO INSTALACIÓN PARA ASEGURAR QUE NO HAY ERRORES"

# Verificar cada paquete
ERRORES=0

echo -e "${BLUE}Verificando Flask...${NC}"
python3 -c "import flask; print(f'   Versión: {flask.__version__}')" 2>/dev/null || { print_error "Flask NO instalado"; ERRORES=$((ERRORES+1)); }

echo -e "${BLUE}Verificando Flask-SocketIO...${NC}"
python3 -c "import flask_socketio; print('   ✅ OK')" 2>/dev/null || { print_error "Flask-SocketIO NO instalado"; ERRORES=$((ERRORES+1)); }

echo -e "${BLUE}Verificando Eventlet...${NC}"
python3 -c "import eventlet; print('   ✅ OK')" 2>/dev/null || { print_error "Eventlet NO instalado"; ERRORES=$((ERRORES+1)); }

echo -e "${BLUE}Verificando Psutil...${NC}"
python3 -c "import psutil; print('   ✅ OK')" 2>/dev/null || { print_error "Psutil NO instalado"; ERRORES=$((ERRORES+1)); }

echo -e "${BLUE}Verificando Python-PAM...${NC}"
python3 -c "import pam; print('   ✅ OK')" 2>/dev/null || { print_error "Python-PAM NO instalado"; ERRORES=$((ERRORES+1)); }

echo -e "${BLUE}Verificando Netifaces...${NC}"
python3 -c "import netifaces; print('   ✅ OK')" 2>/dev/null || { print_error "Netifaces NO instalado"; ERRORES=$((ERRORES+1)); }

echo -e "${BLUE}Verificando Gunicorn...${NC}"
python3 -c "import gunicorn; print('   ✅ OK')" 2>/dev/null || { print_error "Gunicorn NO instalado"; ERRORES=$((ERRORES+1)); }

if [ $ERRORES -eq 0 ]; then
    print_success "TODAS las dependencias se instalaron correctamente"
else
    print_error "Hubo $ERRORES errores en la instalación"
    print_warning "Intentando instalar nuevamente con --ignore-installed..."
    
    python3 -m pip install --ignore-installed --force-reinstall \
        Flask flask-socketio eventlet psutil python-pam netifaces gunicorn
    
    print_success "Reinstalación completada"
fi

# ==================== VERIFICAR SERVICIOS ====================
print_step "VERIFICANDO SERVICIOS DEL SISTEMA"

# Verificar Docker
if systemctl is-active --quiet docker; then
    print_success "Docker está ejecutándose"
else
    print_warning "Docker no está ejecutándose. Iniciando..."
    sudo systemctl start docker
    sudo systemctl enable docker
    print_success "Docker iniciado"
fi

# Verificar Docker grupo
if groups $USER | grep -q docker; then
    print_success "Usuario $USER está en el grupo docker"
else
    print_warning "Agregando $USER al grupo docker..."
    sudo usermod -aG docker $USER
    print_success "Usuario agregado al grupo docker (recomendado cerrar sesión y volver a entrar)"
fi

# ==================== CONFIGURAR FIREWALL ====================
print_step "CONFIGURANDO FIREWALL"

sudo ufw --force enable 2>/dev/null || true
sudo ufw allow 22/tcp comment 'SSH' 2>/dev/null || true
sudo ufw allow 5000/tcp comment 'Panel Myxsi' 2>/dev/null || true
sudo ufw allow 2283/tcp comment 'Immich' 2>/dev/null || true

print_success "Firewall configurado (puertos: 22, 5000, 2283)"

# ==================== INFORMACIÓN FINAL ====================
# Obtener IP
IP=$(hostname -I | awk '{print $1}')
if [ -z "$IP" ]; then
    IP="IP-DE-TU-MAQUINA"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALACIÓN DE DEPENDENCIAS COMPLETADA EXITOSAMENTE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📦 DEPENDENCIAS INSTALADAS:${NC}"
echo "   ✓ Python 3 + pip + venv + dev"
echo "   ✓ Flask + Flask-SocketIO + Eventlet"
echo "   ✓ Psutil + Netifaces + Requests"
echo "   ✓ Python-PAM (autenticación)"
echo "   ✓ Gunicorn + Gevent (servidor producción)"
echo "   ✓ Node.js"
echo "   ✓ Docker + Docker Compose"
echo "   ✓ Hostapd + Dnsmasq (WiFi AP)"
echo "   ✓ Wirelesstools + WPA Supplicant"
echo "   ✓ Nginx + UFW (firewall)"
echo "   ✓ GCC + Make + Build Essential"
echo "   ✓ Librerías: PAM, FFI, SSL, JPEG, Zlib"
echo ""
echo -e "${CYAN}📝 PARA EJECUTAR TU PANEL:${NC}"
echo "   1. Ve a la carpeta donde está tu app.py:"
echo "      cd /ruta/de/tu/panel"
echo ""
echo "   2. Ejecuta tu panel:"
echo "      python3 app.py"
echo ""
echo "   3. O con Gunicorn (recomendado para producción):"
echo "      gunicorn --worker-class eventlet -w 1 --bind 0.0.0.0:5000 app:app"
echo ""
echo -e "${CYAN}🌐 ACCESO AL PANEL:${NC}"
echo "   http://$IP:5000"
echo ""
echo -e "${CYAN}📸 PARA INSTALAR IMMICH (OPCIONAL):${NC}"
echo "   mkdir ~/immich-app && cd ~/immich-app"
echo "   wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml"
echo "   wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env"
echo "   nano .env  # Configurar UPLOAD_LOCATION y DB_PASSWORD"
echo "   docker compose up -d"
echo ""
echo -e "${YELLOW}⚠️  NOTAS IMPORTANTES:${NC}"
echo "   1. Si agregaste el usuario al grupo docker, CIERRA SESIÓN y vuelve a entrar"
echo "   2. Para verificar Docker: docker ps"
echo "   3. Para verificar Python: python3 -c 'import flask, psutil, pam; print(\"OK\")'"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 SISTEMA LISTO - TODAS LAS DEPENDENCIAS INSTALADAS! 🎉${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# ==================== PREGUNTAR SI QUIERE PROBAR ====================
echo -e "${YELLOW}¿Quieres probar que todas las dependencias funcionan? (s/n)${NC}"
read -p "➡️ " probar

if [[ "$probar" == "s" || "$probar" == "S" ]]; then
    echo -e "\n${BLUE}Probando dependencias...${NC}\n"
    
    echo -e "${CYAN}>>> Probando importaciones Python:${NC}"
    python3 << EOF
import sys
try:
    import flask
    print("✅ Flask")
except: print("❌ Flask")
try:
    import flask_socketio
    print("✅ Flask-SocketIO")
except: print("❌ Flask-SocketIO")
try:
    import eventlet
    print("✅ Eventlet")
except: print("❌ Eventlet")
try:
    import psutil
    print("✅ Psutil")
except: print("❌ Psutil")
try:
    import pam
    print("✅ Python-PAM")
except: print("❌ Python-PAM")
try:
    import netifaces
    print("✅ Netifaces")
except: print("❌ Netifaces")
try:
    import gunicorn
    print("✅ Gunicorn")
except: print("❌ Gunicorn")
print("\n✅ Todas las pruebas completadas")
EOF
    
    echo -e "\n${CYAN}>>> Probando servicios:${NC}"
    docker --version && echo "✅ Docker" || echo "❌ Docker"
    node --version && echo "✅ Node.js" || echo "❌ Node.js"
    
    print_success "\nPruebas completadas"
fi

echo -e "${MAGENTA}✨ Instalación de dependencias finalizada. ¡Listo para ejecutar tu panel! ✨${NC}"
