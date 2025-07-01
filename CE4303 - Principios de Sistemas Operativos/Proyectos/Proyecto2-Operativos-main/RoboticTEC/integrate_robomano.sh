#!/bin/bash

# Script para compilar correctamente y crear ejecutables
# RoboticTEC - Proyecto de Sistemas Operativos

set -e

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m'

echo -e "${COLOR_BLUE}=== DIAGNÓSTICO Y COMPILACIÓN ===${COLOR_NC}"
echo ""

# Función para verificar estado actual
verificar_estado() {
    echo -e "${COLOR_YELLOW}🔍 Verificando estado actual...${COLOR_NC}"
    echo ""

    echo "Archivos fuente:"
    for file in server.c client.c nodo.c biblioteca.c biblioteca.h; do
        if [ -f "$file" ]; then
            echo "   ✓ $file"
        else
            echo "   ✗ $file (faltante)"
        fi
    done

    echo ""
    echo "Ejecutables en directorio actual:"
    for exec in server client nodo; do
        if [ -x "./$exec" ]; then
            echo "   ✓ ./$exec"
        else
            echo "   ✗ ./$exec (faltante)"
        fi
    done

    echo ""
    echo "Ejecutables en bin/:"
    if [ -d "bin" ]; then
        for exec in server client nodo; do
            if [ -x "bin/$exec" ]; then
                echo "   ✓ bin/$exec"
            else
                echo "   ✗ bin/$exec (faltante)"
            fi
        done
    else
        echo "   ✗ Directorio bin/ no existe"
    fi

    echo ""
}

# Función para actualizar Makefile con robomano
actualizar_makefile() {
    echo -e "${COLOR_YELLOW}🔧 Actualizando Makefile para incluir robomano...${COLOR_NC}"

    # Backup del Makefile
    timestamp=$(date +%Y%m%d_%H%M%S)
    cp Makefile "Makefile.backup_${timestamp}"

    # Crear Makefile actualizado con robomano
    cat > Makefile << 'EOF'
# Makefile para el proyecto RoboticTEC - VERSION CON ROBOMANO
CC = gcc
MPICC = mpicc
CFLAGS = -Wall -Wextra -g -O2
LDFLAGS =

# Directorios
SRCDIR = .
OBJDIR = obj
BINDIR = bin
LIBDIR = lib

# Archivos fuente
BIBLIOTECA_SRC = biblioteca.c
ROBOMANO_SRC = robomano.c
SERVIDOR_SRC = server.c
CLIENTE_SRC = client.c
NODO_SRC = nodo.c

# Archivos objeto
BIBLIOTECA_OBJ = $(OBJDIR)/biblioteca.o
ROBOMANO_OBJ = $(OBJDIR)/robomano.o
SERVIDOR_OBJ = $(OBJDIR)/server.o
CLIENTE_OBJ = $(OBJDIR)/client.o
NODO_OBJ = $(OBJDIR)/nodo.o

# Ejecutables
SERVIDOR_BIN = $(BINDIR)/server
CLIENTE_BIN = $(BINDIR)/client
NODO_BIN = $(BINDIR)/nodo
BIBLIOTECA_LIB = $(LIBDIR)/libmano.a

# Regla por defecto
all: directories $(BIBLIOTECA_LIB) $(SERVIDOR_BIN) $(CLIENTE_BIN) $(NODO_BIN)
	@echo "Compilación completada exitosamente!"
	@echo "Ejecutables disponibles:"
	@echo "  - Servidor: $(SERVIDOR_BIN)"
	@echo "  - Cliente:  $(CLIENTE_BIN)"
	@echo "  - Nodo MPI: $(NODO_BIN)"
	@echo "  - Biblioteca: $(BIBLIOTECA_LIB)"

# Crear directorios necesarios
directories:
	@mkdir -p $(OBJDIR) $(BINDIR) $(LIBDIR) archivos

# Compilar biblioteca estática (incluye robomano)
$(BIBLIOTECA_LIB): $(BIBLIOTECA_OBJ) $(ROBOMANO_OBJ)
	@echo "Creando biblioteca estática con robomano..."
	@ar rcs $@ $^
	@echo "Biblioteca creada: $@"

# Compilar servidor (con biblioteca que incluye robomano)
$(SERVIDOR_BIN): $(SERVIDOR_OBJ) $(BIBLIOTECA_LIB)
	@echo "Compilando servidor..."
	$(CC) $(CFLAGS) -o $@ $< -L$(LIBDIR) -lmano $(LDFLAGS)

# Compilar cliente
$(CLIENTE_BIN): $(CLIENTE_OBJ)
	@echo "Compilando cliente..."
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

# Compilar nodo MPI
$(NODO_BIN): $(NODO_OBJ)
	@echo "Compilando nodo MPI..."
	$(MPICC) $(CFLAGS) -o $@ $< $(LDFLAGS)

# Reglas para objetos individuales
$(OBJDIR)/biblioteca.o: $(BIBLIOTECA_SRC) biblioteca.h
	@echo "Compilando biblioteca.c..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/robomano.o: $(ROBOMANO_SRC) robomano.h
	@echo "Compilando robomano.c..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/server.o: $(SERVIDOR_SRC) biblioteca.h robomano.h
	@echo "Compilando server.c..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/client.o: $(CLIENTE_SRC)
	@echo "Compilando client.c..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/nodo.o: $(NODO_SRC)
	@echo "Compilando nodo.c..."
	$(MPICC) $(CFLAGS) -c $< -o $@

# Instalar (copiar ejecutables al directorio actual para facilitar uso)
install: all
	@echo "Instalando ejecutables..."
	@cp $(SERVIDOR_BIN) ./server
	@cp $(CLIENTE_BIN) ./client
	@cp $(NODO_BIN) ./nodo
	@chmod +x ./server ./client ./nodo
	@echo "Ejecutables instalados en el directorio actual."

# Limpiar archivos generados
clean:
	@echo "Limpiando archivos generados..."
	@rm -rf $(OBJDIR) $(BINDIR) $(LIBDIR)
	@rm -f server client nodo
	@rm -f *.o
	@rm -f archivos/archivo_cifrado.txt archivos/archivo_descifrado.txt
	@echo "Limpieza completada."

# Limpiar todo incluyendo directorios
distclean: clean
	@rm -rf archivos
	@echo "Limpieza completa realizada."

# Verificar dependencias
test-deps:
	@echo "Verificando dependencias..."
	@which gcc > /dev/null || (echo "ERROR: gcc no encontrado" && exit 1)
	@which mpicc > /dev/null || (echo "ERROR: mpicc no encontrado. Instalar OpenMPI" && exit 1)
	@which mpirun > /dev/null || (echo "ERROR: mpirun no encontrado. Instalar OpenMPI" && exit 1)
	@echo "Todas las dependencias están disponibles."

# Prueba rápida del sistema
test-quick: install
	@echo "=== PRUEBA RÁPIDA DEL SISTEMA ==="
	@echo "Creando archivo de prueba..."
	@echo "esta es una prueba prueba del sistema sistema sistema" > test.txt
	@echo "Iniciando servidor en background..."
	@timeout 10 ./server &
	@sleep 1
	@echo "Enviando archivo..."
	@timeout 5 ./client test.txt 127.0.0.1 || true
	@sleep 1
	@killall server 2>/dev/null || true
	@rm -f test.txt archivo_cifrado.txt
	@echo "Prueba rápida completada."

# Compilación de emergencia (manual)
emergency: clean
	@echo "=== COMPILACIÓN DE EMERGENCIA ==="
	@mkdir -p obj bin lib archivos
	@echo "Compilando manualmente..."
	$(CC) $(CFLAGS) -c biblioteca.c -o obj/biblioteca.o
	$(CC) $(CFLAGS) -c robomano.c -o obj/robomano.o || echo "robomano.c no disponible"
	ar rcs lib/libmano.a obj/biblioteca.o obj/robomano.o 2>/dev/null || ar rcs lib/libmano.a obj/biblioteca.o
	$(CC) $(CFLAGS) -c server.c -o obj/server.o
	$(CC) $(CFLAGS) -c client.c -o obj/client.o
	$(MPICC) $(CFLAGS) -c nodo.c -o obj/nodo.o
	$(CC) $(CFLAGS) -o bin/server obj/server.o -Llib -lmano
	$(CC) $(CFLAGS) -o bin/client obj/client.o
	$(MPICC) $(CFLAGS) -o bin/nodo obj/nodo.o
	cp bin/* .
	chmod +x server client nodo
	@echo "Compilación de emergencia completada."

# Mostrar ayuda
help:
	@echo "Makefile para el proyecto RoboticTEC"
	@echo ""
	@echo "Objetivos disponibles:"
	@echo "  all        - Compilar todo el proyecto"
	@echo "  install    - Compilar e instalar ejecutables"
	@echo "  clean      - Limpiar archivos generados"
	@echo "  distclean  - Limpieza completa"
	@echo "  test-deps  - Verificar dependencias"
	@echo "  test-quick - Ejecutar prueba del sistema"
	@echo "  emergency  - Compilación manual de emergencia"
	@echo "  help       - Mostrar esta ayuda"

.PHONY: all directories install clean distclean test-deps test-quick emergency help
EOF

    echo -e "${COLOR_GREEN}✓ Makefile actualizado${COLOR_NC}"
}

# Función para crear robomano.c si no existe
crear_robomano_si_falta() {
    if [ ! -f "robomano.c" ]; then
        echo -e "${COLOR_YELLOW}📝 Creando robomano.c...${COLOR_NC}"

        cat > robomano.c << 'EOF'
#include "robomano.h"
#include <stdio.h>
#include <unistd.h>
#include <string.h>

int robomano_init() {
    printf("[RoboMano] Inicializando hardware...\n");
    // Simular inicialización del hardware
    usleep(500000); // 0.5 segundos
    printf("[RoboMano] Hardware inicializado correctamente\n");
    return 0; // 0 = éxito, != 0 = error
}

void robomano_write_word(const char *word) {
    if (!word) {
        printf("[RoboMano] Error: palabra nula\n");
        return;
    }

    printf("[RoboMano] Escribiendo palabra: '%s'\n", word);

    // Simular escritura letra por letra
    int len = strlen(word);
    for (int i = 0; i < len; i++) {
        printf("[RoboMano] Escribiendo letra %d/%d: '%c'\n", i+1, len, word[i]);
        usleep(800000); // 0.8 segundos por letra
    }

    printf("[RoboMano] Palabra '%s' escrita completamente\n", word);
}

void robomano_close() {
    printf("[RoboMano] Cerrando conexión con hardware...\n");
    usleep(200000); // 0.2 segundos
    printf("[RoboMano] Hardware desconectado\n");
}
EOF

        echo -e "${COLOR_GREEN}✓ robomano.c creado${COLOR_NC}"
    fi

    if [ ! -f "robomano.h" ]; then
        echo -e "${COLOR_YELLOW}📝 Creando robomano.h...${COLOR_NC}"

        cat > robomano.h << 'EOF'
#ifndef ROBOMANO_H
#define ROBOMANO_H

/**
 * Inicializa el hardware RoboMano
 * @return 0 si es exitoso, != 0 si hay error
 */
int robomano_init(void);

/**
 * Escribe una palabra usando el hardware RoboMano
 * @param word La palabra a escribir
 */
void robomano_write_word(const char *word);

/**
 * Cierra la conexión con el hardware RoboMano
 */
void robomano_close(void);

#endif /* ROBOMANO_H */
EOF

        echo -e "${COLOR_GREEN}✓ robomano.h creado${COLOR_NC}"
    fi
}

# Ejecutar diagnóstico inicial
verificar_estado

# Crear archivos faltantes
crear_robomano_si_falta

# Actualizar Makefile
actualizar_makefile

# Verificar dependencias
echo -e "${COLOR_YELLOW}🔧 Verificando dependencias...${COLOR_NC}"
if ! make test-deps; then
    echo -e "${COLOR_RED}✗ Dependencias faltantes${COLOR_NC}"
    echo "Instala las dependencias necesarias:"
    echo "  sudo apt update"
    echo "  sudo apt install build-essential libopenmpi-dev"
    exit 1
fi

# Intentar compilación normal
echo -e "${COLOR_YELLOW}🔨 Compilando proyecto...${COLOR_NC}"
if make clean && make install; then
    echo -e "${COLOR_GREEN}✓ Compilación exitosa${COLOR_NC}"
else
    echo -e "${COLOR_YELLOW}⚠️ Compilación normal falló, intentando compilación de emergencia...${COLOR_NC}"
    if make emergency; then
        echo -e "${COLOR_GREEN}✓ Compilación de emergencia exitosa${COLOR_NC}"
    else
        echo -e "${COLOR_RED}✗ Ambas compilaciones fallaron${COLOR_NC}"
        echo ""
        echo "Compilación manual paso a paso:"
        echo "  mkdir -p obj bin lib archivos"
        echo "  gcc -Wall -Wextra -g -O2 -c biblioteca.c -o obj/biblioteca.o"
        echo "  gcc -Wall -Wextra -g -O2 -c robomano.c -o obj/robomano.o"
        echo "  gcc -Wall -Wextra -g -O2 -c server.c -o obj/server.o"
        echo "  gcc -Wall -Wextra -g -O2 -c client.c -o obj/client.o"
        echo "  mpicc -Wall -Wextra -g -O2 -c nodo.c -o obj/nodo.o"
        echo "  ar rcs lib/libmano.a obj/biblioteca.o obj/robomano.o"
        echo "  gcc -Wall -Wextra -g -O2 -o server obj/server.o -Llib -lmano"
        echo "  gcc -Wall -Wextra -g -O2 -o client obj/client.o"
        echo "  mpicc -Wall -Wextra -g -O2 -o nodo obj/nodo.o"
        exit 1
    fi
fi

# Verificar que los ejecutables se crearon
echo ""
echo -e "${COLOR_YELLOW}✅ Verificando ejecutables creados...${COLOR_NC}"
all_good=true
for exec in server client nodo; do
    if [ -x "./$exec" ]; then
        size=$(ls -lh "./$exec" | awk '{print $5}')
        echo "   ✓ ./$exec ($size)"
    else
        echo "   ✗ ./$exec (faltante)"
        all_good=false
    fi
done

if [ "$all_good" = true ]; then
    echo ""
    echo -e "${COLOR_GREEN}🎉 ¡COMPILACIÓN EXITOSA!${COLOR_NC}"
    echo ""
    echo "Ejecutables disponibles:"
    echo "   ./server  - Servidor principal"
    echo "   ./client  - Cliente para envío de archivos"
    echo "   ./nodo    - Procesador MPI distribuido"
    echo ""
    echo "Para probar:"
    echo -e "${COLOR_BLUE}   Terminal 1:${COLOR_NC} ./server"
    echo -e "${COLOR_BLUE}   Terminal 2:${COLOR_NC} ./client archivos/el_quijote.txt 127.0.0.1"
    echo ""

    # Probar que el cliente funciona
    if [ -f "archivos/el_quijote.txt" ]; then
        echo -e "${COLOR_GREEN}✓ Archivo el_quijote.txt encontrado${COLOR_NC}"
    else
        echo -e "${COLOR_YELLOW}⚠️  archivos/el_quijote.txt no encontrado${COLOR_NC}"
        echo "Puedes probar con cualquier archivo de texto:"
        echo "   ./client MI_ARCHIVO.txt 127.0.0.1"
    fi
else
    echo -e "${COLOR_RED}✗ Algunos ejecutables no se crearon correctamente${COLOR_NC}"
    exit 1
fi

echo ""
echo -e "${COLOR_BLUE}¿Ejecutar una prueba rápida del sistema? (y/n)${COLOR_NC}"
read -r response
if [[ "$response" == "y" || "$response" == "Y" ]]; then
    make test-quick
fi