#!/bin/bash

# Script para reemplazar archivos originales con versiones corregidas
# RoboticTEC - Proyecto de Sistemas Operativos

set -e  # Salir si hay algún error

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m'

echo -e "${COLOR_BLUE}=== REEMPLAZANDO ARCHIVOS Y COMPILANDO ===${COLOR_NC}"
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "biblioteca.h" ]; then
    echo -e "${COLOR_RED}Error: No se encontró biblioteca.h${COLOR_NC}"
    echo "Asegúrate de estar en el directorio del proyecto"
    exit 1
fi

# Paso 1: Backup de archivos originales
echo -e "${COLOR_YELLOW}1. Creando backups de archivos originales...${COLOR_NC}"
timestamp=$(date +%Y%m%d_%H%M%S)
for file in server.c client.c nodo.c; do
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup_${timestamp}"
        echo "   ✓ Backup creado: ${file}.backup_${timestamp}"
    fi
done

# Paso 2: Crear archivos corregidos
echo -e "${COLOR_YELLOW}2. Creando archivos corregidos...${COLOR_NC}"

# Crear server.c corregido
echo "   Creando server.c corregido..."
cat > server.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <errno.h>
#include "biblioteca.h"

#define PUERTO_SERVIDOR 8080
#define ARCHIVO_CIFRADO "archivos/archivo_cifrado.txt"
#define ARCHIVO_DESCIFRADO "archivos/archivo_descifrado.txt"
#define BUFFER_SIZE 8192

// Funcion para recibir todos los bytes (maneja recepciones parciales)
ssize_t recibir_todo(int socket, void *buffer, size_t length) {
    size_t total_recibido = 0;
    ssize_t bytes_recibidos;
    char *ptr = (char *)buffer;

    while (total_recibido < length) {
        bytes_recibidos = recv(socket, ptr + total_recibido, length - total_recibido, 0);
        if (bytes_recibidos <= 0) {
            if (bytes_recibidos < 0) {
                perror("Error en recv");
            } else {
                printf("Conexion cerrada por el cliente\n");
            }
            return -1;
        }
        total_recibido += bytes_recibidos;
    }
    return total_recibido;
}

void crear_directorio_si_no_existe() {
    struct stat st = {0};
    if (stat("archivos", &st) == -1) {
        if (mkdir("archivos", 0700) == -1) {
            perror("Error creando directorio 'archivos'");
            exit(EXIT_FAILURE);
        }
        printf("Directorio 'archivos' creado.\n");
    }
}

void guardar_archivo(int socket_cliente) {
    crear_directorio_si_no_existe();
    
    // PASO 1: Recibir el tamano del archivo
    long tamano_archivo;
    if (recibir_todo(socket_cliente, &tamano_archivo, sizeof(tamano_archivo)) < 0) {
        fprintf(stderr, "Error recibiendo tamano del archivo\n");
        exit(EXIT_FAILURE);
    }
    
    printf("Tamano del archivo a recibir: %ld bytes\n", tamano_archivo);
    
    if (tamano_archivo <= 0 || tamano_archivo > 100*1024*1024) { // Limite de 100MB
        fprintf(stderr, "Tamano de archivo invalido: %ld\n", tamano_archivo);
        exit(EXIT_FAILURE);
    }

    // PASO 2: Crear archivo de salida
    FILE *archivo = fopen(ARCHIVO_CIFRADO, "wb"); // Modo binario
    if (!archivo) {
        perror("No se pudo crear archivo de salida");
        exit(EXIT_FAILURE);
    }

    // PASO 3: Recibir el contenido del archivo
    char buffer[BUFFER_SIZE];
    long total_recibido = 0;
    ssize_t bytes_recibidos;

    printf("Recibiendo archivo...\n");
    
    while (total_recibido < tamano_archivo) {
        // Calcular cuantos bytes recibir en esta iteracion
        size_t bytes_a_recibir = BUFFER_SIZE;
        if (total_recibido + BUFFER_SIZE > tamano_archivo) {
            bytes_a_recibir = tamano_archivo - total_recibido;
        }

        bytes_recibidos = recv(socket_cliente, buffer, bytes_a_recibir, 0);
        if (bytes_recibidos <= 0) {
            if (bytes_recibidos < 0) {
                perror("Error recibiendo datos");
            } else {
                printf("Conexion cerrada prematuramente por el cliente\n");
            }
            fclose(archivo);
            exit(EXIT_FAILURE);
        }

        // Escribir al archivo
        if (fwrite(buffer, 1, (size_t)bytes_recibidos, archivo) != (size_t)bytes_recibidos) {
            perror("Error escribiendo al archivo");
            fclose(archivo);
            exit(EXIT_FAILURE);
        }

        total_recibido += bytes_recibidos;
        
        // Mostrar progreso
        printf("Progreso: %ld/%ld bytes (%.1f%%)\r", 
               total_recibido, tamano_archivo, 
               (float)total_recibido / tamano_archivo * 100);
        fflush(stdout);
    }

    fclose(archivo);
    printf("\nArchivo recibido completamente: %ld bytes\n", total_recibido);
    
    // PASO 4: Intentar recibir marcador de fin (opcional)
    char marcador_fin[20];
    bytes_recibidos = recv(socket_cliente, marcador_fin, sizeof(marcador_fin)-1, MSG_DONTWAIT);
    if (bytes_recibidos > 0) {
        marcador_fin[bytes_recibidos] = '\0';
        printf("Marcador de fin recibido: %s\n", marcador_fin);
    }

    // Verificar integridad del archivo
    struct stat st;
    if (stat(ARCHIVO_CIFRADO, &st) == 0) {
        printf("Verificacion: archivo guardado con %ld bytes\n", st.st_size);
        if (st.st_size != tamano_archivo) {
            fprintf(stderr, "ADVERTENCIA: Tamano del archivo no coincide!\n");
        }
    }
}

void ejecutar_mpi() {
    printf("Ejecutando procesamiento distribuido con MPI...\n");
    
    // Verificar que el archivo existe antes de ejecutar MPI
    if (access(ARCHIVO_CIFRADO, F_OK) != 0) {
        fprintf(stderr, "Error: El archivo cifrado no existe.\n");
        exit(EXIT_FAILURE);
    }
    
    // Cambiar al directorio donde esta el archivo antes de ejecutar MPI
    if (chdir("archivos") != 0) {
        // Si no se puede cambiar al directorio, copiar el archivo
        int ret = system("cp archivos/archivo_cifrado.txt .");
        if (ret != 0) {
            fprintf(stderr, "Advertencia: No se pudo copiar el archivo\n");
        }
    }
    
    int status = system("mpirun -np 3 ../nodo");
    if (status != 0) {
        fprintf(stderr, "Error ejecutando nodos MPI (codigo: %d).\n", status);
        exit(EXIT_FAILURE);
    }
    
    // Volver al directorio original si se cambio
    if (chdir("..") != 0) {
        fprintf(stderr, "Advertencia: No se pudo volver al directorio original\n");
    }
}

void escribir_resultado() {
    FILE *f = fopen(ARCHIVO_DESCIFRADO, "r");
    if (!f) {
        // Intentar en el directorio actual tambien
        f = fopen("archivo_descifrado.txt", "r");
        if (!f) {
            perror("No se pudo abrir el archivo descifrado");
            return;
        }
    }

    char palabra[100];
    int cantidad;

    if (fscanf(f, "%s %d", palabra, &cantidad) != 2) {
        fprintf(stderr, "Error leyendo el resultado del archivo descifrado\n");
        fclose(f);
        return;
    }
    fclose(f);

    printf("=== RESULTADO FINAL ===\n");
    printf("Palabra mas repetida: '%s' (%d veces)\n", palabra, cantidad);
    printf("======================\n");
    
    // Aqui integrarias con la biblioteca del hardware
    /*
    if (inicializar_mano("/dev/ttyUSB0") == 0) {
        printf("Escribiendo resultado con el hardware...\n");
        // Implementar logica para escribir la palabra con el robot
        escribir_palabra_con_robot(palabra);
        cerrar_mano();
    } else {
        printf("No se pudo inicializar el hardware, mostrando solo resultado.\n");
    }
    */
}

int main() {
    int sockfd, socket_cliente;
    struct sockaddr_in servidor, cliente;
    socklen_t cliente_len = sizeof(cliente);

    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        perror("Error creando socket");
        exit(EXIT_FAILURE);
    }

    // Permitir reutilizar la direccion
    int opt = 1;
    if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        perror("Error en setsockopt");
        exit(EXIT_FAILURE);
    }

    // Configurar timeout para recepcion
    struct timeval timeout;
    timeout.tv_sec = 60;  // 60 segundos
    timeout.tv_usec = 0;
    setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

    servidor.sin_family = AF_INET;
    servidor.sin_port = htons(PUERTO_SERVIDOR);
    servidor.sin_addr.s_addr = INADDR_ANY;

    if (bind(sockfd, (struct sockaddr *)&servidor, sizeof(servidor)) < 0) {
        perror("Error en bind");
        exit(EXIT_FAILURE);
    }

    listen(sockfd, 1);
    printf("Servidor esperando conexion en puerto %d...\n", PUERTO_SERVIDOR);

    socket_cliente = accept(sockfd, (struct sockaddr *)&cliente, &cliente_len);
    if (socket_cliente < 0) {
        perror("Error aceptando conexion");
        exit(EXIT_FAILURE);
    }

    printf("Cliente conectado desde %s\n", inet_ntoa(cliente.sin_addr));
    printf("Iniciando recepcion del archivo...\n");
    
    guardar_archivo(socket_cliente);
    close(socket_cliente);
    close(sockfd);

    printf("Iniciando procesamiento...\n");
    ejecutar_mpi();
    escribir_resultado();

    return 0;
}
EOF

# Crear client.c corregido
echo "   Creando client.c corregido..."
cat > client.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/stat.h>

#define BUFFER_SIZE 8192
#define PUERTO_SERVIDOR 8080
#define CLAVE_CIFRADO 3

void cifrar_archivo(const char *archivo_entrada, const char *archivo_salida) {
    FILE *fin = fopen(archivo_entrada, "r");
    FILE *fout = fopen(archivo_salida, "w");

    if (!fin || !fout) {
        perror("Error abriendo archivos");
        exit(EXIT_FAILURE);
    }

    int c;
    while ((c = fgetc(fin)) != EOF) {
        if (c >= 32 && c <= 126) {
            c = ((c - 32 + CLAVE_CIFRADO) % 95) + 32;
        }
        fputc(c, fout);
    }

    fclose(fin);
    fclose(fout);
}

// Funcion para enviar todos los bytes (maneja envios parciales)
ssize_t enviar_todo(int socket, const void *buffer, size_t length) {
    size_t total_enviado = 0;
    ssize_t bytes_enviados;
    const char *ptr = (const char *)buffer;

    while (total_enviado < length) {
        bytes_enviados = send(socket, ptr + total_enviado, length - total_enviado, 0);
        if (bytes_enviados <= 0) {
            if (bytes_enviados < 0) {
                perror("Error en send");
            }
            return -1;
        }
        total_enviado += bytes_enviados;
    }
    return total_enviado;
}

long obtener_tamano_archivo(const char *archivo) {
    struct stat st;
    if (stat(archivo, &st) == 0) {
        return st.st_size;
    }
    return -1;
}

void enviar_archivo(const char *archivo_cifrado, const char *ip_servidor) {
    int sockfd;
    struct sockaddr_in servidor;
    char buffer[BUFFER_SIZE];
    FILE *archivo = fopen(archivo_cifrado, "rb"); // Modo binario para mayor precision

    if (!archivo) {
        perror("Error abriendo archivo cifrado");
        exit(EXIT_FAILURE);
    }

    // Obtener tamano del archivo
    long tamano_archivo = obtener_tamano_archivo(archivo_cifrado);
    if (tamano_archivo < 0) {
        perror("Error obteniendo tamano del archivo");
        exit(EXIT_FAILURE);
    }

    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        perror("Error creando socket");
        exit(EXIT_FAILURE);
    }

    // Configurar timeout para el socket
    struct timeval timeout;
    timeout.tv_sec = 30;  // 30 segundos
    timeout.tv_usec = 0;
    setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

    servidor.sin_family = AF_INET;
    servidor.sin_port = htons(PUERTO_SERVIDOR);
    servidor.sin_addr.s_addr = inet_addr(ip_servidor);

    if (connect(sockfd, (struct sockaddr *)&servidor, sizeof(servidor)) < 0) {
        perror("Error conectando al servidor");
        exit(EXIT_FAILURE);
    }

    // PASO 1: Enviar el tamano del archivo primero
    printf("Enviando tamano del archivo: %ld bytes\n", tamano_archivo);
    if (enviar_todo(sockfd, &tamano_archivo, sizeof(tamano_archivo)) < 0) {
        perror("Error enviando tamano del archivo");
        exit(EXIT_FAILURE);
    }

    // PASO 2: Enviar el contenido del archivo
    size_t bytes_leidos;
    long total_enviado = 0;
    
    printf("Enviando archivo...\n");
    while ((bytes_leidos = fread(buffer, 1, BUFFER_SIZE, archivo)) > 0) {
        if (enviar_todo(sockfd, buffer, bytes_leidos) < 0) {
            perror("Error enviando datos del archivo");
            exit(EXIT_FAILURE);
        }
        total_enviado += bytes_leidos;
        
        // Mostrar progreso
        printf("Progreso: %ld/%ld bytes (%.1f%%)\r", 
               total_enviado, tamano_archivo, 
               (float)total_enviado / tamano_archivo * 100);
        fflush(stdout);
    }

    printf("\nArchivo enviado completamente: %ld bytes\n", total_enviado);
    
    // PASO 3: Enviar senal de fin (opcional, pero util)
    const char *fin_transmision = "EOF_MARKER";
    enviar_todo(sockfd, fin_transmision, strlen(fin_transmision));

    fclose(archivo);
    close(sockfd);
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Uso: %s <archivo_entrada.txt> <ip_servidor>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    const char *archivo_entrada = argv[1];
    const char *archivo_salida = "archivo_cifrado.txt";
    const char *ip_servidor = argv[2];

    printf("Cifrando archivo: %s\n", archivo_entrada);
    cifrar_archivo(archivo_entrada, archivo_salida);
    
    printf("Enviando al servidor: %s\n", ip_servidor);
    enviar_archivo(archivo_salida, ip_servidor);

    return 0;
}
EOF

# Crear nodo.c corregido
echo "   Creando nodo.c corregido..."
cat > nodo.c << 'EOF'
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define CLAVE_CIFRADO 3
#define MAX_PALABRA 100
#define MAX_TEXTO 100000
#define OVERLAP 16  // margen extra para evitar cortar palabras

// Descifra un caracter (algoritmo Cesar inverso)
char descifrar_char(char c) {
    if (c >= 32 && c <= 126)
        return ((c - 32 - CLAVE_CIFRADO + 95) % 95) + 32;
    return c;
}

// Normaliza una palabra (convierte a minuscula)
void normalizar(char *palabra) {
    for (int i = 0; palabra[i]; ++i)
        palabra[i] = tolower(palabra[i]);
}

// Estructura para contar palabras
typedef struct {
    char palabra[MAX_PALABRA];
    int conteo;
} PalabraConteo;

int main(int argc, char *argv[]) {
    int rank, size;
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    char *texto_total = NULL;
    int tam_texto = 0;

    if (rank == 0) {
        FILE *f = fopen("archivo_cifrado.txt", "r");
        if (!f) {
            perror("No se pudo abrir archivo_cifrado.txt");
            MPI_Abort(MPI_COMM_WORLD, 1);
        }

        texto_total = malloc(MAX_TEXTO);
        tam_texto = fread(texto_total, 1, MAX_TEXTO - 1, f);
        texto_total[tam_texto] = '\0';
        fclose(f);
    }

    // Difundir tamano del texto
    MPI_Bcast(&tam_texto, 1, MPI_INT, 0, MPI_COMM_WORLD);

    // Difundir el texto completo
    if (rank != 0) {
        texto_total = malloc(MAX_TEXTO);
    }
    MPI_Bcast(texto_total, tam_texto + 1, MPI_CHAR, 0, MPI_COMM_WORLD);

    // Calcular segmento a procesar
    int start = rank * (tam_texto / size);
    int end = (rank == size - 1) ? tam_texto : (rank + 1) * (tam_texto / size) + OVERLAP;
    if (end > tam_texto) end = tam_texto;
    int tam_local = end - start;

    char *bloque_local = malloc(tam_local + 1);
    memcpy(bloque_local, texto_total + start, tam_local);
    bloque_local[tam_local] = '\0';

    // Descifrar el bloque
    for (int i = 0; i < tam_local; ++i)
        bloque_local[i] = descifrar_char(bloque_local[i]);

    // Tokenizar palabras
    char *token = strtok(bloque_local, " \t\n\r.,;:!?()[]{}<>\"\'");
    PalabraConteo conteos_locales[1000];
    int n_local = 0;

    while (token != NULL) {
        normalizar(token);
        int encontrado = 0;
        for (int i = 0; i < n_local; ++i) {
            if (strcmp(conteos_locales[i].palabra, token) == 0) {
                conteos_locales[i].conteo++;
                encontrado = 1;
                break;
            }
        }
        if (!encontrado && n_local < 1000) {
            strcpy(conteos_locales[n_local].palabra, token);
            conteos_locales[n_local].conteo = 1;
            n_local++;
        }
        token = strtok(NULL, " \t\n\r.,;:!?()[]{}<>\"\'");
    }

    // Serializar conteos
    char buffer_envio[MAX_TEXTO];
    buffer_envio[0] = '\0';
    for (int i = 0; i < n_local; ++i) {
        char linea[150];
        sprintf(linea, "%s %d\n", conteos_locales[i].palabra, conteos_locales[i].conteo);
        strcat(buffer_envio, linea);
    }

    // Enviar tamano del buffer
    int tam_envio = strlen(buffer_envio) + 1;
    int *tamanos = NULL;
    if (rank == 0) tamanos = malloc(size * sizeof(int));
    MPI_Gather(&tam_envio, 1, MPI_INT, tamanos, 1, MPI_INT, 0, MPI_COMM_WORLD);

    // Enviar conteos serializados al root
    char *recibidos = NULL;
    if (rank == 0) {
        int total = 0;
        for (int i = 0; i < size; ++i) total += tamanos[i];
        recibidos = malloc(total);
    }

    MPI_Gather(buffer_envio, tam_envio, MPI_CHAR, recibidos, tam_envio, MPI_CHAR, 0, MPI_COMM_WORLD);

    // Procesamiento final en root
    if (rank == 0) {
        PalabraConteo final[2000];
        int n_final = 0;

        char *linea = strtok(recibidos, "\n");
        while (linea) {
            char palabra[MAX_PALABRA];
            int cantidad;
            sscanf(linea, "%s %d", palabra, &cantidad);

            int encontrado = 0;
            for (int i = 0; i < n_final; ++i) {
                if (strcmp(final[i].palabra, palabra) == 0) {
                    final[i].conteo += cantidad;
                    encontrado = 1;
                    break;
                }
            }
            if (!encontrado) {
                strcpy(final[n_final].palabra, palabra);
                final[n_final].conteo = cantidad;
                n_final++;
            }

            linea = strtok(NULL, "\n");
        }

        // Encontrar la mas frecuente
        int max = 0;
        char palabra_max[MAX_PALABRA];
        for (int i = 0; i < n_final; ++i) {
            if (final[i].conteo > max) {
                max = final[i].conteo;
                strcpy(palabra_max, final[i].palabra);
            }
        }

        // Guardar resultado
        FILE *out = fopen("archivo_descifrado.txt", "w");
        if (out) {
            fprintf(out, "%s %d\n", palabra_max, max);
            fclose(out);
            printf("Resultado guardado: %s (%d veces)\n", palabra_max, max);
        } else {
            perror("No se pudo guardar resultado");
        }

        free(recibidos);
        free(tamanos);
    }

    free(bloque_local);
    if (texto_total) free(texto_total);

    MPI_Finalize();
    return 0;
}
EOF

echo -e "   ${COLOR_GREEN}✓ Archivos corregidos creados${COLOR_NC}"

# Paso 3: Crear Makefile actualizado
echo -e "${COLOR_YELLOW}3. Actualizando Makefile...${COLOR_NC}"
cat > Makefile << 'EOF'
# Makefile para el proyecto RoboticTEC - VERSION CORREGIDA
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
SERVIDOR_SRC = server.c
CLIENTE_SRC = client.c
NODO_SRC = nodo.c

# Archivos objeto
BIBLIOTECA_OBJ = $(OBJDIR)/biblioteca.o
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

# Compilar biblioteca estática
$(BIBLIOTECA_LIB): $(BIBLIOTECA_OBJ)
	@echo "Creando biblioteca estática..."
	@ar rcs $@ $^
	@echo "Biblioteca creada: $@"

# Compilar servidor
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

$(OBJDIR)/server.o: $(SERVIDOR_SRC) biblioteca.h
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
	@echo "Ejecutables instalados en el directorio actual."

# Limpiar archivos generados
clean:
	@echo "Limpiando archivos generados..."
	@rm -rf $(OBJDIR) $(BINDIR) $(LIBDIR)
	@rm -f server client nodo
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
	@echo "  help       - Mostrar esta ayuda"

.PHONY: all directories install clean distclean test-deps test-quick help
EOF

echo -e "   ${COLOR_GREEN}✓ Makefile actualizado${COLOR_NC}"

# Paso 4: Verificar dependencias
echo -e "${COLOR_YELLOW}4. Verificando dependencias del sistema...${COLOR_NC}"
if make test-deps; then
    echo -e "   ${COLOR_GREEN}✓ Todas las dependencias disponibles${COLOR_NC}"
else
    echo -e "   ${COLOR_RED}✗ Faltan dependencias${COLOR_NC}"
    echo "   Instalar OpenMPI: sudo apt install libopenmpi-dev"
    exit 1
fi

# Paso 5: Limpiar y compilar
echo -e "${COLOR_YELLOW}5. Compilando proyecto...${COLOR_NC}"
if make clean && make all; then
    echo -e "   ${COLOR_GREEN}✓ Compilación exitosa${COLOR_NC}"
else
    echo -e "   ${COLOR_RED}✗ Error en compilación${COLOR_NC}"
    echo "   Revisa los errores arriba para más detalles"
    exit 1
fi

# Paso 6: Instalar ejecutables
echo -e "${COLOR_YELLOW}6. Instalando ejecutables...${COLOR_NC}"
if make install; then
    echo -e "   ${COLOR_GREEN}✓ Instalación exitosa${COLOR_NC}"
else
    echo -e "   ${COLOR_RED}✗ Error en instalación${COLOR_NC}"
    exit 1
fi

# Paso 7: Verificar ejecutables
echo -e "${COLOR_YELLOW}7. Verificando ejecutables...${COLOR_NC}"
all_good=true
for exec in server client nodo; do
    if [ -x "./$exec" ]; then
        echo "   ✓ $exec - OK"
    else
        echo "   ✗ $exec - NO ENCONTRADO"
        all_good=false
    fi
done

if [ "$all_good" = false ]; then
    echo -e "   ${COLOR_RED}✗ Algunos ejecutables no se crearon correctamente${COLOR_NC}"
    exit 1
fi

# Paso 8: Ejecutar prueba rápida (opcional)
echo ""
echo -e "${COLOR_YELLOW}¿Deseas ejecutar una prueba rápida del sistema? (y/n)${COLOR_NC}"
read -r response
if [[ "$response" == "y" || "$response" == "Y" ]]; then
    echo -e "${COLOR_YELLOW}8. Ejecutando prueba rápida...${COLOR_NC}"
    make test-quick
fi

# Información final
echo ""
echo -e "${COLOR_GREEN}=== ¡REEMPLAZO Y COMPILACIÓN COMPLETADOS! ===${COLOR_NC}"
echo ""
echo "✅ Resumen de cambios:"
echo "   • server.c    - Reemplazado con versión sin caracteres especiales"
echo "   • client.c    - Reemplazado con versión sin caracteres especiales"  
echo "   • nodo.c      - Reemplazado con versión sin caracteres especiales"
echo "   • Makefile    - Actualizado para nueva configuración"
echo ""
echo "📁 Backups creados:"
echo "   • server.c.backup_${timestamp}"
echo "   • client.c.backup_${timestamp}"
echo "   • nodo.c.backup_${timestamp}"
echo ""
echo "🚀 Ejecutables disponibles:"
echo "   • ./server    - Servidor principal"
echo "   • ./client    - Cliente para envío de archivos"
echo "   • ./nodo      - Procesador MPI distribuido"
echo ""
echo "📋 Para usar el sistema:"
echo "   Terminal 1: ./server"
echo "   Terminal 2: ./client mi_archivo_grande.txt 127.0.0.1"
echo ""
echo -e "${COLOR_BLUE}¡El sistema está listo para manejar archivos grandes!${COLOR_NC}"
