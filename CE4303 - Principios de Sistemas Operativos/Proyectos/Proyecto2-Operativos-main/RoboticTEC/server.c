#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <errno.h>
#include "biblioteca.h"
#include "robomano.h"

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

    int status = system("mpirun --allow-run-as-root -np 3 ../nodo");
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

    // INTEGRACION CON ROBOMANO
    printf("Iniciando escritura con RoboMano...\n");

    if (robomano_init()) {
        fprintf(stderr, "Error: No se pudo inicializar RoboMano\n");
        printf("Continuando sin hardware...\n");
        return;
    }

    printf("RoboMano inicializado correctamente.\n");
    printf("Escribiendo la palabra: '%s'\n", palabra);

    // Escribir la palabra encontrada (no hardcodeada)
    robomano_write_word(palabra);

    printf("Escritura completada. Cerrando RoboMano...\n");
    robomano_close();

    printf("=== ESCRITURA CON ROBOMANO COMPLETADA ===\n");
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
