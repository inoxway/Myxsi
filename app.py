from flask import Flask, render_template, request, jsonify, redirect, url_for, session
import subprocess
import psutil
import os
import platform
from datetime import datetime
import time
import signal
import pwd
import spwd
import crypt
from functools import wraps

app = Flask(__name__)
app.secret_key = 'tu_clave_secreta_muy_segura_cambia_esto_123456'

# ==================== SISTEMA DE AUTENTICACIÓN ====================

def verificar_usuario_sistema(usuario, contraseña):
    """
    Verifica si el usuario y contraseña son válidos en el sistema Linux
    """
    try:
        # Obtener información del usuario del sistema
        pwd_info = pwd.getpwnam(usuario)
        
        # Obtener contraseña encriptada del shadow
        try:
            shadow_info = spwd.getspnam(usuario)
            contraseña_encriptada = shadow_info.sp_pwd
        except:
            # Si no se puede leer shadow, intentar con autenticación por PAM
            return verificar_con_pam(usuario, contraseña)
        
        # Verificar contraseña
        if contraseña_encriptada and contraseña_encriptada not in ['!', '*', 'x']:
            return crypt.crypt(contraseña, contraseña_encriptada) == contraseña_encriptada
        
        return False
        
    except KeyError:
        # Usuario no existe
        return False
    except Exception as e:
        print(f"Error verificando usuario: {e}")
        return False

def verificar_con_pam(usuario, contraseña):
    """
    Verificar usando PAM (más seguro, requiere python3-pam)
    """
    try:
        import pam
        p = pam.pam()
        return p.authenticate(usuario, contraseña)
    except ImportError:
        # Fallback: intentar con passwd
        try:
            import crypt
            shadow = spwd.getspnam(usuario)
            return crypt.crypt(contraseña, shadow.sp_pwd) == shadow.sp_pwd
        except:
            return False

def obtener_rol_usuario(usuario):
    """
    Determina el rol del usuario basado en grupos del sistema
    """
    try:
        # Obtener grupos del usuario
        grupos = subprocess.run(
            f'groups {usuario}',
            shell=True,
            capture_output=True,
            text=True
        ).stdout
        
        # Si está en grupo sudo, admin, o wheel -> es administrador
        if usuario == 'root' or 'sudo' in grupos or 'wheel' in grupos or 'admin' in grupos:
            return 'admin'
        return 'usuario'
    except:
        return 'usuario'

def login_requerido(f):
    """Decorador para rutas que requieren login"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'usuario' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# ==================== RUTAS DE AUTENTICACIÓN ====================

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Página de inicio de sesión con usuarios del sistema"""
    if request.method == 'POST':
        usuario = request.form.get('usuario', '').strip()
        contraseña = request.form.get('contraseña', '')
        
        if verificar_usuario_sistema(usuario, contraseña):
            session['usuario'] = usuario
            session['rol'] = obtener_rol_usuario(usuario)
            return redirect(url_for('index'))
        else:
            return render_template('login.html', error="Usuario o contraseña incorrectos")
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """Cierra sesión"""
    session.clear()
    return redirect(url_for('login'))

# ==================== FUNCIONES DEL SISTEMA ====================

# Variables globales para caché
cache_sistema = {}
ultima_actualizacion = 0

def convertir_timedelta(td):
    if td is None:
        return "0s"
    horas = td.seconds // 3600
    minutos = (td.seconds % 3600) // 60
    segundos = td.seconds % 60
    if horas > 0:
        return f"{horas}h {minutos}m"
    elif minutos > 0:
        return f"{minutos}m {segundos}s"
    else:
        return f"{segundos}s"

def obtener_estado_sistema():
    global cache_sistema, ultima_actualizacion
    
    ahora = time.time()
    if ahora - ultima_actualizacion < 2 and cache_sistema:
        return cache_sistema
    
    try:
        cpu_percent = psutil.cpu_percent(interval=0.5)
        cpu_count = psutil.cpu_count()
        cpu_freq = psutil.cpu_freq()
        
        memoria = psutil.virtual_memory()
        swap = psutil.swap_memory()
        disco = psutil.disk_usage('/')
        
        discos = []
        for part in psutil.disk_partitions():
            if part.fstype and 'loop' not in part.device:
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
        
        net = psutil.net_io_counters()
        
        temperaturas = {}
        try:
            if os.path.exists('/sys/class/thermal/thermal_zone0/temp'):
                with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                    temp = float(f.read().strip()) / 1000.0
                    temperaturas['CPU'] = f"{temp:.1f}°C"
        except:
            temperaturas['CPU'] = 'N/A'
        
        boot_time = datetime.fromtimestamp(psutil.boot_time())
        uptime_delta = datetime.now() - boot_time
        uptime_str = convertir_timedelta(uptime_delta)
        
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
                'discos': discos
            },
            'red': {
                'rx': net.bytes_recv,
                'tx': net.bytes_sent,
                'rx_paquetes': net.packets_recv,
                'tx_paquetes': net.packets_sent
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

def obtener_procesos():
    procesos = []
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'status', 'username']):
            try:
                info = proc.info
                procesos.append({
                    'pid': info['pid'],
                    'nombre': info['name'] or '???',
                    'cpu': info['cpu_percent'] or 0,
                    'memoria': info['memory_percent'] or 0,
                    'estado': info['status'] or '?',
                    'usuario': info['username'] or '?'
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    except Exception as e:
        print(f"Error obteniendo procesos: {e}")
    
    procesos.sort(key=lambda x: x['cpu'], reverse=True)
    return procesos[:50]

def ejecutar_comando(comando, timeout=30):
    try:
        resultado = subprocess.run(
            comando,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return {
            'success': resultado.returncode == 0,
            'output': resultado.stdout if resultado.stdout else resultado.stderr,
            'code': resultado.returncode
        }
    except subprocess.TimeoutExpired:
        return {'success': False, 'output': 'Comando agotó el tiempo de espera', 'code': -1}
    except Exception as e:
        return {'success': False, 'output': str(e), 'code': -1}

# ==================== RUTAS PROTEGIDAS ====================

@app.route('/')
@login_requerido
def index():
    return render_template('index.html', usuario=session['usuario'], rol=session['rol'])

@app.route('/scripts')
@login_requerido
def scripts_page():
    scripts_dir = os.path.join(os.path.dirname(__file__), 'scripts')
    scripts = []
    
    if os.path.exists(scripts_dir):
        for file in os.listdir(scripts_dir):
            if file.endswith('.sh') or file.endswith('.py'):
                scripts.append({
                    'nombre': file,
                    'ruta': os.path.join(scripts_dir, file),
                    'tipo': 'bash' if file.endswith('.sh') else 'python'
                })
    
    return render_template('scripts.html', usuario=session['usuario'], rol=session['rol'], scripts=scripts)

@app.route('/api/estado')
@login_requerido
def api_estado():
    return jsonify(obtener_estado_sistema())

@app.route('/api/procesos')
@login_requerido
def api_procesos():
    return jsonify(obtener_procesos())

@app.route('/api/ejecutar', methods=['POST'])
@login_requerido
def api_ejecutar():
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
    else:
        return jsonify({'success': False, 'output': 'Comando no permitido', 'code': -1})

@app.route('/api/almacenamiento')
@login_requerido
def api_almacenamiento():
    estado = obtener_estado_sistema()
    return jsonify({
        'discos': estado.get('disco', {}).get('discos', []),
        'disco_principal': {
            'total': estado.get('disco', {}).get('total', 0),
            'usado': estado.get('disco', {}).get('usado', 0),
            'libre': estado.get('disco', {}).get('libre', 0),
            'porcentaje': estado.get('disco', {}).get('porcentaje', 0)
        }
    })

@app.route('/api/terminal', methods=['POST'])
@login_requerido
def api_terminal():
    data = request.get_json()
    comando = data.get('comando', '')
    
    comandos_permitidos = ['ls', 'pwd', 'whoami', 'echo', 'cat', 'grep', 'ps', 'df', 'free', 'uptime', 'top', 'htop']
    comando_base = comando.split()[0] if comando.split() else ''
    
    if comando_base in comandos_permitidos:
        return jsonify(ejecutar_comando(comando))
    else:
        comandos_peligrosos = ['rm -rf', 'mkfs', 'dd', '> /dev/sda']
        if any(peligroso in comando for peligroso in comandos_peligrosos):
            return jsonify({'success': False, 'output': '⚠️ Comando no permitido por seguridad', 'code': -1})
        return jsonify(ejecutar_comando(comando))

@app.route('/api/ejecutar_script', methods=['POST'])
@login_requerido
def api_ejecutar_script():
    data = request.get_json()
    script_nombre = data.get('script', '')
    
    scripts_dir = os.path.join(os.path.dirname(__file__), 'scripts')
    script_path = os.path.join(scripts_dir, script_nombre)
    
    if os.path.exists(script_path) and script_nombre.endswith(('.sh', '.py')):
        if script_nombre.endswith('.sh'):
            comando = f'bash {script_path}'
        else:
            comando = f'python3 {script_path}'
        
        return jsonify(ejecutar_comando(comando, timeout=60))
    
    return jsonify({'success': False, 'output': f'Script no encontrado: {script_nombre}', 'code': -1})

@app.route('/api/crear_script', methods=['POST'])
@login_requerido
def api_crear_script():
    data = request.get_json()
    nombre = data.get('nombre', '')
    contenido = data.get('contenido', '')
    
    if not nombre or not contenido:
        return jsonify({'success': False, 'output': 'Nombre y contenido requeridos'})
    
    if not nombre.endswith('.sh'):
        nombre += '.sh'
    
    scripts_dir = os.path.join(os.path.dirname(__file__), 'scripts')
    os.makedirs(scripts_dir, exist_ok=True)
    
    script_path = os.path.join(scripts_dir, nombre)
    
    try:
        with open(script_path, 'w') as f:
            f.write(contenido)
        os.chmod(script_path, 0o755)
        return jsonify({'success': True, 'output': f'Script {nombre} creado correctamente'})
    except Exception as e:
        return jsonify({'success': False, 'output': str(e)})

@app.route('/api/servicios')
@login_requerido
def api_servicios():
    try:
        resultado = subprocess.run(
            'systemctl list-units --type=service --all --no-pager --no-legend | head -30',
            shell=True,
            capture_output=True,
            text=True,
            timeout=10
        )
        servicios = []
        for line in resultado.stdout.split('\n'):
            if line.strip():
                partes = line.split()
                if len(partes) >= 4:
                    servicios.append({
                        'nombre': partes[0],
                        'estado': partes[3],
                        'descripcion': ' '.join(partes[4:]) if len(partes) > 4 else ''
                    })
        return jsonify(servicios)
    except Exception as e:
        print(f"Error cargando servicios: {e}")
        return jsonify([])

@app.route('/api/control_servicio', methods=['POST'])
@login_requerido
def api_control_servicio():
    data = request.get_json()
    servicio = data.get('servicio')
    accion = data.get('accion')
    
    if servicio and accion in ['start', 'stop', 'restart']:
        return jsonify(ejecutar_comando(f'sudo systemctl {accion} {servicio} 2>&1'))
    return jsonify({'success': False, 'output': 'Acción no válida'})

@app.route('/api/matar_proceso', methods=['POST'])
@login_requerido
def api_matar_proceso():
    data = request.get_json()
    pid = data.get('pid')
    
    try:
        os.kill(int(pid), signal.SIGTERM)
        return jsonify({'success': True, 'output': f'Proceso {pid} terminado'})
    except Exception as e:
        return jsonify({'success': False, 'output': str(e)})

if __name__ == '__main__':
    # Crear directorio de scripts
    scripts_dir = os.path.join(os.path.dirname(__file__), 'scripts')
    os.makedirs(scripts_dir, exist_ok=True)
    
    # Crear scripts de ejemplo
    ejemplo_script = os.path.join(scripts_dir, 'ejemplo.sh')
    if not os.path.exists(ejemplo_script):
        with open(ejemplo_script, 'w') as f:
            f.write('#!/bin/bash\necho "=== Panel Myxsi ===="\necho "Fecha: $(date)"\necho "Uptime: $(uptime)"\necho "Memoria: $(free -h)"\necho "Disco: $(df -h /)"\n')
        os.chmod(ejemplo_script, 0o755)
    
    print("✅ Panel Myxsi iniciado correctamente")
    print("📱 Accede desde tu móvil en: http://[IP-DE-TU-DEBIAN]:5000")
    print("🔐 Inicia sesión con tu usuario y contraseña del sistema")
    print("   - Puedes usar: root, tu usuario personal, etc.")
    print("   - Los administradores son usuarios en grupo sudo/wheel")
    
    app.run(host='0.0.0.0', port=5000, debug=False)
