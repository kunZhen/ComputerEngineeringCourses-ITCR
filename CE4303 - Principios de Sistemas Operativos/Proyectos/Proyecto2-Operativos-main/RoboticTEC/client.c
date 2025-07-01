#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/stat.h>
#include <sys/time.h>


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
