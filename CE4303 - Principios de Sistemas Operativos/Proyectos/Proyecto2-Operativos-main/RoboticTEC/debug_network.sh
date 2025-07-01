#!/bin/bash

# Script de diagnóstico para problemas de transmisión de archivos grandes
# RoboticTEC - Proyecto de Sistemas Operativos

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m' # No Color

echo -e "${COLOR_BLUE}=== DIAGNÓSTICO DEL SISTEMA RoboticTEC ===${COLOR_NC}"
echo ""

# 1. Verificar dependencias del sistema
echo -e "${COLOR_YELLOW}1. Verificando dependencias...${COLOR_NC}"
echo "Verificando compiladores:"
if command -v gcc &> /dev/null; then
    echo -e "  ✓ gcc: $(gcc --version | head -n1)"
else
    echo -e "  ${COLOR_RED}✗ gcc no encontrado${COLOR_NC}"
fi

if command -v mpicc &> /dev/null; then
    echo -e "  ✓ mpicc: $(mpicc --version | head -n1)"
else
    echo -e "  ${COLOR_RED}✗ mpicc no encontrado (instalar: sudo apt install libopenmpi-dev)${COLOR_NC}"
fi

if command -v mpirun &> /dev/null; then
    echo -e "  ✓ mpirun: $(mpirun --version | head -n1)"
else
    echo -e "  ${COLOR_RED}✗ mpirun no encontrado${COLOR_NC}"
fi
echo ""

# 2. Verificar configuración de red
echo -e "${COLOR_YELLOW}2. Verificando configuración de red...${COLOR_NC}"
echo "Puertos disponibles:"
if command -v netstat &> /dev/null; then
    if netstat -tuln | grep -q ":8080"; then
        echo -e "  ${COLOR_RED}✗ Puerto 8080 ya está en uso${COLOR_NC}"
        echo "    Procesos usando el puerto:"
        netstat -tulnp | grep ":8080"
    else
        echo -e "  ✓ Puerto 8080 disponible"
    fi
else
    echo "  netstat no disponible, instalarlo con: sudo apt install net-tools"
fi

echo "Configuración de loopback:"
if ping -c 1 127.0.0.1 &> /dev/null; then
    echo -e "  ✓ Loopback (127.0.0.1) funcional"
else
    echo -e "  ${COLOR_RED}✗ Problema con loopback${COLOR_NC}"
fi
echo ""

# 3. Verificar límites del sistema
echo -e "${COLOR_YELLOW}3. Verificando límites del sistema...${COLOR_NC}"
echo "Límites de archivos y memoria:"
echo "  Tamaño máximo de archivo: $(ulimit -f) bloques"
echo "  Memoria virtual máxima: $(ulimit -v) KB"
echo "  Archivos abiertos máximos: $(ulimit -n)"
echo "  Tamaño de stack: $(ulimit -s) KB"

# Verificar espacio en disco
echo "Espacio en disco disponible:"
df -h . | tail -n 1 | awk '{print "  Disponible: " $4 " de " $2 " (" $5 " usado)"}'
echo ""

# 4. Probar la compilación
echo -e "${COLOR_YELLOW}4. Probando compilación...${COLOR_NC}"
if [ -f "Makefile" ]; then
    echo "Ejecutando make test-deps:"
    if make test-deps &> /dev/null; then
        echo -e "  ✓ Dependencias de compilación OK"
    else
        echo -e "  ${COLOR_RED}✗ Problemas con dependencias${COLOR_NC}"
    fi
    
    echo "Intentando compilación:"
    if make clean &> /dev/null && make all &> /dev/null; then
        echo -e "  ✓ Compilación exitosa"
    else
        echo -e "  ${COLOR_RED}✗ Error en compilación${COLOR_NC}"
        echo "    Ejecutar 'make all' para ver detalles"
    fi
else
    echo -e "  ${COLOR_RED}✗ Makefile no encontrado${COLOR_NC}"
fi
echo ""

# 5. Crear archivo de prueba de diferentes tamaños
echo -e "${COLOR_YELLOW}5. Creando archivos de prueba...${COLOR_NC}"
create_test_file() {
    local size=$1
    local filename=$2
    local unit=$3
    
    echo "Creando archivo de prueba de $size$unit..."
    if [ "$unit" == "KB" ]; then
        dd if=/dev/urandom of="$filename" bs=1024 count=$size &> /dev/null
    elif [ "$unit" == "MB" ]; then
        dd if=/dev/urandom of="$filename" bs=1048576 count=$size &> /dev/null
    fi
    
    if [ -f "$filename" ]; then
        local actual_size=$(stat -c%s "$filename")
        echo -e "  ✓ $filename creado ($(($actual_size / 1024)) KB)"
    else
        echo -e "  ${COLOR_RED}✗ Error creando $filename${COLOR_NC}"
    fi
}

create_test_file 1 "test_small.txt" "KB"
create_test_file 100 "test_medium.txt" "KB" 
create_test_file 1 "test_large.txt" "MB"

# 6. Función para probar transmisión
test_transmission() {
    local test_file=$1
    local file_size=$(stat -c%s "$test_file" 2>/dev/null || echo "0")
    
    echo ""
    echo -e "${COLOR_YELLOW}6. Probando transmisión con $test_file ($(($file_size / 1024)) KB)...${COLOR_NC}"
    
    if [ ! -f "./server" ] || [ ! -f "./client" ]; then
        echo -e "  ${COLOR_RED}✗ Ejecutables no encontrados. Compilar primero con 'make install'${COLOR_NC}"
        return 1
    fi
    
    # Limpiar archivos previos
    rm -f archivos/archivo_cifrado.txt archivos/archivo_descifrado.txt
    
    # Iniciar servidor en background
    echo "  Iniciando servidor..."
    timeout 30 ./server &
    local server_pid=$!
    sleep 2
    
    # Verificar que el servidor esté corriendo
    if ! kill -0 $server_pid 2>/dev/null; then
        echo -e "  ${COLOR_RED}✗ El servidor no se inició correctamente${COLOR_NC}"
        return 1
    fi
    
    # Ejecutar cliente
    echo "  Enviando archivo..."
    if timeout 25 ./client "$test_file" 127.0.0.1; then
        echo -e "  ✓ Cliente ejecutado exitosamente"
        
        # Verificar que el archivo se recibió
        sleep 2
        if [ -f "archivos/archivo_cifrado.txt" ]; then
            local received_size=$(stat -c%s "archivos/archivo_cifrado.txt")
            echo -e "  ✓ Archivo recibido: $(($received_size / 1024)) KB"
            
            if [ "$received_size" -eq "$file_size" ]; then
                echo -e "  ${COLOR_GREEN}✓ Tamaño correcto - transmisión exitosa${COLOR_NC}"
            else
                echo -e "  ${COLOR_RED}✗ Tamaño incorrecto - transmisión incompleta${COLOR_NC}"
                echo "    Enviado: $(($file_size / 1024)) KB, Recibido: $(($received_size / 1024)) KB"
            fi
        else
            echo -e "  ${COLOR_RED}✗ Archivo no recibido${COLOR_NC}"
        fi
    else
        echo -e "  ${COLOR_RED}✗ Error en cliente o timeout${COLOR_NC}"
    fi
    
    # Limpiar proceso del servidor
    kill $server_pid 2>/dev/null || true
    wait $server_pid 2>/dev/null || true
}

# Ejecutar pruebas solo si los ejecutables existen
if [ -f "./server" ] && [ -f "./client" ]; then
    test_transmission "test_small.txt"
    test_transmission "test_medium.txt" 
    test_transmission "test_large.txt"
else
    echo ""
    echo -e "${COLOR_YELLOW}6. Pruebas de transmisión omitidas${COLOR_NC}"
    echo "   Compilar primero con: make install"
fi

# 7. Recomendaciones
echo ""
echo -e "${COLOR_BLUE}=== RECOMENDACIONES ===${COLOR_NC}"
echo "Para problemas con archivos grandes:"
echo "  1. Verificar espacio suficiente en disco"
echo "  2. Aumentar timeouts si la red es lenta"
echo "  3. Verificar que no hay firewall bloqueando el puerto 8080"
echo "  4. Probar con archivos pequeños primero"
echo "  5. Verificar logs del sistema: dmesg | tail"
echo ""
echo "Para compilación:"
echo "  make clean && make install"
echo ""
echo "Para ejecutar:"
echo "  Terminal 1: ./server"
echo "  Terminal 2: ./client archivo.txt 127.0.0.1"

# Limpiar archivos de prueba
echo ""
echo "Limpiando archivos de prueba..."
rm -f test_small.txt test_medium.txt test_large.txt

echo -e "${COLOR_GREEN}Diagnóstico completado.${COLOR_NC}"
