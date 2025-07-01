# Makefile para el proyecto RoboticTEC - SIN BIBLIOTECA.C
CC = gcc
MPICC = mpicc
AR = ar
CFLAGS = -Wall -Wextra -g -O2
LDFLAGS =

# Directorios
SRCDIR = .
OBJDIR = obj
BINDIR = bin
LIBDIR = lib

# Archivos fuente
ROBOMANO_SRC = robomano.c
SERVIDOR_SRC = server.c
CLIENTE_SRC = client.c
NODO_SRC = nodo.c

# Archivos objeto
ROBOMANO_OBJ = $(OBJDIR)/robomano.o
SERVIDOR_OBJ = $(OBJDIR)/server.o
CLIENTE_OBJ = $(OBJDIR)/client.o
NODO_OBJ = $(OBJDIR)/nodo.o

# Ejecutables y bibliotecas
SERVIDOR_BIN = $(BINDIR)/server
CLIENTE_BIN = $(BINDIR)/client
NODO_BIN = $(BINDIR)/nodo
ROBOMANO_LIB = librobomano.a

# Regla por defecto - incluye demo
all: directories $(ROBOMANO_LIB) $(SERVIDOR_BIN) $(CLIENTE_BIN) $(NODO_BIN) $(DEMO_BIN)
	@echo "Compilación completada exitosamente!"
	@echo "Ejecutables disponibles:"
	@echo "  - Servidor: $(SERVIDOR_BIN)"
	@echo "  - Cliente:  $(CLIENTE_BIN)"
	@echo "  - Nodo MPI: $(NODO_BIN)"
	@echo "Bibliotecas disponibles:"
	@echo "  - Biblioteca RoboMano: $(ROBOMANO_LIB)"

# Crear directorios necesarios
directories:
	@mkdir -p $(OBJDIR) $(BINDIR) $(LIBDIR) archivos

# =====================================
# BIBLIOTECAS ROBOMANO
# =====================================

# Biblioteca RoboMano independiente (estilo original)
librobomano.a: robomano.o
	$(AR) rcs $@ $^

robomano.o: robomano.c robomano.h
	$(CC) -c -O2 -Wall $<

# =====================================
# EJECUTABLES PRINCIPALES
# =====================================

# Compilar servidor (con robomano incluido)
$(SERVIDOR_BIN): $(SERVIDOR_OBJ) $(ROBOMANO_OBJ)
	@echo "Compilando servidor..."
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

# Compilar cliente
$(CLIENTE_BIN): $(CLIENTE_OBJ)
	@echo "Compilando cliente..."
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

# Compilar nodo MPI
$(NODO_BIN): $(NODO_OBJ)
	@echo "Compilando nodo MPI..."
	$(MPICC) $(CFLAGS) -o $@ $< $(LDFLAGS)

# Demo RoboMano (estilo original)
demo: demo.c librobomano.a
	$(CC) demo.c -L. -lrobomano -o demo

# Demo en directorio bin
$(DEMO_BIN): $(DEMO_SRC) $(ROBOMANO_LIB)
	@echo "Compilando demo RoboMano..."
	$(CC) $(CFLAGS) $< -L. -lrobomano -o $@ $(LDFLAGS)

# =====================================
# OBJETOS INDIVIDUALES
# =====================================

$(OBJDIR)/robomano.o: $(ROBOMANO_SRC) robomano.h
	@echo "Compilando robomano.c..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/server.o: $(SERVIDOR_SRC) robomano.h
	@echo "Compilando server.c..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/client.o: $(CLIENTE_SRC)
	@echo "Compilando client.c..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/nodo.o: $(NODO_SRC)
	@echo "Compilando nodo.c..."
	$(MPICC) $(CFLAGS) -c $< -o $@

# =====================================
# INSTALACIÓN
# =====================================

# Instalar (copiar ejecutables al directorio actual)
install: all
	@echo "Instalando ejecutables..."
	@cp $(SERVIDOR_BIN) ./server
	@cp $(CLIENTE_BIN) ./client
	@cp $(NODO_BIN) ./nodo
	@cp $(DEMO_BIN) ./demo 2>/dev/null || cp demo ./demo 2>/dev/null || echo "Demo no disponible"
	@chmod +x ./server ./client ./nodo ./demo 2>/dev/null || true
	@echo "Ejecutables instalados en el directorio actual."

# =====================================
# LIMPIEZA
# =====================================

# Limpiar archivos generados
clean:
	@echo "Limpiando archivos generados..."
	@rm -rf $(OBJDIR) $(BINDIR) $(LIBDIR)
	@rm -f server client nodo demo
	@rm -f *.o librobomano.a
	@rm -f archivos/archivo_cifrado.txt archivos/archivo_descifrado.txt
	@echo "Limpieza completada."

# Limpiar todo incluyendo directorios
distclean: clean
	@rm -rf archivos
	@echo "Limpieza completa realizada."

# =====================================
# UTILIDADES
# =====================================

# Verificar dependencias
test-deps:
	@echo "Verificando dependencias..."
	@which gcc > /dev/null || (echo "ERROR: gcc no encontrado" && exit 1)
	@which mpicc > /dev/null || (echo "ERROR: mpicc no encontrado. Instalar OpenMPI" && exit 1)
	@which mpirun > /dev/null || (echo "ERROR: mpirun no encontrado. Instalar OpenMPI" && exit 1)
	@which ar > /dev/null || (echo "ERROR: ar no encontrado" && exit 1)
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
	$(CC) $(CFLAGS) -c robomano.c -o obj/robomano.o || echo "robomano.c no disponible"
	$(CC) -c -O2 -Wall robomano.c || echo "robomano.o no disponible"
	$(AR) rcs librobomano.a robomano.o 2>/dev/null || echo "librobomano.a no creado"
	$(CC) $(CFLAGS) -c server.c -o obj/server.o
	$(CC) $(CFLAGS) -c client.c -o obj/client.o
	$(MPICC) $(CFLAGS) -c nodo.c -o obj/nodo.o
	$(CC) $(CFLAGS) -o bin/server obj/server.o obj/robomano.o
	$(CC) $(CFLAGS) -o bin/client obj/client.o
	$(MPICC) $(CFLAGS) -o bin/nodo obj/nodo.o
	$(CC) demo.c -L. -lrobomano -o bin/demo 2>/dev/null || echo "Demo no compilado"
	cp bin/* . 2>/dev/null || true
	chmod +x server client nodo demo 2>/dev/null || true
	@echo "Compilación de emergencia completada."

# =====================================
# TARGETS ESPECÍFICOS DE ROBOMANO
# =====================================

# Solo RoboMano
robomano-only: librobomano.a server.c
	@echo "Componentes RoboMano compilados:"
	@echo "  - librobomano.a"
	@echo "  - server"

# Instalar solo RoboMano
install-robomano: robomano-only
	@cp server ./server 2>/dev/null || echo "Demo no disponible"
	@chmod +x ./server 2>/dev/null || true
	@echo "RoboMano instalado."

# =====================================
# AYUDA Y DOCUMENTACIÓN
# =====================================

# Mostrar ayuda
help:
	@echo "Makefile para el proyecto RoboticTEC - Sin biblioteca.c"
	@echo ""
	@echo "Objetivos principales:"
	@echo "  all            - Compilar todo el proyecto (incluye demo)"
	@echo "  install        - Compilar e instalar ejecutables"
	@echo "  clean          - Limpiar archivos generados"
	@echo "  distclean      - Limpieza completa"
	@echo ""
	@echo "Objetivos de RoboMano:"
	@echo "  librobomano.a  - Compilar solo biblioteca RoboMano"
	@echo "  demo           - Compilar solo demo RoboMano (estilo original)"
	@echo "  robomano-only  - Compilar solo componentes RoboMano"
	@echo "  install-robomano - Instalar solo RoboMano"
	@echo ""
	@echo "Objetivos de prueba:"
	@echo "  test-deps      - Verificar dependencias"
	@echo "  test-quick     - Prueba rápida del sistema"
	@echo "  test-demo      - Probar demo RoboMano"
	@echo ""
	@echo "Objetivos de utilidad:"
	@echo "  emergency      - Compilación manual de emergencia"
	@echo "  help           - Mostrar esta ayuda"
	@echo ""
	@echo "Ejemplos de uso:"
	@echo "  make                    # Compilar todo"
	@echo "  make demo               # Solo demo RoboMano"
	@echo "  make librobomano.a      # Solo biblioteca RoboMano"
	@echo "  make install            # Compilar e instalar todo"
	@echo "  make test-demo          # Probar demo"

# Mostrar información del proyecto
info:
	@echo "=== INFORMACIÓN DEL PROYECTO ==="
	@echo "Proyecto: RoboticTEC"
	@echo "Componentes:"
	@echo "  - Servidor de archivos con MPI"
	@echo "  - Cliente de envío de archivos"
	@echo "  - Procesamiento distribuido (3 nodos MPI)"
	@echo "  - Integración con hardware RoboMano"
	@echo "  - Demo independiente de RoboMano"
	@echo ""
	@echo "Bibliotecas:"
	@echo "  - librobomano.a: Solo RoboMano"
	@echo ""
	@echo "Archivos fuente:"
	@ls -la *.c *.h 2>/dev/null || echo "  (archivos fuente no encontrados)"

.PHONY: all directories install clean distclean test-deps test-quick test-demo emergency robomano-only install-robomano help info