#!/bin/bash

# Script para ejecutar servidor con permisos de RoboMano
# mientras mantiene MPI como usuario normal

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m'

echo -e "${COLOR_BLUE}=== SERVIDOR CON ROBOMANO ===${COLOR_NC}"
echo ""

# Verificar si robomano existe
if [ -e "/dev/robomano" ]; then
    echo -e "${COLOR_GREEN}✓ Dispositivo RoboMano encontrado${COLOR_NC}"

    # Verificar permisos actuales
    if [ -r "/dev/robomano" ] && [ -w "/dev/robomano" ]; then
        echo -e "${COLOR_GREEN}✓ Permisos de RoboMano correctos${COLOR_NC}"
        echo ""
        echo "Ejecutando servidor normal..."
        ./server
    else
        echo -e "${COLOR_YELLOW}⚠️  Permisos insuficientes para RoboMano${COLOR_NC}"
        echo ""
        echo "Soluciones:"
        echo "1. Ejecutar con sudo SOLO para este script:"
        echo "   sudo ./run_with_robomano.sh"
        echo ""
        echo "2. O agregar tu usuario al grupo correcto:"
        device_group=$(stat -c %G /dev/robomano 2>/dev/null)
        echo "   sudo usermod -a -G $device_group $(whoami)"
        echo "   newgrp $device_group"
        echo ""
        echo "3. O cambiar permisos temporalmente:"
        echo "   sudo chmod 666 /dev/robomano"
        echo ""

        # Si ejecutamos con sudo, configurar entorno para MPI
        if [ "$EUID" -eq 0 ]; then
            echo -e "${COLOR_YELLOW}Ejecutando como root - configurando MPI...${COLOR_NC}"
            export OMPI_ALLOW_RUN_AS_ROOT=1
            export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
            echo ""
            echo "Ejecutando servidor con permisos especiales..."
            ./server
        else
            echo ""
            echo "Ejecutando servidor (RoboMano no funcionará)..."
            ./server
        fi
    fi
else
    echo -e "${COLOR_RED}✗ Dispositivo RoboMano no encontrado${COLOR_NC}"
    echo ""
    echo "El servidor funcionará normalmente pero sin escritura física."
    echo ""
    ./server
fi
