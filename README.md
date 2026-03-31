<div align="center">
  
  <img src="https://img.shields.io/badge/Python-3.9+-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/Flask-2.3+-000000?style=for-the-badge&logo=flask&logoColor=white" alt="Flask">
  <img src="https://img.shields.io/badge/Debian-12+-A81D33?style=for-the-badge&logo=debian&logoColor=white" alt="Debian">
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License">
  
  <br>
  <br>
  
  <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&size=28&pause=1000&color=06FFA5&center=true&vCenter=true&width=500&lines=Myxsi+Panel;Control+total+de+tu+servidor;Terminal+REAL+Linux;+Asistente+de+Voz" alt="Typing SVG" />
  
  <br>
  
  <h1>🚀 Myxsi Panel</h1>
  <h3>Myxsi panel desarrollado para Debian con Terminal REAL y Asistente de Voz y Ciberseguridad</h3>
  
  <p>
    <strong>Control total de tu servidor desde cualquier dispositivo móvil o navegador</strong>
  </p>
  
  <br>
  
  <img src="https://img.shields.io/github/stars/yourusername/myxsi?style=social" alt="Stars">
  <img src="https://img.shields.io/github/forks/yourusername/myxsi?style=social" alt="Forks">
  <img src="https://img.shields.io/github/issues/yourusername/myxsi" alt="Issues">
  <img src="https://img.shields.io/github/last-commit/yourusername/myxsi" alt="Last Commit">
  
</div>

---

## 📋 Índice

- [🌟 Características](#-características)
- [🎯 ¿Qué es Myxsi?](#-qué-es-myxsi)
- [🖼️ Capturas de Pantalla](#️-capturas-de-pantalla)
- [🚀 Instalación Rápida](#-instalación-rápida)
- [💻 Funcionalidades](#-funcionalidades)
- [🎤 Asistente de Voz](#-asistente-de-voz-en-desarrollo)
- [🔧 Comandos Útiles](#-comandos-útiles)
- [📁 Estructura del Proyecto](#-estructura-del-proyecto)
- [🛡️ Seguridad](#️-seguridad)
- [🤝 Contribuciones](#-contribuciones)
- [📄 Licencia](#-licencia)

---

## 🌟 Características

<div align="center">
  
| Característica | Estado | Descripción |
|----------------|--------|-------------|
| 🔐 **Autenticación PAM** | ✅ Completo | Usa las credenciales del sistema Linux |
| 💻 **Terminal REAL** | 🚧 En desarrollo | Terminal Linux completa con xterm.js + WebSocket |
| 📁 **Gestor de Archivos** | ✅ Completo | Navega, sube y organiza tus archivos |
| 📸 **Immich Integration** | 🚧 En desarrollo | Google Photos alternativo auto-alojado |
| 🎤 **Asistente de Voz Myxsi** | 🚧 En desarrollo | Control por voz del panel |
| 📊 **Panel de control Myxsi** | 🚧 En desarrollo | CPU, RAM, Disco, Procesos, Servicios y configuracion |
| 📱 **Responsive Design** | ✅ Completo | Funciona perfecto la conexion de móviles |

</div>

---

## 🎯 ¿Qué es Myxsi?

**Myxsi Panel** es un sistema de administración para servidores Debian que te permite:

- 🖥️ **Controlar tu servidor desde cualquier lugar de tu red local** a través de una interfaz web moderna
- 💻 **Acceder a una terminal REAL de Linux** desde tu navegador (bash/zsh completa)
- 📸 **Gestionar tus fotos** con Immich, la alternativa open-source a Google Photos
- 📁 **Navegar por el sistema de archivos** y subir/descargar archivos
- 🎤 **Usar comandos de voz** para controlar el panel (próximamente)

**Perfecto para:** Administradores de sistemas, entusiastas del self-hosting, equipos de desarrollo, y cualquiera que quiera control remoto de su servidor Linux.

---

## 🖼️ Capturas de Pantalla

<div align="center">
  <table>
    <tr>
      <td align="center"><strong>📊 Dashboard Principal</strong></td>
      <td align="center"><strong>💻 Terminal REAL</strong></td>
    </tr>
    <tr>
      <td><img src="https://via.placeholder.com/400x250/0f172a/06ffa5?text=Dashboard+Myxsi" alt="Dashboard"></td>
      <td><img src="https://via.placeholder.com/400x250/0f172a/06ffa5?text=Terminal+REAL" alt="Terminal"></td>
    </tr>
    <tr>
      <td align="center"><strong>📁 Gestor de Archivos</strong></td>
      <td align="center"><strong>📸 Immich Gallery</strong></td>
    </tr>
    <tr>
      <td><img src="https://via.placeholder.com/400x250/0f172a/06ffa5?text=File+Manager" alt="File Manager"></td>
      <td><img src="https://via.placeholder.com/400x250/0f172a/06ffa5?text=Immich" alt="Immich"></td>
    </tr>
  </table>
</div>

---

## 🚀 Instalación Rápida

### Sistema permitido
- Debian 12+ / Kali Linux / Orange pi Zero 3
- Python 3.9+
- Conexión a internet
- Usuario con permisos sudo

### Instalación Automática (Recomendada)

```bash
# Clonar el repositorio
git clone https://github.com/yourusername/myxsi.git
cd myxsi

# Dar permisos al instalador
chmod +x install.sh

# Ejecutar instalación
./install.sh
