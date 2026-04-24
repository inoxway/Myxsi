#!/bin/bash
# ============================================
# PANEL MYXSI - INSTALACIÓN COMPLETA PARA DEBIAN
# Incluye: Selección de zona horaria
#          Configuración de ruta de app.py
#          Inicio automático con el sistema
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
echo "║         PANEL MYXSI - INSTALACIÓN COMPLETA PARA DEBIAN                     ║"
echo "║      Dependencias + Panel + Immich + WiFi AP + Inicio Automático          ║"
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

# ==================== SELECCIÓN DE ZONA HORARIA ====================
print_step "SELECCIONA TU ZONA HORARIA"

echo -e "${CYAN}Selecciona tu continente/región:${NC}"
echo "1) America"
echo "2) Europe"
echo "3) Asia"
echo "4) Africa"
echo "5) Australia"
echo "6) Pacific"
echo "7) UTC (Universal)"
echo ""
read -p "➡️  Opción (1-7): " continente

case $continente in
    1)
        echo -e "\n${CYAN}Selecciona tu ciudad en América:${NC}"
        echo "1) New_York"
        echo "2) Los_Angeles"
        echo "3) Chicago"
        echo "4) Mexico_City"
        echo "5) Bogota"
        echo "6) Lima"
        echo "7) Santiago"
        echo "8) Buenos_Aires"
        echo "9) Sao_Paulo"
        echo "10) Toronto"
        echo "11) Vancouver"
        echo "12) Denver"
        echo "13) Phoenix"
        echo "14) Guatemala"
        echo "15) Panama"
        echo "16) Caracas"
        echo "17) La_Paz"
        echo "18) Montevideo"
        echo "19) Asuncion"
        echo "20) Managua"
        echo "21) San_Salvador"
        echo "22) Tegucigalpa"
        echo "23) San_Jose"
        echo "24) Havana"
        echo "25) Winnipeg"
        echo ""
        read -p "➡️  Opción (1-25): " ciudad
        case $ciudad in
            1) ZONA="America/New_York";;
            2) ZONA="America/Los_Angeles";;
            3) ZONA="America/Chicago";;
            4) ZONA="America/Mexico_City";;
            5) ZONA="America/Bogota";;
            6) ZONA="America/Lima";;
            7) ZONA="America/Santiago";;
            8) ZONA="America/Buenos_Aires";;
            9) ZONA="America/Sao_Paulo";;
            10) ZONA="America/Toronto";;
            11) ZONA="America/Vancouver";;
            12) ZONA="America/Denver";;
            13) ZONA="America/Phoenix";;
            14) ZONA="America/Guatemala";;
            15) ZONA="America/Panama";;
            16) ZONA="America/Caracas";;
            17) ZONA="America/La_Paz";;
            18) ZONA="America/Montevideo";;
            19) ZONA="America/Asuncion";;
            20) ZONA="America/Managua";;
            21) ZONA="America/El_Salvador";;
            22) ZONA="America/Tegucigalpa";;
            23) ZONA="America/Costa_Rica";;
            24) ZONA="America/Havana";;
            25) ZONA="America/Winnipeg";;
            *) ZONA="America/Mexico_City";;
        esac
        ;;
    2)
        echo -e "\n${CYAN}Selecciona tu ciudad en Europa:${NC}"
        echo "1) Madrid"
        echo "2) London"
        echo "3) Paris"
        echo "4) Berlin"
        echo "5) Rome"
        echo "6) Amsterdam"
        echo "7) Brussels"
        echo "8) Vienna"
        echo "9) Zurich"
        echo "10) Stockholm"
        echo "11) Oslo"
        echo "12) Copenhagen"
        echo "13) Helsinki"
        echo "14) Lisbon"
        echo "15) Dublin"
        echo "16) Warsaw"
        echo "17) Prague"
        echo "18) Budapest"
        echo "19) Athens"
        echo "20) Istanbul"
        echo ""
        read -p "➡️  Opción (1-20): " ciudad
        case $ciudad in
            1) ZONA="Europe/Madrid";;
            2) ZONA="Europe/London";;
            3) ZONA="Europe/Paris";;
            4) ZONA="Europe/Berlin";;
            5) ZONA="Europe/Rome";;
            6) ZONA="Europe/Amsterdam";;
            7) ZONA="Europe/Brussels";;
            8) ZONA="Europe/Vienna";;
            9) ZONA="Europe/Zurich";;
            10) ZONA="Europe/Stockholm";;
            11) ZONA="Europe/Oslo";;
            12) ZONA="Europe/Copenhagen";;
            13) ZONA="Europe/Helsinki";;
            14) ZONA="Europe/Lisbon";;
            15) ZONA="Europe/Dublin";;
            16) ZONA="Europe/Warsaw";;
            17) ZONA="Europe/Prague";;
            18) ZONA="Europe/Budapest";;
            19) ZONA="Europe/Athens";;
            20) ZONA="Europe/Istanbul";;
            *) ZONA="Europe/Madrid";;
        esac
        ;;
    3)
        echo -e "\n${CYAN}Selecciona tu ciudad en Asia:${NC}"
        echo "1) Tokyo"
        echo "2) Shanghai"
        echo "3) Hong_Kong"
        echo "4) Singapore"
        echo "5) Seoul"
        echo "6) Mumbai"
        echo "7) Delhi"
        echo "8) Bangkok"
        echo "9) Jakarta"
        echo "10) Manila"
        echo ""
        read -p "➡️  Opción (1-10): " ciudad
        case $ciudad in
            1) ZONA="Asia/Tokyo";;
            2) ZONA="Asia/Shanghai";;
            3) ZONA="Asia/Hong_Kong";;
            4) ZONA="Asia/Singapore";;
            5) ZONA="Asia/Seoul";;
            6) ZONA="Asia/Kolkata";;
            7) ZONA="Asia/Delhi";;
            8) ZONA="Asia/Bangkok";;
            9) ZONA="Asia/Jakarta";;
            10) ZONA="Asia/Manila";;
            *) ZONA="Asia/Tokyo";;
        esac
        ;;
    4) ZONA="Africa/Cairo";;
    5) ZONA="Australia/Sydney";;
    6) ZONA="Pacific/Auckland";;
    7) ZONA="UTC";;
    *) ZONA="America/Mexico_City";;
esac

# Configurar zona horaria del sistema
print_info "Configurando zona horaria: $ZONA"
sudo timedatectl set-timezone $ZONA 2>/dev/null || sudo ln -sf /usr/share/zoneinfo/$ZONA /etc/localtime
print_success "Zona horaria configurada: $(date)"

# ==================== SOLICITAR RUTA DEL ARCHIVO app.py ====================
print_step "CONFIGURANDO LA RUTA DE TU PANEL (app.py)"

echo -e "${YELLOW}📁 Por favor, ingresa la ruta COMPLETA donde se encuentra tu archivo app.py${NC}"
echo -e "${CYAN}Ejemplo: /home/myxsi/Myxsi/app.py${NC}"
echo -e "${CYAN}Ejemplo: /home/usuario/panel/app.py${NC}"
echo ""
read -p "➡️  Ruta del archivo app.py: " RUTA_APP

# Validar que el archivo existe
if [ ! -f "$RUTA_APP" ]; then
    print_error "El archivo no existe en: $RUTA_APP"
    echo ""
    echo -e "${YELLOW}¿Quieres intentar de nuevo? (s/n)${NC}"
    read -p "➡️ " reintentar
    if [[ "$reintentar" == "s" || "$reintentar" == "S" ]]; then
        echo ""
        read -p "➡️  Ruta del archivo app.py: " RUTA_APP
        if [ ! -f "$RUTA_APP" ]; then
            print_error "Archivo no encontrado. Saliendo..."
            exit 1
        fi
    else
        print_error "Saliendo..."
        exit 1
    fi
fi

# Obtener el directorio del archivo
DIR_APP=$(dirname "$RUTA_APP")
print_success "Archivo encontrado: $RUTA_APP"
print_info "Directorio del panel: $DIR_APP"

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
    echo "Ejecuta: ./install.sh"
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

# ==================== INSTALAR DEPENDENCIAS BASE (APT) ====================
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
    netcat-openbsd \
    systemd

print_success "Dependencias base instaladas via APT"

# ==================== INSTALAR DEPENDENCIAS WIFI ====================
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

# ==================== INSTALAR DOCKER ====================
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

# ==================== INSTALAR PAQUETES PYTHON ====================
print_step "INSTALANDO PAQUETES PYTHON"

# Actualizar pip
print_info "Actualizando pip..."
python3 -m pip install --upgrade pip setuptools wheel --break-system-packages

# Instalar dependencias
print_info "Instalando dependencias Python..."
python3 -m pip install --break-system-packages \
    Flask \
    flask-socketio \
    python-socketio \
    eventlet \
    psutil \
    netifaces \
    requests \
    python-dotenv \
    python-pam \
    gunicorn \
    gevent \
    gevent-websocket

print_success "Paquetes Python instalados"

# ==================== INSTALAR IMMICH ====================
print_step "INSTALANDO IMMICH"

print_info "📦 Instalando archivos de Immich..."

mkdir -p ~/immich-app
cd ~/immich-app || exit

wget -q --show-progress -O docker-compose.yml \
https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml

wget -q --show-progress -O .env \
https://github.com/immich-app/immich/releases/latest/download/example.env

mkdir -p ./library ./postgres

# Configurar .env
sed -i 's|UPLOAD_LOCATION=./library|UPLOAD_LOCATION=./library|g' .env
sed -i 's|DB_DATA_LOCATION=./postgres|DB_DATA_LOCATION=./postgres|g' .env
sed -i 's|DB_PASSWORD=postgres|DB_PASSWORD=ImmichSecure2024|g' .env
sed -i "s|# TZ=Etc/UTC|TZ=$ZONA|g" .env

print_info "🚀 Iniciando contenedores de Immich..."
docker compose up -d

print_success "Immich instalado"

# ==================== CREAR SERVICIO SYSTEMD PARA INICIO AUTOMÁTICO ====================
print_step "CONFIGURANDO INICIO AUTOMÁTICO DEL PANEL"

# Crear archivo de servicio systemd
SERVICE_FILE="/etc/systemd/system/myxsi-panel.service"

sudo tee $SERVICE_FILE > /dev/null << EOF
[Unit]
Description=Panel Myxsi - Sistema de Administración
After=network.target network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$DIR_APP
ExecStart=/usr/bin/python3 $RUTA_APP
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myxsi-panel
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="TZ=$ZONA"

[Install]
WantedBy=multi-user.target
EOF

# Recargar systemd y habilitar servicio
sudo systemctl daemon-reload
sudo systemctl enable myxsi-panel.service
print_success "Servicio systemd creado y habilitado"
print_success "El panel se iniciará AUTOMÁTICAMENTE al encender el sistema"

# ==================== CREAR SCRIPT DE INICIO MANUAL ====================
print_step "CREANDO SCRIPT DE INICIO MANUAL"

cat > ~/start_myxsi.sh << EOF
#!/bin/bash
# Panel Myxsi - Inicio manual
cd "$DIR_APP"
python3 "$RUTA_APP"
EOF

chmod +x ~/start_myxsi.sh
print_success "Script manual creado: ~/start_myxsi.sh"

# ==================== CONFIGURAR FIREWALL ====================
print_step "CONFIGURANDO FIREWALL"

sudo ufw --force enable 2>/dev/null || true
sudo ufw allow 22/tcp comment 'SSH' 2>/dev/null || true
sudo ufw allow 5000/tcp comment 'Panel Myxsi' 2>/dev/null || true
sudo ufw allow 2283/tcp comment 'Immich' 2>/dev/null || true

print_success "Firewall configurado (puertos: 22, 5000, 2283)"

# ==================== CREAR COMANDOS ÚTILES ====================
print_step "CREANDO COMANDOS ÚTILES"

if ! grep -q "alias myxsi" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << EOF

# ========== Panel Myxsi - Comandos útiles ==========
alias myxsi-start='sudo systemctl start myxsi-panel'
alias myxsi-stop='sudo systemctl stop myxsi-panel'
alias myxsi-restart='sudo systemctl restart myxsi-panel'
alias myxsi-status='sudo systemctl status myxsi-panel'
alias myxsi-logs='sudo journalctl -u myxsi-panel -f'
alias myxsi-manual='~/start_myxsi.sh'
alias immich-start='cd ~/immich-app && docker compose up -d'
alias immich-stop='cd ~/immich-app && docker compose down'
alias immich-status='docker ps | grep immich'
alias immich-logs='cd ~/immich-app && docker compose logs -f'
EOF
    print_success "Alias agregados a ~/.bashrc"
else
    print_success "Alias ya existentes"
fi

# ==================== INFORMACIÓN FINAL ====================
IP=$(hostname -I | awk '{print $1}')
if [ -z "$IP" ]; then
    IP="IP-DE-TU-MAQUINA"
fi

# Verificar estado de Immich
sleep 3
IMMICH_STATUS=""
if docker ps | grep -q immich; then
    IMMICH_STATUS="✅ Activo"
else
    IMMICH_STATUS="⏳ Iniciando (espera 1-2 minutos)"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALACIÓN COMPLETA FINALIZADA EXITOSAMENTE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📋 CONFIGURACIÓN:${NC}"
echo "   🕐 Zona horaria: $ZONA"
echo "   📁 app.py: $RUTA_APP"
echo "   📂 Directorio: $DIR_APP"
echo "   🚀 Inicio automático: ✅ ACTIVADO (systemd)"
echo ""
echo -e "${CYAN}🌐 SERVICIOS DISPONIBLES:${NC}"
echo "   🔧 Panel Myxsi:  http://$IP:5000"
echo "   📸 Immich:       http://$IP:2283"
echo ""
echo -e "${CYAN}⚙️  COMANDOS ÚTILES:${NC}"
echo "   myxsi-start      - Iniciar el panel"
echo "   myxsi-stop       - Detener el panel"
echo "   myxsi-restart    - Reiniciar el panel"
echo "   myxsi-status     - Ver estado del panel"
echo "   myxsi-logs       - Ver logs del panel"
echo "   myxsi-manual     - Iniciar manualmente"
echo "   immich-start     - Iniciar Immich"
echo "   immich-stop      - Detener Immich"
echo "   immich-status    - Ver estado de Immich"
echo ""
echo -e "${CYAN}🔧 COMANDOS SYSTEMD:${NC}"
echo "   sudo systemctl start myxsi-panel    - Iniciar servicio"
echo "   sudo systemctl stop myxsi-panel     - Detener servicio"
echo "   sudo systemctl restart myxsi-panel  - Reiniciar servicio"
echo "   sudo systemctl status myxsi-panel   - Ver estado"
echo "   sudo journalctl -u myxsi-panel -f   - Ver logs en tiempo real"
echo ""
echo -e "${YELLOW}⚠️  NOTAS IMPORTANTES:${NC}"
echo "   1. El panel se inicia AUTOMÁTICAMENTE con el sistema"
echo "   2. Immich se inicia manualmente con: immich-start"
echo "   3. Para aplicar cambios: source ~/.bashrc o nueva terminal"
echo "   4. Credenciales del panel: Usuario y contraseña del sistema"
echo "   5. Immich tarda 1-2 minutos en iniciar completamente"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 ¡TODO LISTO! El panel se iniciará automáticamente al encender la PC 🎉${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# ==================== PREGUNTAR SI QUIERE INICIAR AHORA ====================
echo -e "${YELLOW}¿Quieres iniciar el panel AHORA? (s/n)${NC}"
read -p "➡️ " iniciar

if [[ "$iniciar" == "s" || "$iniciar" == "S" ]]; then
    echo -e "\n${BLUE}Iniciando Panel Myxsi...${NC}"
    sudo systemctl start myxsi-panel
    sleep 3
    echo -e "${GREEN}✅ Panel iniciado!${NC}"
    echo -e "${CYAN}Accede a: http://$IP:5000${NC}"
    echo ""
    echo -e "${YELLOW}Para ver los logs: myxsi-logs${NC}"
else
    echo -e "\n${BLUE}El panel se iniciará automáticamente cuando reinicies el sistema${NC}"
    echo -e "${BLUE}Puedes iniciarlo manualmente con: myxsi-start${NC}"
fi

echo -e "\n${MAGENTA}✨ ¡INSTALACIÓN COMPLETADA! ✨${NC}"
