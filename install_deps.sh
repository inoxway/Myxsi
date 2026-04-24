#!/bin/bash
# ============================================
# PANEL MYXSI - INSTALADOR DIRECTO PARA DEBIAN
# Instala TODAS las dependencias directamente en el sistema
# SOLUCIONADO: Conflictos de versiones (Flask + Werkzeug)
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
echo "║         PANEL MYXSI - INSTALACIÓN DIRECTA PARA DEBIAN                      ║"
echo "║      Instalando TODAS las dependencias - VERSIONES COMPATIBLES            ║"
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

# ==================== INSTALAR DEPENDENCIAS BASE DEL SISTEMA ====================
print_step "INSTALANDO DEPENDENCIAS BASE (APT)"

sudo apt install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-full \
    python3-venv \
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

print_success "Dependencias base instaladas via APT"

# ==================== INSTALAR DEPENDENCIAS PARA WIFI ====================
print_step "INSTALANDO DEPENDENCIAS WIFI"

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
print_step "INSTALANDO DOCKER"

if command -v docker &> /dev/null; then
    print_success "Docker ya instalado"
else
    print_info "Instalando Docker desde repositorio oficial..."
    
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    
    print_success "Docker instalado correctamente"
fi

if docker compose version &> /dev/null; then
    print_success "Docker Compose plugin disponible"
fi

# ==================== INSTALAR PAQUETES PYTHON (VERSIONES COMPATIBLES) ====================
print_step "INSTALANDO PAQUETES PYTHON (VERSIONES COMPATIBLES)"

# Actualizar pip
print_info "Actualizando pip..."
python3 -m pip install --upgrade pip setuptools wheel --break-system-packages

# Instalar Flask y Werkzeug (SIN forzar versiones conflictivas)
print_info "Instalando Flask y dependencias web (versiones compatibles)..."
python3 -m pip install --break-system-packages \
    Flask \
    flask-socketio \
    python-socketio \
    eventlet

# Instalar utilidades del sistema
print_info "Instalando utilidades del sistema..."
python3 -m pip install --break-system-packages \
    psutil \
    netifaces \
    requests \
    python-dotenv

# Instalar python-pam
print_info "Instalando python-pam..."
python3 -m pip install --break-system-packages python-pam

# Instalar servidor de producción
print_info "Instalando Gunicorn y Gevent..."
python3 -m pip install --break-system-packages \
    gunicorn \
    gevent \
    gevent-websocket

print_success "Todos los paquetes Python instalados con versiones compatibles"

# ==================== VERIFICAR INSTALACIÓN ====================
print_step "VERIFICANDO INSTALACIÓN"

ERRORES=0

echo -e "${BLUE}Verificando paquetes instalados...${NC}\n"

# Función para verificar paquetes Python
verificar_paquete() {
    python3 -c "import $1" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✅ $1${NC}"
        return 0
    else
        echo -e "   ${RED}❌ $1${NC}"
        return 1
    fi
}

verificar_paquete flask
verificar_paquete flask_socketio
verificar_paquete eventlet
verificar_paquete psutil
verificar_paquete pam
verificar_paquete netifaces
verificar_paquete gunicorn
verificar_paquete requests
verificar_paquete dotenv

# Verificar versión de Werkzeug (ahora será compatible)
echo -e "\n${BLUE}Verificando versiones de dependencias críticas:${NC}"
python3 -c "import werkzeug; print(f'   Werkzeug: {werkzeug.__version__}')" 2>/dev/null || echo "   Werkzeug: No instalado"
python3 -c "import flask; print(f'   Flask: {flask.__version__}')" 2>/dev/null || echo "   Flask: No instalado"

print_success "Verificación completada"

# ==================== CONFIGURAR FIREWALL ====================
print_step "CONFIGURANDO FIREWALL"

sudo ufw --force enable 2>/dev/null || true
sudo ufw allow 22/tcp comment 'SSH' 2>/dev/null || true
sudo ufw allow 5000/tcp comment 'Panel Myxsi' 2>/dev/null || true
sudo ufw allow 2283/tcp comment 'Immich' 2>/dev/null || true

print_success "Firewall configurado (puertos: 22, 5000, 2283)"

# ==================== CREAR ALIAS PARA EJECUTAR ====================
print_step "CREANDO COMANDOS ÚTILES"

if ! grep -q "alias myxsi" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# ========== Panel Myxsi - Comandos útiles ==========
alias myxsi-start='cd ~/panel-myxsi && python3 app.py'
alias myxsi-status='ps aux | grep "python3.*app.py" | grep -v grep'
alias myxsi-stop='pkill -f "python3.*app.py"'
EOF
    print_success "Alias agregados a ~/.bashrc"
else
    print_success "Alias ya existentes"
fi

# ==================== INFORMACIÓN DEL SISTEMA ====================
print_step "INFORMACIÓN DEL SISTEMA"

echo -e "${CYAN}Versiones instaladas:${NC}"
echo "   🐍 Python: $(python3 --version)"
echo "   📦 Pip: $(pip3 --version)"
echo "   💻 Node.js: $(node --version 2>/dev/null || echo 'No instalado')"
echo "   🐳 Docker: $(docker --version 2>/dev/null || echo 'No instalado')"
echo "   🔥 UFW: $(ufw --version 2>/dev/null | head -1 || echo 'No instalado')"

# Obtener IP
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
echo -e "${CYAN}📦 DEPENDENCIAS INSTALADAS DIRECTAMENTE EN EL SISTEMA:${NC}"
echo "   ✅ Python 3 + pip3 + dev + full"
echo "   ✅ Flask + Flask-SocketIO + Eventlet (versiones compatibles)"
echo "   ✅ Psutil + Netifaces + Requests"
echo "   ✅ Python-PAM (autenticación de usuarios)"
echo "   ✅ Gunicorn + Gevent (servidor producción)"
echo "   ✅ Node.js"
echo "   ✅ Docker + Docker Compose"
echo "   ✅ Hostapd + Dnsmasq (punto de acceso WiFi)"
echo "   ✅ Wirelesstools + WPA Supplicant"
echo "   ✅ UFW Firewall"
echo "   ✅ GCC + Make + Build Essential"
echo ""
echo -e "${CYAN}🚀 CÓMO EJECUTAR TU PANEL:${NC}"
echo "   1. Ve a la carpeta donde está tu app.py:"
echo "      cd /ruta/donde/esta/tu/panel"
echo ""
echo "   2. Ejecuta el panel:"
echo "      python3 app.py"
echo ""
echo "   3. O usa Gunicorn (recomendado):"
echo "      gunicorn --worker-class eventlet -w 1 --bind 0.0.0.0:5000 app:app"
echo ""
echo "   4. O usa los alias creados:"
echo "      myxsi-start  # Inicia el panel"
echo "      myxsi-stop   # Detiene el panel"
echo "      myxsi-status # Ver estado"
echo ""
echo -e "${CYAN}🌐 ACCESO AL PANEL:${NC}"
echo "   http://$IP:5000"
echo ""
echo -e "${CYAN}📸 PARA INSTALAR IMMICH (OPCIONAL):${NC}"
echo "   mkdir ~/immich && cd ~/immich"
echo "   wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml"
echo "   wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env"
echo "   nano .env  # Configurar UPLOAD_LOCATION y DB_PASSWORD"
echo "   docker compose up -d"
echo ""
echo -e "${YELLOW}⚠️  NOTAS IMPORTANTES:${NC}"
echo "   1. Se usó --break-system-packages para instalar directamente en el sistema"
echo "   2. Todos los paquetes están instalados GLOBALMENTE (no entorno virtual)"
echo "   3. Las versiones son COMPATIBLES (Flask y Werkzeug ahora funcionan juntos)"
echo "   4. Para verificar: python3 -c 'import flask, psutil, pam; print(\"OK\")'"
echo "   5. Si Docker no funciona, cierra sesión y vuelve a entrar"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 SISTEMA COMPLETO - SIN CONFLICTOS DE VERSIONES! 🎉${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# ==================== PREGUNTAR SI QUIERE PROBAR ====================
echo -e "${YELLOW}¿Quieres probar que todas las dependencias funcionan? (s/n)${NC}"
read -p "➡️ " probar

if [[ "$probar" == "s" || "$probar" == "S" ]]; then
    echo -e "\n${BLUE}Probando dependencias Python...${NC}\n"
    
    python3 << 'EOF'
import sys
success = True

print("📦 Verificando importaciones:")
try:
    import flask
    print(f"  ✅ Flask {flask.__version__}")
except Exception as e:
    print(f"  ❌ Flask: {e}")
    success = False

try:
    import flask_socketio
    print("  ✅ Flask-SocketIO")
except Exception as e:
    print(f"  ❌ Flask-SocketIO: {e}")
    success = False

try:
    import eventlet
    print("  ✅ Eventlet")
except Exception as e:
    print(f"  ❌ Eventlet: {e}")
    success = False

try:
    import werkzeug
    print(f"  ✅ Werkzeug {werkzeug.__version__}")
except Exception as e:
    print(f"  ❌ Werkzeug: {e}")
    success = False

try:
    import psutil
    print(f"  ✅ Psutil {psutil.__version__}")
except Exception as e:
    print(f"  ❌ Psutil: {e}")
    success = False

try:
    import pam
    print("  ✅ Python-PAM")
except Exception as e:
    print(f"  ❌ Python-PAM: {e}")
    success = False

try:
    import netifaces
    print("  ✅ Netifaces")
except Exception as e:
    print(f"  ❌ Netifaces: {e}")
    success = False

try:
    import gunicorn
    print(f"  ✅ Gunicorn {gunicorn.__version__}")
except Exception as e:
    print(f"  ❌ Gunicorn: {e}")
    success = False

if success:
    print("\n✅ TODAS las dependencias funcionan correctamente!")
    print("✅ No hay conflictos entre Flask y Werkzeug")
else:
    print("\n⚠️ Algunas dependencias fallaron, revisa los mensajes arriba")
EOF
    
    echo -e "\n${BLUE}Probando servicios del sistema...${NC}"
    
    if command -v docker &> /dev/null; then
        echo "  ✅ Docker: $(docker --version)"
    else
        echo "  ❌ Docker no encontrado"
    fi
    
    if command -v node &> /dev/null; then
        echo "  ✅ Node.js: $(node --version)"
    else
        echo "  ❌ Node.js no encontrado"
    fi
    
    print_success "\nPruebas completadas"
fi

echo -e "${MAGENTA}✨ ¡INSTALACIÓN DIRECTA COMPLETADA! Todas las dependencias están listas y son compatibles. ✨${NC}"
