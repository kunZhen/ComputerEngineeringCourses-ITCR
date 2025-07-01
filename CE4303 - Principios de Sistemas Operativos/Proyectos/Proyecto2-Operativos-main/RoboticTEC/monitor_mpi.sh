#!/bin/bash

# Script para monitorear la ejecución de nodos MPI en tiempo real
# RoboticTEC - Proyecto de Sistemas Operativos

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_NC='\033[0m'

echo -e "${COLOR_BLUE}=== MONITOR DE NODOS MPI ===${COLOR_NC}"
echo ""

# Función para mostrar procesos MPI activos
mostrar_procesos_mpi() {
    echo -e "${COLOR_YELLOW}🔍 Procesos MPI activos:${COLOR_NC}"
    
    # Buscar procesos relacionados con MPI
    if pgrep -f "mpirun" >/dev/null; then
        echo -e "${COLOR_GREEN}✓ MPI Master ejecutándose:${COLOR_NC}"
        ps aux | grep -E "(mpirun|orterun)" | grep -v grep | while read line; do
            echo "   $line"
        done
        echo ""
        
        echo -e "${COLOR_GREEN}✓ Nodos trabajadores:${COLOR_NC}"
        ps aux | grep -E "./nodo" | grep -v grep | while read line; do
            pid=$(echo "$line" | awk '{print $2}')
            echo "   PID: $pid - $line"
        done
        echo ""
        
        # Contar procesos
        total_nodos=$(pgrep -f "./nodo" | wc -l)
        echo -e "${COLOR_CYAN}📊 Total de nodos activos: $total_nodos${COLOR_NC}"
        
    else
        echo -e "${COLOR_RED}✗ No hay procesos MPI ejecutándose${COLOR_NC}"
    fi
}

# Función para mostrar configuración actual
mostrar_configuracion() {
    echo -e "${COLOR_YELLOW}⚙️ Configuración actual:${COLOR_NC}"
    
    # Verificar el comando mpirun en server.c
    if [ -f "server.c" ]; then
        nodos_config=$(grep -o "mpirun -np [0-9]*" server.c | head -1)
        if [ -n "$nodos_config" ]; then
            echo "   Configurado en server.c: $nodos_config"
        else
            echo "   No se encontró configuración en server.c"
        fi
    fi
    
    # Verificar versión de MPI
    echo "   Versión MPI instalada:"
    if command -v mpirun >/dev/null 2>&1; then
        mpirun --version | head -1 | sed 's/^/      /'
    else
        echo "      MPI no instalado"
    fi
    
    # Verificar número de CPUs disponibles
    cpus=$(nproc)
    echo "   CPUs disponibles en el sistema: $cpus"
    
    echo ""
}

# Función para probar diferentes números de nodos
probar_configuracion() {
    local num_nodos=$1
    echo -e "${COLOR_YELLOW}🧪 Probando con $num_nodos nodos...${COLOR_NC}"
    
    # Crear archivo de prueba temporal
    echo "Esta es una prueba con $num_nodos nodos. El sistema debe distribuir el procesamiento entre los nodos disponibles." > test_temp.txt
    
    # Crear versión temporal del nodo con más output
    cp nodo.c nodo_verbose.c
    
    # Compilar versión verbose
    mpicc -Wall -Wextra -g -O2 -o nodo_verbose nodo_verbose.c
    
    if [ -x "./nodo_verbose" ]; then
        echo "Ejecutando: mpirun -np $num_nodos ./nodo_verbose"
        echo "Creando archivo_cifrado.txt temporal..."
        
        # Cifrar archivo de prueba
        cat test_temp.txt | sed 's/./\x0/g' > archivo_cifrado.txt
        
        echo "Ejecutando MPI con $num_nodos nodos:"
        timeout 10 mpirun -np $num_nodos ./nodo_verbose
        
        # Limpiar
        rm -f test_temp.txt archivo_cifrado.txt nodo_verbose.c nodo_verbose
        echo ""
    else
        echo "Error: No se pudo compilar versión de prueba"
    fi
}

# Función para mostrar distribución de trabajo
explicar_distribucion() {
    echo -e "${COLOR_YELLOW}📊 Cómo se distribuye el trabajo entre nodos:${COLOR_NC}"
    echo ""
    echo "Para un archivo de ejemplo de 1,000,000 bytes con 3 nodos:"
    echo ""
    echo -e "${COLOR_CYAN}   Nodo 0 (Rank 0):${COLOR_NC} Procesa bytes    0 -  333,365"
    echo -e "${COLOR_CYAN}   Nodo 1 (Rank 1):${COLOR_NC} Procesa bytes  333,333 -  666,698"  
    echo -e "${COLOR_CYAN}   Nodo 2 (Rank 2):${COLOR_NC} Procesa bytes  666,666 - 1,000,000"
    echo ""
    echo "Cada nodo:"
    echo "  1. 🔓 Descifra su segmento del archivo"
    echo "  2. 🔤 Tokeniza las palabras en su segmento"
    echo "  3. 📊 Cuenta la frecuencia de cada palabra"
    echo "  4. 📤 Envía sus resultados al nodo maestro (Rank 0)"
    echo "  5. 🏆 El nodo maestro consolida y encuentra la palabra más frecuente"
    echo ""
}

# Función principal de monitoreo en tiempo real
monitoreo_tiempo_real() {
    echo -e "${COLOR_YELLOW}📡 Iniciando monitoreo en tiempo real...${COLOR_NC}"
    echo "Presiona Ctrl+C para salir"
    echo ""
    
    while true; do
        clear
        echo -e "${COLOR_BLUE}=== MONITOR MPI EN TIEMPO REAL ===${COLOR_NC}"
        echo "$(date)"
        echo ""
        
        mostrar_procesos_mpi
        
        # Mostrar uso de CPU y memoria
        echo -e "${COLOR_YELLOW}💻 Uso de recursos:${COLOR_NC}"
        if pgrep -f "./nodo" >/dev/null; then
            echo "   Procesos nodo:"
            ps aux | grep "./nodo" | grep -v grep | awk '{printf "      PID %s: CPU %s%% MEM %s%%\n", $2, $3, $4}'
        fi
        
        if pgrep -f "mpirun" >/dev/null; then
            echo "   Proceso mpirun:"
            ps aux | grep "mpirun" | grep -v grep | awk '{printf "      PID %s: CPU %s%% MEM %s%%\n", $2, $3, $4}'
        fi
        
        echo ""
        echo "Monitoreando... (actualización cada 2 segundos)"
        sleep 2
    done
}

# Menú principal
echo -e "${COLOR_YELLOW}Selecciona una opción:${COLOR_NC}"
echo "1. Ver estado actual de nodos MPI"
echo "2. Ver configuración del sistema"
echo "3. Explicar distribución de trabajo"
echo "4. Monitoreo en tiempo real"
echo "5. Cambiar número de nodos"
echo "6. Ejecutar todas las verificaciones"
echo ""
echo -n "Opción (1-6): "
read -r opcion

case $opcion in
    1)
        mostrar_procesos_mpi
        ;;
    2)
        mostrar_configuracion
        ;;
    3)
        explicar_distribucion
        ;;
    4)
        monitoreo_tiempo_real
        ;;
    5)
        echo ""
        echo -e "${COLOR_YELLOW}¿Cuántos nodos quieres usar? (1-8): ${COLOR_NC}"
        read -r num_nodos
        
        if [[ "$num_nodos" =~ ^[1-8]$ ]]; then
            echo "Modificando server.c para usar $num_nodos nodos..."
            
            # Backup del server.c actual
            cp server.c server.c.backup_nodos
            
            # Cambiar el número de nodos
            sed -i "s/mpirun -np [0-9]*/mpirun -np $num_nodos/g" server.c
            
            echo "Recompilando servidor..."
            if gcc -Wall -Wextra -g -O2 -c server.c -o server.o && gcc -Wall -Wextra -g -O2 -o server server.o -Llib -lmano; then
                echo -e "${COLOR_GREEN}✓ Servidor recompilado para usar $num_nodos nodos${COLOR_NC}"
                echo "Nuevo comando MPI:"
                grep "mpirun -np" server.c
            else
                echo -e "${COLOR_RED}✗ Error recompilando servidor${COLOR_NC}"
                mv server.c.backup_nodos server.c
            fi
        else
            echo "Número inválido. Debe ser entre 1 y 8."
        fi
        ;;
    6)
        mostrar_configuracion
        echo ""
        mostrar_procesos_mpi
        echo ""
        explicar_distribucion
        ;;
    *)
        echo "Opción inválida"
        ;;
esac

echo ""
