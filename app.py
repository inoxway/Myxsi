#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Panel Myxsi - Sistema de Administración para Debian
Características:
- Autenticación PAM (usuarios del sistema)
- Terminal REAL con WebSocket y xterm.js
- Gestor de archivos completo
- Integración con Immich (Google Photos alternativo)
- Monitoreo de sistema (CPU, RAM, disco, procesos, servicios)
- Sistema WiFi con punto de acceso automático
"""

from flask import Flask, render_template, request, jsonify, redirect, url_for, session, send_file
from flask_socketio import SocketIO, emit
import subprocess
import psutil
import os
import platform
from datetime import datetime
import time
import signal
import pwd
import grp
from functools import wraps
import sys
import socket
import pty
import select
import termios
import struct
import fcntl
import threading
import mimetypes
import json
from pathlib import Path
import re

# ==================== CONFIGURACIÓN INICIAL ====================

app = Flask(__name__)
app.secret_key = 'myxsi_panel_secret_key_change_in_production_2024'
app.config['SESSION_COOKIE_SECURE'] = False
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['PERMANENT_SESSION_LIFETIME'] = 3600  # 1 hora
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB max upload

# Configurar SocketIO para WebSocket
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Variables globales
terminal_processes = {}
cache_sistema = {}
ultima_actualizacion = 0
CACHE_TTL = 2

# Configuración WiFi
AP_INTERFACE = 'wlan0'  # Cambia según tu interfaz WiFi
WIFI_CONFIG_FILE = '/tmp/wifi_config.json'
AP_SSID = 'Myxsi'
AP_PASSWORD = 'Myxis123'

# ==================== FUNCIONES WIFI ====================

def obtener_interfaces_wifi():
    """Obtiene las interfaces WiFi disponibles"""
    try:
        resultado = subprocess.run(
            ['iwconfig'], capture_output=True, text=True, timeout=5
        )
        interfaces = []
        for linea in resultado.stdout.split('\n'):
            if 'IEEE 802.11' in linea:
                interface = linea.split()[0]
                interfaces.append(interface)
        return interfaces
    except:
        return []

def verificar_conexion_internet():
    """Verifica si hay conexión a internet"""
    try:
        # Intentar hacer ping a Google
        resultado = subprocess.run(
            ['ping', '-c', '1', '-W', '2', '8.8.8.8'],
            capture_output=True, timeout=3
        )
        return resultado.returncode == 0
    except:
        return False

def obtener_red_conectada():
    """Obtiene la red WiFi a la que está conectado"""
    try:
        # Método 1: Usar iwgetid
        resultado = subprocess.run(
            ['iwgetid'], capture_output=True, text=True, timeout=3
        )
        if resultado.stdout:
            match = re.search(r'ESSID:"([^"]+)"', resultado.stdout)
            if match:
                return match.group(1)
        
        # Método 2: Usar iw dev wlan0 info
        resultado = subprocess.run(
            ['iw', 'dev', AP_INTERFACE, 'info'], capture_output=True, text=True, timeout=3
        )
        if resultado.stdout:
            for linea in resultado.stdout.split('\n'):
                if 'ssid' in linea.lower():
                    ssid = linea.split('ssid')[-1].strip()
                    if ssid and ssid != '':
                        return ssid
        
        # Método 3: Usar nmcli si está disponible
        resultado = subprocess.run(
            ['nmcli', '-t', '-f', 'NAME', 'connection', 'show', '--active'],
            capture_output=True, text=True, timeout=3
        )
        if resultado.stdout:
            lineas = resultado.stdout.strip().split('\n')
            for linea in lineas:
                if linea and 'wifi' in linea.lower():
                    return linea.strip()
        
        # Método 4: Verificar archivo de configuración guardado
        if os.path.exists(WIFI_CONFIG_FILE):
            with open(WIFI_CONFIG_FILE, 'r') as f:
                config = json.load(f)
                return config.get('ssid', 'Red WiFi')
        
        # Método 5: Usar iwconfig
        resultado = subprocess.run(
            ['iwconfig', AP_INTERFACE], capture_output=True, text=True, timeout=3
        )
        if resultado.stdout:
            for linea in resultado.stdout.split('\n'):
                if 'ESSID:' in linea:
                    match = re.search(r'ESSID:"([^"]*)"', linea)
                    if match and match.group(1):
                        return match.group(1)
        
        return None
        
    except Exception as e:
        print(f"Error obteniendo red conectada: {e}")
        return None

def escanear_wifi(interface='wlan0'):
    """Escanea redes WiFi disponibles"""
    try:
        # Activar interfaz si está apagada
        subprocess.run(['sudo', 'ifconfig', interface, 'up'], capture_output=True)
        time.sleep(1)
        
        # Escanear redes
        resultado = subprocess.run(
            ['sudo', 'iwlist', interface, 'scan'],
            capture_output=True, text=True, timeout=20
        )
        
        redes = []
        red_actual = {}
        
        for linea in resultado.stdout.split('\n'):
            linea = linea.strip()
            
            if 'Cell' in linea:
                if red_actual:
                    redes.append(red_actual)
                red_actual = {}
            
            if 'ESSID:' in linea:
                essid = re.search(r'ESSID:"(.+)"', linea)
                if essid:
                    red_actual['ssid'] = essid.group(1)
            
            if 'Encryption key:' in linea:
                if 'on' in linea:
                    red_actual['encrypted'] = True
                else:
                    red_actual['encrypted'] = False
            
            if 'Quality=' in linea:
                quality_match = re.search(r'Quality=(\d+)/(\d+)', linea)
                if quality_match:
                    calidad = int(quality_match.group(1)) / int(quality_match.group(2)) * 100
                    red_actual['signal'] = round(calidad, 1)
        
        if red_actual:
            redes.append(red_actual)
        
        # Filtrar redes sin SSID y ordenar por señal
        redes = [r for r in redes if r.get('ssid') and r['ssid'] not in ['', 'x00']]
        redes.sort(key=lambda x: x.get('signal', 0), reverse=True)
        
        return redes[:30]  # Limitar a 30 redes
        
    except Exception as e:
        print(f"Error escaneando WiFi: {e}")
        return []

def detener_punto_acceso():
    """Detiene el punto de acceso WiFi"""
    try:
        # Detener servicios
        subprocess.run(['sudo', 'systemctl', 'stop', 'hostapd'], capture=True)
        subprocess.run(['sudo', 'systemctl', 'stop', 'dnsmasq'], capture=True)
        time.sleep(1)
        
        # Matar procesos si existen
        subprocess.run(['sudo', 'pkill', '-f', 'hostapd'], capture=True)
        subprocess.run(['sudo', 'pkill', '-f', 'dnsmasq'], capture=True)
        
        # Restaurar interfaz
        subprocess.run(['sudo', 'ifconfig', AP_INTERFACE, 'down'], capture=True)
        subprocess.run(['sudo', 'ifconfig', AP_INTERFACE, 'up'], capture=True)
        
        # Reiniciar NetworkManager
        subprocess.run(['sudo', 'systemctl', 'restart', 'NetworkManager'], capture=True)
        
        print("✅ Punto de acceso detenido")
        return True
    except Exception as e:
        print(f"Error deteniendo AP: {e}")
        return False

def iniciar_punto_acceso(ssid=AP_SSID, password=AP_PASSWORD):
    """Inicia el punto de acceso WiFi"""
    try:
        # Detener cualquier punto de acceso existente
        detener_punto_acceso()
        
        # Configurar hostapd
        hostapd_conf = f"""
interface={AP_INTERFACE}
driver=nl80211
ssid={ssid}
hw_mode=g
channel=6
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase={password}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
"""
        with open('/tmp/hostapd.conf', 'w') as f:
            f.write(hostapd_conf)
        
        # Configurar dnsmasq
        dnsmasq_conf = f"""
interface={AP_INTERFACE}
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
dhcp-option=3,192.168.4.1
dhcp-option=6,192.168.4.1
server=8.8.8.8
log-queries
log-dhcp
listen-address=192.168.4.1
"""
        with open('/tmp/dnsmasq.conf', 'w') as f:
            f.write(dnsmasq_conf)
        
        # Configurar interfaz
        subprocess.run(['sudo', 'ifconfig', AP_INTERFACE, '192.168.4.1', 'netmask', '255.255.255.0', 'up'], capture=True)
        
        # Iniciar servicios
        subprocess.Popen(['sudo', 'hostapd', '/tmp/hostapd.conf'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1)
        subprocess.Popen(['sudo', 'dnsmasq', '-C', '/tmp/dnsmasq.conf'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Habilitar forwarding
        with open('/proc/sys/net/ipv4/ip_forward', 'w') as f:
            f.write('1')
        
        print(f"✅ Punto de acceso iniciado: {ssid} (Contraseña: {password})")
        return True
        
    except Exception as e:
        print(f"Error iniciando punto de acceso: {e}")
        return False

def conectar_wifi(ssid, password):
    """Conecta a una red WiFi"""
    try:
        # Detener punto de acceso si está activo
        detener_punto_acceso()
        time.sleep(2)
        
        # Crear configuración de wpa_supplicant
        wpa_conf = f"""
network={{
    ssid="{ssid}"
    psk="{password}"
    key_mgmt=WPA-PSK
}}
"""
        with open('/tmp/wpa_supplicant.conf', 'w') as f:
            f.write(wpa_conf)
        
        # Conectar
        subprocess.run(['sudo', 'ifconfig', AP_INTERFACE, 'down'], capture=True)
        time.sleep(1)
        subprocess.run(['sudo', 'wpa_supplicant', '-B', '-i', AP_INTERFACE, '-c', '/tmp/wpa_supplicant.conf'], capture=True)
        time.sleep(3)
        subprocess.run(['sudo', 'dhclient', AP_INTERFACE], capture=True)
        time.sleep(3)
        
        # Verificar conexión
        if verificar_conexion_internet():
            # Guardar configuración
            with open(WIFI_CONFIG_FILE, 'w') as f:
                json.dump({'ssid': ssid, 'password': password}, f)
            
            return {'success': True, 'message': f'✅ Conectado a {ssid}'}
        else:
            return {'success': False, 'message': '❌ No se pudo obtener IP'}
            
    except Exception as e:
        return {'success': False, 'message': f'❌ Error: {str(e)}'}

def is_ap_running():
    """Verifica si el punto de acceso está activo"""
    try:
        resultado = subprocess.run(
            ['pgrep', '-f', 'hostapd'], capture_output=True
        )
        return resultado.returncode == 0
    except:
        return False

def obtener_estado_wifi():
    """Obtiene el estado actual del WiFi"""
    return {
        'conectado': verificar_conexion_internet(),
        'red_actual': obtener_red_conectada(),
        'ap_activo': is_ap_running()
    }

def monitorear_conexion():
    """Monitorea la conexión y activa AP si es necesario"""
    while True:
        try:
            if not verificar_conexion_internet() and not is_ap_running():
                print("⚠️ Sin conexión a internet, activando punto de acceso...")
                iniciar_punto_acceso()
            elif verificar_conexion_internet() and is_ap_running():
                print("✅ Conexión restaurada, desactivando punto de acceso...")
                detener_punto_acceso()
            
            time.sleep(10)  # Verificar cada 10 segundos
        except Exception as e:
            print(f"Error en monitoreo: {e}")
            time.sleep(30)

# Iniciar monitoreo de WiFi en segundo plano
wifi_monitor_thread = threading.Thread(target=monitorear_conexion, daemon=True)
wifi_monitor_thread.start()

# ==================== AUTENTICACIÓN PAM (USUARIOS DEL SISTEMA) ====================

def verificar_usuario_sistema(usuario, contraseña):
    """
    Verifica credenciales usando PAM (módulo de autenticación de Linux)
    Esto usa las MISMA CREDENCIALES que usas para iniciar sesión en la máquina
    """
    if not usuario or not contraseña:
        return False
    
    # Método 1: Usar python-pam (la mejor opción)
    try:
        import pam
        p = pam.pam()
        autenticado = p.authenticate(usuario, contraseña)
        if autenticado:
            print(f"✅ Usuario {usuario} autenticado vía PAM")
            return True
        else:
            print(f"⚠️  PAM falló para {usuario}, usando métodos alternativos")
    except ImportError:
        print("⚠️  python-pam no instalado, usando método alternativo")
    except Exception as e:
        print(f"⚠️  Error en PAM: {e}")
    
    # Método 2: Usar el comando 'su' (alternativa universal)
    try:
        cmd = f'echo "{contraseña}" | su - {usuario} -c "exit" 2>/dev/null'
        resultado = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=3
        )
        if resultado.returncode == 0:
            print(f"✅ Usuario {usuario} autenticado vía su")
            return True
    except Exception as e:
        print(f"Error en método su: {e}")
    
    # Método 3: Usar 'sudo' (también válido)
    try:
        cmd = f'echo "{contraseña}" | sudo -S -u {usuario} id 2>/dev/null'
        resultado = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=3
        )
        if resultado.returncode == 0:
            print(f"✅ Usuario {usuario} autenticado vía sudo")
            return True
    except Exception as e:
        print(f"Error en método sudo: {e}")
    
    print(f"❌ Autenticación fallida para usuario: {usuario}")
    return False

def obtener_rol_usuario(usuario):
    """Determina si el usuario es administrador basado en grupos"""
    try:
        if usuario == 'root':
            return 'admin'
        
        try:
            grupos_usuario = [g.gr_name for g in grp.getgrall() if usuario in g.gr_mem]
        except:
            resultado = subprocess.run(
                f'groups {usuario} 2>/dev/null',
                shell=True, capture_output=True, text=True, timeout=2
            )
            if resultado.stdout:
                grupos_usuario = resultado.stdout.strip().split(':')[-1].split()
            else:
                grupos_usuario = []
        
        grupos_admin = ['sudo', 'wheel', 'admin', 'adm', 'root']
        
        for grupo in grupos_admin:
            if grupo in grupos_usuario:
                print(f"✅ Usuario {usuario} es administrador (grupo: {grupo})")
                return 'admin'
        
        return 'usuario'
        
    except Exception as e:
        print(f"Error obteniendo rol: {e}")
        return 'usuario'

def login_requerido(f):
    """Decorador para rutas protegidas"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'usuario' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# ==================== TERMINAL REAL CON WEBSOCKET ====================

def set_winsize(fd, row, col, xpix=0, ypix=0):
    """Configura el tamaño de la ventana del terminal"""
    winsize = struct.pack("HHHH", row, col, xpix, ypix)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)

def create_terminal_process(usuario, sid):
    """Crea un proceso de terminal REAL para el usuario"""
    try:
        # Obtener información del usuario
        user_info = pwd.getpwnam(usuario)
        user_home = user_info.pw_dir
        user_shell = user_info.pw_shell if user_info.pw_shell not in ['/usr/sbin/nologin', '/bin/false'] else '/bin/bash'
        
        # Crear pseudo-terminal (pty)
        master_fd, slave_fd = pty.openpty()
        
        # Configurar el tamaño de la ventana
        set_winsize(master_fd, 24, 80)
        
        # Fork para ejecutar la shell como el usuario
        pid = os.fork()
        
        if pid == 0:  # Proceso hijo
            # Cambiar a la terminal esclava
            os.setsid()
            
            # Configurar terminal como controladora
            fcntl.ioctl(slave_fd, termios.TIOCSCTTY, 0)
            
            # Redirigir stdin, stdout, stderr a la terminal esclava
            os.dup2(slave_fd, 0)
            os.dup2(slave_fd, 1)
            os.dup2(slave_fd, 2)
            
            # Cerrar descriptores no necesarios
            if slave_fd > 2:
                os.close(slave_fd)
            
            # Cambiar al directorio home del usuario
            os.chdir(user_home)
            
            # Cambiar UID y GID al usuario
            os.setgid(user_info.pw_gid)
            os.setuid(user_info.pw_uid)
            
            # Variables de entorno para el usuario
            env = os.environ.copy()
            env['HOME'] = user_home
            env['USER'] = usuario
            env['LOGNAME'] = usuario
            env['SHELL'] = user_shell
            env['TERM'] = 'xterm-256color'
            env['PATH'] = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
            env['PS1'] = f'\\[\\033[01;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '
            
            # Ejecutar la shell real del usuario
            os.execle(user_shell, user_shell, env)
            sys.exit(0)
        
        else:  # Proceso padre
            os.close(slave_fd)
            
            terminal_processes[sid] = {
                'pid': pid,
                'master_fd': master_fd,
                'usuario': usuario,
                'thread': None
            }
            
            # Iniciar thread para leer la salida del terminal
            def read_terminal_output():
                while sid in terminal_processes:
                    try:
                        rlist, _, _ = select.select([master_fd], [], [], 0.1)
                        if rlist:
                            data = os.read(master_fd, 1024)
                            if data:
                                socketio.emit('terminal_output', {'data': data.decode('utf-8', errors='replace')}, room=sid)
                            else:
                                break
                    except (OSError, ValueError):
                        break
                
                if sid in terminal_processes:
                    cleanup_terminal(sid)
            
            thread = threading.Thread(target=read_terminal_output)
            thread.daemon = True
            thread.start()
            terminal_processes[sid]['thread'] = thread
            
            return True
            
    except Exception as e:
        print(f"Error creando terminal: {e}")
        return False

def cleanup_terminal(sid):
    """Limpia el proceso del terminal"""
    if sid in terminal_processes:
        proc = terminal_processes[sid]
        try:
            os.kill(proc['pid'], signal.SIGTERM)
            os.close(proc['master_fd'])
        except:
            pass
        del terminal_processes[sid]

# ==================== FUNCIONES DEL SISTEMA ====================

def convertir_timedelta(td):
    """Convierte timedelta a string legible"""
    if td is None:
        return "0s"
    dias = td.days
    horas = td.seconds // 3600
    minutos = (td.seconds % 3600) // 60
    segundos = td.seconds % 60
    
    partes = []
    if dias > 0: partes.append(f"{dias}d")
    if horas > 0: partes.append(f"{horas}h")
    if minutos > 0: partes.append(f"{minutos}m")
    if segundos > 0 or not partes: partes.append(f"{segundos}s")
    
    return " ".join(partes)

def obtener_estado_sistema():
    """Obtiene estado actual del sistema con caché"""
    global cache_sistema, ultima_actualizacion
    
    ahora = time.time()
    if ahora - ultima_actualizacion < CACHE_TTL and cache_sistema:
        return cache_sistema
    
    try:
        cpu_percent = psutil.cpu_percent(interval=0.5)
        cpu_count = psutil.cpu_count()
        cpu_freq = psutil.cpu_freq()
        memoria = psutil.virtual_memory()
        swap = psutil.swap_memory()
        disco = psutil.disk_usage('/')
        net = psutil.net_io_counters()
        
        # Listar discos
        discos = []
        for part in psutil.disk_partitions():
            if part.fstype and 'loop' not in part.device and part.fstype not in ['squashfs']:
                try:
                    uso = psutil.disk_usage(part.mountpoint)
                    discos.append({
                        'dispositivo': part.device,
                        'montaje': part.mountpoint,
                        'tipo': part.fstype,
                        'total': uso.total,
                        'usado': uso.used,
                        'libre': uso.free,
                        'porcentaje': uso.percent
                    })
                except:
                    pass
        
        # Temperaturas
        temperaturas = {}
        try:
            if os.path.exists('/sys/class/thermal/'):
                for zone in os.listdir('/sys/class/thermal/'):
                    if zone.startswith('thermal_zone'):
                        temp_file = f'/sys/class/thermal/{zone}/temp'
                        if os.path.exists(temp_file):
                            with open(temp_file, 'r') as f:
                                temp = float(f.read().strip()) / 1000.0
                                type_file = f'/sys/class/thermal/{zone}/type'
                                if os.path.exists(type_file):
                                    with open(type_file, 'r') as ft:
                                        zone_type = ft.read().strip()
                                    temperaturas[zone_type] = f"{temp:.1f}°C"
                                else:
                                    temperaturas[f'CPU{len(temperaturas)}'] = f"{temp:.1f}°C"
        except:
            pass
        
        boot_time = datetime.fromtimestamp(psutil.boot_time())
        uptime_str = convertir_timedelta(datetime.now() - boot_time)
        
        cache_sistema = {
            'cpu': {
                'porcentaje': cpu_percent,
                'nucleos': cpu_count,
                'frecuencia': cpu_freq.current if cpu_freq else 0,
                'load_avg': list(psutil.getloadavg())
            },
            'memoria': {
                'total': memoria.total,
                'disponible': memoria.available,
                'usado': memoria.used,
                'porcentaje': memoria.percent,
                'swap_total': swap.total,
                'swap_usado': swap.used,
                'swap_porcentaje': swap.percent if swap.total > 0 else 0
            },
            'disco': {
                'total': disco.total,
                'usado': disco.used,
                'libre': disco.free,
                'porcentaje': disco.percent,
                'discos': discos[:5]
            },
            'red': {
                'rx': net.bytes_recv,
                'tx': net.bytes_sent
            },
            'temperaturas': temperaturas,
            'hostname': platform.node(),
            'sistema': f"{platform.system()} {platform.release()}",
            'uptime': uptime_str,
            'procesos_totales': len(psutil.pids())
        }
        
        ultima_actualizacion = ahora
        return cache_sistema
        
    except Exception as e:
        print(f"Error obteniendo estado: {e}")
        return cache_sistema or {}

def obtener_procesos(limite=50):
    """Obtiene lista de procesos ordenados por CPU"""
    procesos = []
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'status', 'username']):
            try:
                info = proc.info
                procesos.append({
                    'pid': info['pid'],
                    'nombre': (info['name'] or '???')[:50],
                    'cpu': round(info['cpu_percent'] or 0, 1),
                    'memoria': round(info['memory_percent'] or 0, 1),
                    'estado': info['status'] or '?',
                    'usuario': info['username'] or '?'
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    except Exception as e:
        print(f"Error obteniendo procesos: {e}")
    
    procesos.sort(key=lambda x: x['cpu'], reverse=True)
    return procesos[:limite]

def ejecutar_comando(comando, timeout=30):
    """Ejecuta comando de forma segura"""
    try:
        resultado = subprocess.run(
            comando, shell=True, capture_output=True, text=True, timeout=timeout
        )
        salida = resultado.stdout if resultado.stdout else resultado.stderr
        if len(salida) > 10000:
            salida = salida[:10000] + "\n... (truncado)"
        return {
            'success': resultado.returncode == 0,
            'output': salida,
            'code': resultado.returncode
        }
    except subprocess.TimeoutExpired:
        return {'success': False, 'output': '⏰ Tiempo de espera agotado', 'code': -1}
    except Exception as e:
        return {'success': False, 'output': f'❌ Error: {str(e)}', 'code': -1}

# ==================== GESTOR DE ARCHIVOS ====================

def listar_directorio(ruta_base="/"):
    """Lista el contenido de un directorio de forma segura"""
    try:
        if not os.path.exists(ruta_base):
            return {'error': 'Directorio no existe', 'items': []}
        
        if not os.access(ruta_base, os.R_OK):
            return {'error': 'Permiso denegado', 'items': []}
        
        items = []
        for item in os.listdir(ruta_base):
            ruta_completa = os.path.join(ruta_base, item)
            try:
                stats = os.stat(ruta_completa)
                items.append({
                    'nombre': item,
                    'ruta': ruta_completa,
                    'es_directorio': os.path.isdir(ruta_completa),
                    'tamaño': stats.st_size if not os.path.isdir(ruta_completa) else 0,
                    'modificado': datetime.fromtimestamp(stats.st_mtime).strftime('%Y-%m-%d %H:%M:%S'),
                    'permisos': oct(stats.st_mode)[-3:]
                })
            except (PermissionError, OSError):
                continue
        
        items.sort(key=lambda x: (not x['es_directorio'], x['nombre'].lower()))
        
        return {
            'success': True,
            'ruta_actual': ruta_base,
            'ruta_padre': os.path.dirname(ruta_base) if ruta_base != '/' else None,
            'items': items
        }
    except Exception as e:
        return {'error': str(e), 'items': []}

def obtener_info_immich():
    """Obtiene información de instalación de Immich"""
    rutas_posibles = [
        '/opt/immich',
        '/home/*/immich',
        '/var/lib/immich',
        '/docker/immich',
        os.path.expanduser('~/immich')
    ]
    
    # Verificar si Immich está instalado via Docker
    tiene_docker = False
    try:
        resultado = subprocess.run(
            'docker ps --filter "name=immich" --format "{{.Names}}" 2>/dev/null',
            shell=True, capture_output=True, text=True, timeout=5
        )
        contenedores = resultado.stdout.strip().split('\n') if resultado.stdout else []
        tiene_docker = any('immich' in c for c in contenedores)
    except:
        pass
    
    # Verificar si existe el directorio de Immich
    immich_dir = None
    for ruta in rutas_posibles:
        if '*' in ruta:
            import glob
            for encontrado in glob.glob(ruta):
                if os.path.exists(encontrado):
                    immich_dir = encontrado
                    break
        elif os.path.exists(ruta):
            immich_dir = ruta
            break
    
    return {
        'instalado': immich_dir is not None or tiene_docker,
        'directorio': immich_dir,
        'docker': tiene_docker,
        'url': 'http://localhost:2283' if tiene_docker else None
    }

# ==================== RUTAS DE AUTENTICACIÓN ====================

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Página de inicio de sesión con usuarios del sistema"""
    if request.method == 'POST':
        usuario = request.form.get('usuario', '').strip()
        contraseña = request.form.get('contraseña', '')
        
        if not usuario or not contraseña:
            return render_template('login.html', error="❌ Por favor ingresa usuario y contraseña")
        
        if verificar_usuario_sistema(usuario, contraseña):
            session.permanent = True
            session['usuario'] = usuario
            session['rol'] = obtener_rol_usuario(usuario)
            print(f"✅ Sesión iniciada: {usuario} (Rol: {session['rol']})")
            return redirect(url_for('index'))
        else:
            print(f"❌ Intento fallido de login para: {usuario}")
            return render_template('login.html', error="❌ Usuario o contraseña incorrectos")
    
    usuarios = []
    try:
        for user in pwd.getpwall():
            if user.pw_uid == 0 or (user.pw_uid >= 1000 and user.pw_uid < 65534):
                if user.pw_shell not in ['/usr/sbin/nologin', '/bin/false']:
                    usuarios.append({'username': user.pw_name, 'uid': user.pw_uid})
    except:
        pass
    
    return render_template('login.html', usuarios=usuarios)

@app.route('/logout')
def logout():
    """Cierra sesión"""
    for sid in list(terminal_processes.keys()):
        if terminal_processes[sid]['usuario'] == session.get('usuario'):
            cleanup_terminal(sid)
    session.clear()
    return redirect(url_for('login'))

# ==================== RUTAS PRINCIPALES ====================

@app.route('/')
@login_requerido
def index():
    """Página principal"""
    return render_template('index.html', usuario=session['usuario'], rol=session['rol'])

@app.route('/terminal')
@login_requerido
def terminal_page():
    """Página con terminal REAL usando xterm.js"""
    return render_template('terminal.html', usuario=session['usuario'], rol=session['rol'])

@app.route('/storage')
@login_requerido
def storage_page():
    """Página del gestor de archivos"""
    return render_template('storage.html', usuario=session['usuario'], rol=session['rol'])

@app.route('/immich')
@login_requerido
def immich_page():
    """Página de Immich - Google Photos alternativo"""
    info = obtener_info_immich()
    return render_template('immich.html', usuario=session['usuario'], rol=session['rol'], immich_info=info)

@app.route('/scripts')
@login_requerido
def scripts_page():
    """Página de scripts"""
    scripts_dir = os.path.join(os.path.dirname(__file__), 'scripts')
    scripts = []
    
    if os.path.exists(scripts_dir):
        for file in os.listdir(scripts_dir):
            if file.endswith(('.sh', '.py')) and not file.startswith('.'):
                ruta = os.path.join(scripts_dir, file)
                scripts.append({
                    'nombre': file,
                    'tipo': 'bash' if file.endswith('.sh') else 'python',
                    'tamaño': os.path.getsize(ruta)
                })
    
    return render_template('scripts.html', usuario=session['usuario'], rol=session['rol'], scripts=scripts)

# ==================== API ENDPOINTS ====================

@app.route('/api/estado')
@login_requerido
def api_estado():
    """API de estado del sistema"""
    return jsonify(obtener_estado_sistema())

@app.route('/api/procesos')
@login_requerido
def api_procesos():
    """API de procesos"""
    return jsonify(obtener_procesos())

@app.route('/api/ejecutar', methods=['POST'])
@login_requerido
def api_ejecutar():
    """Ejecuta comandos predefinidos del sistema"""
    data = request.get_json()
    comando = data.get('comando', '')
    
    comandos = {
        'actualizar': 'sudo apt update 2>&1',
        'actualizar_completo': 'sudo apt update && sudo apt upgrade -y 2>&1',
        'limpiar': 'sudo apt autoremove -y && sudo apt autoclean 2>&1',
        'apagar': 'shutdown -h now',
        'reiniciar': 'shutdown -r now'
    }
    
    if comando in comandos:
        return jsonify(ejecutar_comando(comandos[comando]))
    return jsonify({'success': False, 'output': 'Comando no permitido', 'code': -1})

@app.route('/api/almacenamiento')
@login_requerido
def api_almacenamiento():
    """API de información de almacenamiento"""
    estado = obtener_estado_sistema()
    return jsonify({
        'discos': estado.get('disco', {}).get('discos', []),
        'disco_principal': estado.get('disco', {})
    })

@app.route('/api/terminal', methods=['POST'])
@login_requerido
def api_terminal():
    """Ejecuta comandos en la terminal con restricciones"""
    data = request.get_json()
    comando = data.get('comando', '').strip()
    
    if not comando:
        return jsonify({'success': False, 'output': '❌ Comando vacío', 'code': -1})
    
    comandos_bloqueados = ['rm -rf', 'mkfs', 'dd', 'chmod 777', 'passwd', 'userdel']
    for peligroso in comandos_bloqueados:
        if peligroso in comando:
            return jsonify({'success': False, 'output': f'⚠️ Comando bloqueado: {peligroso}', 'code': -1})
    
    return jsonify(ejecutar_comando(comando, timeout=15))

@app.route('/api/ejecutar_script', methods=['POST'])
@login_requerido
def api_ejecutar_script():
    """Ejecuta un script del directorio scripts"""
    data = request.get_json()
    script_nombre = data.get('script', '')
    
    if '..' in script_nombre or script_nombre.startswith('/'):
        return jsonify({'success': False, 'output': '❌ Nombre inválido', 'code': -1})
    
    scripts_dir = os.path.join(os.path.dirname(__file__), 'scripts')
    script_path = os.path.join(scripts_dir, script_nombre)
    
    if os.path.exists(script_path) and script_nombre.endswith(('.sh', '.py')):
        comando = f'bash {script_path}' if script_nombre.endswith('.sh') else f'python3 {script_path}'
        return jsonify(ejecutar_comando(comando, timeout=60))
    
    return jsonify({'success': False, 'output': f'❌ Script no encontrado: {script_nombre}', 'code': -1})

@app.route('/api/crear_script', methods=['POST'])
@login_requerido
def api_crear_script():
    """Crea un nuevo script"""
    data = request.get_json()
    nombre = data.get('nombre', '').strip()
    contenido = data.get('contenido', '')
    
    if not nombre:
        return jsonify({'success': False, 'output': '❌ Nombre requerido', 'code': -1})
    
    if not nombre.endswith('.sh'):
        nombre += '.sh'
    
    if '..' in nombre or '/' in nombre:
        return jsonify({'success': False, 'output': '❌ Nombre inválido', 'code': -1})
    
    scripts_dir = os.path.join(os.path.dirname(__file__), 'scripts')
    os.makedirs(scripts_dir, exist_ok=True)
    script_path = os.path.join(scripts_dir, nombre)
    
    try:
        with open(script_path, 'w') as f:
            if not contenido.startswith('#!/bin'):
                contenido = '#!/bin/bash\n' + contenido
            f.write(contenido)
        os.chmod(script_path, 0o755)
        return jsonify({'success': True, 'output': f'✅ Script {nombre} creado', 'code': 0})
    except Exception as e:
        return jsonify({'success': False, 'output': f'❌ Error: {str(e)}', 'code': -1})

@app.route('/api/servicios')
@login_requerido
def api_servicios():
    """Lista servicios del sistema"""
    try:
        resultado = subprocess.run(
            'systemctl list-units --type=service --all --no-pager --no-legend | head -20',
            shell=True, capture_output=True, text=True, timeout=10
        )
        servicios = []
        for line in resultado.stdout.split('\n'):
            if line.strip():
                partes = line.split()
                if len(partes) >= 4:
                    servicios.append({
                        'nombre': partes[0],
                        'estado': partes[3],
                        'descripcion': ' '.join(partes[4:])
                    })
        return jsonify(servicios)
    except:
        return jsonify([])

@app.route('/api/control_servicio', methods=['POST'])
@login_requerido
def api_control_servicio():
    """Controla servicios del sistema"""
    data = request.get_json()
    servicio = data.get('servicio')
    accion = data.get('accion')
    
    if servicio and accion in ['start', 'stop', 'restart']:
        return jsonify(ejecutar_comando(f'sudo systemctl {accion} {servicio} 2>&1'))
    return jsonify({'success': False, 'output': '❌ Acción no válida', 'code': -1})

@app.route('/api/matar_proceso', methods=['POST'])
@login_requerido
def api_matar_proceso():
    """Termina un proceso por PID"""
    data = request.get_json()
    pid = data.get('pid')
    
    try:
        pid = int(pid)
        if pid <= 0 or pid in [1, 2, 3, 4, 5]:
            return jsonify({'success': False, 'output': '❌ No se puede matar este proceso', 'code': -1})
        os.kill(pid, signal.SIGTERM)
        return jsonify({'success': True, 'output': f'✅ Proceso {pid} terminado', 'code': 0})
    except ProcessLookupError:
        return jsonify({'success': False, 'output': f'❌ Proceso {pid} no encontrado', 'code': -1})
    except PermissionError:
        return jsonify({'success': False, 'output': f'❌ Permiso denegado', 'code': -1})
    except Exception as e:
        return jsonify({'success': False, 'output': f'❌ Error: {str(e)}', 'code': -1})

# ==================== API WIFI ====================

@app.route('/api/wifi/estado')
@login_requerido
def api_wifi_estado():
    """Obtiene estado del WiFi"""
    return jsonify(obtener_estado_wifi())

@app.route('/api/wifi/escanear')
@login_requerido
def api_wifi_escanear():
    """Escanea redes WiFi disponibles"""
    redes = escanear_wifi(AP_INTERFACE)
    return jsonify(redes)

@app.route('/api/wifi/conectar', methods=['POST'])
@login_requerido
def api_wifi_conectar():
    """Conecta a una red WiFi"""
    data = request.get_json()
    ssid = data.get('ssid')
    password = data.get('password', '')
    
    if not ssid:
        return jsonify({'success': False, 'message': 'SSID requerido'})
    
    resultado = conectar_wifi(ssid, password)
    return jsonify(resultado)

@app.route('/api/wifi/ap/estado')
@login_requerido
def api_wifi_ap_estado():
    """Estado del punto de acceso"""
    return jsonify({
        'activo': is_ap_running(),
        'ssid': AP_SSID if is_ap_running() else None
    })

@app.route('/api/wifi/ap/desactivar', methods=['POST'])
@login_requerido
def api_wifi_ap_desactivar():
    """Desactiva el punto de acceso manualmente"""
    if detener_punto_acceso():
        return jsonify({'success': True, 'message': 'Punto de acceso desactivado'})
    return jsonify({'success': False, 'message': 'Error al desactivar'})

# ==================== API GESTOR DE ARCHIVOS ====================

@app.route('/api/storage/browse')
@login_requerido
def api_storage_browse():
    """API para navegar por el sistema de archivos"""
    ruta = request.args.get('path', '/')
    
    if '..' in ruta:
        return jsonify({'error': 'Ruta no permitida', 'items': []})
    
    rutas_prohibidas = ['/etc/shadow', '/etc/passwd', '/root']
    for prohibida in rutas_prohibidas:
        if ruta.startswith(prohibida) and session['rol'] != 'admin':
            return jsonify({'error': 'Acceso denegado', 'items': []})
    
    resultado = listar_directorio(ruta)
    return jsonify(resultado)

@app.route('/api/storage/download')
@login_requerido
def api_storage_download():
    """Descargar un archivo"""
    ruta = request.args.get('path', '')
    
    if '..' in ruta:
        return jsonify({'error': 'Ruta no permitida'}), 403
    
    if not os.path.exists(ruta) or os.path.isdir(ruta):
        return jsonify({'error': 'Archivo no encontrado'}), 404
    
    return send_file(ruta, as_attachment=True)

@app.route('/api/storage/upload', methods=['POST'])
@login_requerido
def api_storage_upload():
    """Subir archivos al servidor"""
    if 'file' not in request.files:
        return jsonify({'success': False, 'error': 'No se seleccionó archivo'})
    
    file = request.files['file']
    ruta = request.form.get('path', '/tmp')
    
    if file.filename == '':
        return jsonify({'success': False, 'error': 'Archivo vacío'})
    
    if '..' in ruta:
        return jsonify({'success': False, 'error': 'Ruta no permitida'})
    
    try:
        ruta_completa = os.path.join(ruta, file.filename)
        file.save(ruta_completa)
        return jsonify({'success': True, 'message': f'✅ Archivo {file.filename} subido'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/storage/create_folder', methods=['POST'])
@login_requerido
def api_storage_create_folder():
    """Crear una nueva carpeta"""
    data = request.get_json()
    ruta = data.get('path', '')
    nombre = data.get('name', '')
    
    if not nombre:
        return jsonify({'success': False, 'error': 'Nombre requerido'})
    
    if '..' in ruta or '..' in nombre or '/' in nombre:
        return jsonify({'success': False, 'error': 'Nombre no permitido'})
    
    try:
        nueva_ruta = os.path.join(ruta, nombre)
        os.makedirs(nueva_ruta, exist_ok=True)
        return jsonify({'success': True, 'message': f'✅ Carpeta {nombre} creada'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

# ==================== API IMMICH ====================

@app.route('/api/immich/status')
@login_requerido
def api_immich_status():
    """Obtener estado de Immich"""
    info = obtener_info_immich()
    
    if info['docker']:
        try:
            resultado = subprocess.run(
                'docker ps --filter "name=immich" --format "table {{.Names}}\t{{.Status}}"',
                shell=True, capture_output=True, text=True, timeout=5
            )
            info['contenedores'] = resultado.stdout
        except:
            pass
    
    return jsonify(info)

@app.route('/api/immich/install', methods=['POST'])
@login_requerido
def api_immich_install():
    """Instalar Immich vía Docker"""
    if session['rol'] != 'admin':
        return jsonify({'success': False, 'error': 'Se requieren permisos de administrador'})
    
    cmd = '''
    cd ~ && 
    curl -fsSL https://raw.githubusercontent.com/immich-app/immich/main/install.sh | bash
    '''
    
    resultado = ejecutar_comando(cmd, timeout=300)
    return jsonify(resultado)

# ==================== SOCKET.IO EVENTOS (TERMINAL REAL) ====================

@socketio.on('connect')
def handle_connect():
    """Cliente conectado"""
    print(f"🔌 Cliente conectado: {request.sid}")

@socketio.on('disconnect')
def handle_disconnect():
    """Cliente desconectado - limpiar terminal"""
    sid = request.sid
    if sid in terminal_processes:
        cleanup_terminal(sid)
    print(f"🔌 Cliente desconectado: {sid}")

@socketio.on('terminal_init')
def handle_terminal_init(data):
    """Inicializar terminal REAL para el usuario"""
    sid = request.sid
    usuario = session.get('usuario')
    
    if not usuario:
        emit('terminal_error', {'error': 'No hay sesión activa'})
        return
    
    if sid in terminal_processes:
        cleanup_terminal(sid)
    
    if create_terminal_process(usuario, sid):
        emit('terminal_ready', {'message': f'Terminal iniciada para {usuario}'})
    else:
        emit('terminal_error', {'error': 'No se pudo iniciar la terminal'})

@socketio.on('terminal_input')
def handle_terminal_input(data):
    """Enviar input al terminal REAL"""
    sid = request.sid
    
    if sid in terminal_processes:
        try:
            master_fd = terminal_processes[sid]['master_fd']
            input_data = data.get('data', '')
            os.write(master_fd, input_data.encode('utf-8'))
        except Exception as e:
            emit('terminal_error', {'error': str(e)})

@socketio.on('terminal_resize')
def handle_terminal_resize(data):
    """Redimensionar ventana del terminal"""
    sid = request.sid
    rows = data.get('rows', 24)
    cols = data.get('cols', 80)
    
    if sid in terminal_processes:
        try:
            master_fd = terminal_processes[sid]['master_fd']
            set_winsize(master_fd, rows, cols)
        except Exception as e:
            print(f"Error redimensionando: {e}")

# ==================== INICIO DE LA APLICACIÓN ====================

if __name__ == '__main__':
    # Crear directorio de scripts
    scripts_dir = os.path.join(os.path.dirname(__file__), 'scripts')
    os.makedirs(scripts_dir, exist_ok=True)
    
    # Scripts de ejemplo
    scripts_ejemplo = [
        ('ejemplo.sh', '#!/bin/bash\necho "=== Panel Myxsi ===="\necho "📅 Fecha: $(date)"\necho "⏱️  Uptime: $(uptime)"\necho "💾 Memoria: $(free -h)"\necho "💿 Disco: $(df -h /)"\n'),
        ('info_sistema.sh', '#!/bin/bash\necho "=== Información del Sistema ==="\necho "Hostname: $(hostname)"\necho "Kernel: $(uname -r)"\necho "CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"\n'),
        ('monitoreo_red.sh', '#!/bin/bash\necho "=== Monitoreo de Red ==="\nip addr show | grep -E "^[0-9]+:"\nss -tunap | head -10\n')
    ]
    
    for nombre, contenido in scripts_ejemplo:
        script_path = os.path.join(scripts_dir, nombre)
        if not os.path.exists(script_path):
            with open(script_path, 'w') as f:
                f.write(contenido)
            os.chmod(script_path, 0o755)
            print(f"✅ Script de ejemplo creado: {nombre}")
    
    # Verificar e iniciar estado WiFi al arrancar
    print("\n🔍 Verificando estado de conexión...")
    if not verificar_conexion_internet():
        print("⚠️ Sin conexión a internet, activando punto de acceso...")
        time.sleep(2)  # Esperar a que el sistema esté listo
        iniciar_punto_acceso()
    else:
        print("✅ Conexión a internet detectada")
        red = obtener_red_conectada()
        if red:
            print(f"📶 Conectado a: {red}")
    
    # Obtener IP de la máquina
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
    except:
        ip = "IP-DE-TU-MAQUINA"
    
    print("\n" + "="*70)
    print("✅ Panel Myxsi - Sistema de Administración para Debian")
    print("="*70)
    print("🔐 Autenticación: Usuarios del sistema (PAM)")
    print("💻 Terminal REAL con xterm.js + WebSocket")
    print("📁 Gestor de archivos completo")
    print("📸 Integración con Immich (Google Photos alternativo)")
    print("📶 Sistema WiFi con punto de acceso automático")
    print("="*70)
    print(f"📱 Accede desde cualquier dispositivo en: http://{ip}:5000")
    if is_ap_running():
        print(f"📡 Punto de acceso activo: {AP_SSID} (Contraseña: {AP_PASSWORD})")
        print(f"🔗 Conéctate al AP y accede a: http://192.168.4.1:5000")
    print("="*70)
    print("⚠️  Presiona Ctrl+C para detener el panel")
    print("="*70 + "\n")
    
    # Ejecutar la aplicación con SocketIO
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True) 
