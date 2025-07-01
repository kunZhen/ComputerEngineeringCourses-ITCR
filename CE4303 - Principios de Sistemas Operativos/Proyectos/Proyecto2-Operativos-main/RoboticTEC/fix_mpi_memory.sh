#!/bin/bash

# Script para corregir problemas de memoria en el procesamiento MPI
# RoboticTEC - Proyecto de Sistemas Operativos

set -e

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m'

echo -e "${COLOR_BLUE}=== CORRIGIENDO PROBLEMAS DE MEMORIA EN MPI ===${COLOR_NC}"
echo ""

# Backup del nodo actual
timestamp=$(date +%Y%m%d_%H%M%S)
if [ -f "nodo.c" ]; then
    cp nodo.c "nodo.c.backup_${timestamp}"
    echo -e "${COLOR_YELLOW}Backup creado: nodo.c.backup_${timestamp}${COLOR_NC}"
fi

# Crear nodo.c corregido para archivos grandes
echo -e "${COLOR_YELLOW}Creando nodo.c corregido para archivos grandes...${COLOR_NC}"

cat > nodo.c << 'EOF'
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define CLAVE_CIFRADO 3
#define MAX_PALABRA 100
#define MAX_TEXTO_GRANDE 5000000    // 5MB para archivos grandes
#define MAX_PALABRAS_LOCAL 10000    // Más palabras por nodo
#define OVERLAP 32                  // Mayor margen para archivos grandes

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

// Funcion para liberar memoria de forma segura
void liberar_memoria(void *ptr) {
    if (ptr != NULL) {
        free(ptr);
        ptr = NULL;
    }
}

int main(int argc, char *argv[]) {
    int rank, size;
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    char *texto_total = NULL;
    int tam_texto = 0;
    char *bloque_local = NULL;
    PalabraConteo *conteos_locales = NULL;
    char *buffer_envio = NULL;

    if (rank == 0) {
        printf("Nodo raiz: Abriendo archivo cifrado...\n");
        FILE *f = fopen("archivo_cifrado.txt", "rb");
        if (!f) {
            perror("No se pudo abrir archivo_cifrado.txt");
            MPI_Abort(MPI_COMM_WORLD, 1);
        }

        // Obtener tamaño real del archivo
        fseek(f, 0, SEEK_END);
        tam_texto = ftell(f);
        fseek(f, 0, SEEK_SET);

        printf("Nodo raiz: Archivo de %d bytes detectado\n", tam_texto);

        // Asignar memoria basada en el tamaño real
        texto_total = malloc(tam_texto + 1);
        if (!texto_total) {
            fprintf(stderr, "Error: No se pudo asignar memoria para el texto\n");
            fclose(f);
            MPI_Abort(MPI_COMM_WORLD, 1);
        }

        size_t leidos = fread(texto_total, 1, tam_texto, f);
        texto_total[leidos] = '\0';
        tam_texto = leidos;
        fclose(f);

        printf("Nodo raiz: %d bytes leidos correctamente\n", tam_texto);
    }

    // Difundir tamaño del texto
    MPI_Bcast(&tam_texto, 1, MPI_INT, 0, MPI_COMM_WORLD);
    
    printf("Nodo %d: Recibido tamaño de texto: %d bytes\n", rank, tam_texto);

    // Verificar tamaño válido
    if (tam_texto <= 0 || tam_texto > MAX_TEXTO_GRANDE) {
        fprintf(stderr, "Nodo %d: Tamaño de archivo inválido: %d\n", rank, tam_texto);
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    // Asignar memoria en todos los nodos
    if (rank != 0) {
        texto_total = malloc(tam_texto + 1);
        if (!texto_total) {
            fprintf(stderr, "Nodo %d: Error asignando memoria\n", rank);
            MPI_Abort(MPI_COMM_WORLD, 1);
        }
    }

    // Difundir el texto completo
    MPI_Bcast(texto_total, tam_texto + 1, MPI_CHAR, 0, MPI_COMM_WORLD);
    
    printf("Nodo %d: Texto recibido correctamente\n", rank);

    // Calcular segmento a procesar de manera más equilibrada
    int segmento_base = tam_texto / size;
    int start = rank * segmento_base;
    int end;
    
    if (rank == size - 1) {
        end = tam_texto;  // El último nodo procesa todo lo restante
    } else {
        end = start + segmento_base + OVERLAP;
        if (end > tam_texto) end = tam_texto;
    }
    
    int tam_local = end - start;
    
    printf("Nodo %d: Procesando desde %d hasta %d (tamaño: %d)\n", 
           rank, start, end, tam_local);

    // Asignar memoria para el bloque local
    bloque_local = malloc(tam_local + 1);
    if (!bloque_local) {
        fprintf(stderr, "Nodo %d: Error asignando memoria para bloque local\n", rank);
        liberar_memoria(texto_total);
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    memcpy(bloque_local, texto_total + start, tam_local);
    bloque_local[tam_local] = '\0';

    // Liberar el texto completo para ahorrar memoria
    liberar_memoria(texto_total);

    // Descifrar el bloque
    printf("Nodo %d: Descifrando bloque...\n", rank);
    for (int i = 0; i < tam_local; ++i) {
        bloque_local[i] = descifrar_char(bloque_local[i]);
    }

    // Asignar memoria para conteos locales
    conteos_locales = malloc(MAX_PALABRAS_LOCAL * sizeof(PalabraConteo));
    if (!conteos_locales) {
        fprintf(stderr, "Nodo %d: Error asignando memoria para conteos\n", rank);
        liberar_memoria(bloque_local);
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    // Tokenizar palabras
    printf("Nodo %d: Tokenizando palabras...\n", rank);
    char *token = strtok(bloque_local, " \t\n\r.,;:!?()[]{}<>\"\'");
    int n_local = 0;

    while (token != NULL && n_local < MAX_PALABRAS_LOCAL - 1) {
        // Filtrar tokens muy cortos o muy largos
        if (strlen(token) > 2 && strlen(token) < MAX_PALABRA - 1) {
            normalizar(token);
            
            int encontrado = 0;
            for (int i = 0; i < n_local; ++i) {
                if (strcmp(conteos_locales[i].palabra, token) == 0) {
                    conteos_locales[i].conteo++;
                    encontrado = 1;
                    break;
                }
            }
            
            if (!encontrado) {
                strncpy(conteos_locales[n_local].palabra, token, MAX_PALABRA - 1);
                conteos_locales[n_local].palabra[MAX_PALABRA - 1] = '\0';
                conteos_locales[n_local].conteo = 1;
                n_local++;
            }
        }
        token = strtok(NULL, " \t\n\r.,;:!?()[]{}<>\"\'");
    }

    printf("Nodo %d: Encontradas %d palabras únicas\n", rank, n_local);

    // Liberar bloque local
    liberar_memoria(bloque_local);

    // Serializar conteos de manera más segura
    int buffer_size = n_local * 150 + 100;  // Tamaño dinámico
    buffer_envio = malloc(buffer_size);
    if (!buffer_envio) {
        fprintf(stderr, "Nodo %d: Error asignando buffer de envío\n", rank);
        liberar_memoria(conteos_locales);
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    buffer_envio[0] = '\0';
    for (int i = 0; i < n_local; ++i) {
        char linea[150];
        snprintf(linea, sizeof(linea), "%s %d\n", 
                conteos_locales[i].palabra, conteos_locales[i].conteo);
        
        // Verificar que no desbordemos el buffer
        if (strlen(buffer_envio) + strlen(linea) < buffer_size - 1) {
            strcat(buffer_envio, linea);
        } else {
            printf("Nodo %d: Advertencia - buffer lleno, truncando datos\n", rank);
            break;
        }
    }

    // Liberar conteos locales
    liberar_memoria(conteos_locales);

    // Comunicación MPI más robusta
    int tam_envio = strlen(buffer_envio) + 1;
    int *tamanos = NULL;
    
    if (rank == 0) {
        tamanos = malloc(size * sizeof(int));
        if (!tamanos) {
            fprintf(stderr, "Nodo raiz: Error asignando memoria para tamaños\n");
            liberar_memoria(buffer_envio);
            MPI_Abort(MPI_COMM_WORLD, 1);
        }
    }

    printf("Nodo %d: Enviando %d bytes de datos\n", rank, tam_envio);
    MPI_Gather(&tam_envio, 1, MPI_INT, tamanos, 1, MPI_INT, 0, MPI_COMM_WORLD);

    // Calcular tamaño total necesario
    char *recibidos = NULL;
    int *desplazamientos = NULL;
    
    if (rank == 0) {
        int total = 0;
        for (int i = 0; i < size; ++i) {
            total += tamanos[i];
        }
        
        printf("Nodo raiz: Recibiendo %d bytes totales\n", total);
        
        recibidos = malloc(total + 100);
        desplazamientos = malloc(size * sizeof(int));
        
        if (!recibidos || !desplazamientos) {
            fprintf(stderr, "Nodo raiz: Error asignando memoria para recepción\n");
            MPI_Abort(MPI_COMM_WORLD, 1);
        }
        
        // Calcular desplazamientos
        desplazamientos[0] = 0;
        for (int i = 1; i < size; ++i) {
            desplazamientos[i] = desplazamientos[i-1] + tamanos[i-1];
        }
    }

    // Usar Gatherv para manejar tamaños variables de manera segura
    MPI_Gatherv(buffer_envio, tam_envio, MPI_CHAR, 
                recibidos, tamanos, desplazamientos, MPI_CHAR, 
                0, MPI_COMM_WORLD);

    liberar_memoria(buffer_envio);

    // Procesamiento final en root
    if (rank == 0) {
        printf("Nodo raiz: Procesando resultados finales...\n");
        
        PalabraConteo *final = malloc(20000 * sizeof(PalabraConteo));
        if (!final) {
            fprintf(stderr, "Nodo raiz: Error asignando memoria final\n");
            MPI_Abort(MPI_COMM_WORLD, 1);
        }
        
        int n_final = 0;

        // Procesar datos recibidos de manera más robusta
        for (int nodo = 0; nodo < size; ++nodo) {
            char *inicio = recibidos + desplazamientos[nodo];
            char *copia = malloc(tamanos[nodo] + 1);
            if (!copia) continue;
            
            memcpy(copia, inicio, tamanos[nodo]);
            copia[tamanos[nodo]] = '\0';
            
            char *linea = strtok(copia, "\n");
            while (linea && n_final < 19999) {
                char palabra[MAX_PALABRA];
                int cantidad;
                
                if (sscanf(linea, "%99s %d", palabra, &cantidad) == 2) {
                    int encontrado = 0;
                    for (int i = 0; i < n_final; ++i) {
                        if (strcmp(final[i].palabra, palabra) == 0) {
                            final[i].conteo += cantidad;
                            encontrado = 1;
                            break;
                        }
                    }
                    
                    if (!encontrado) {
                        strncpy(final[n_final].palabra, palabra, MAX_PALABRA - 1);
                        final[n_final].palabra[MAX_PALABRA - 1] = '\0';
                        final[n_final].conteo = cantidad;
                        n_final++;
                    }
                }
                
                linea = strtok(NULL, "\n");
            }
            
            liberar_memoria(copia);
        }

        printf("Nodo raiz: Total de %d palabras únicas procesadas\n", n_final);

        // Encontrar la palabra más frecuente
        int max = 0;
        char palabra_max[MAX_PALABRA] = "";
        
        for (int i = 0; i < n_final; ++i) {
            if (final[i].conteo > max) {
                max = final[i].conteo;
                strncpy(palabra_max, final[i].palabra, MAX_PALABRA - 1);
                palabra_max[MAX_PALABRA - 1] = '\0';
            }
        }

        // Guardar resultado
        FILE *out = fopen("archivo_descifrado.txt", "w");
        if (out) {
            fprintf(out, "%s %d\n", palabra_max, max);
            fclose(out);
            printf("Resultado guardado: '%s' (%d veces)\n", palabra_max, max);
        } else {
            perror("No se pudo guardar resultado");
        }

        // Limpiar memoria
        liberar_memoria(final);
        liberar_memoria(recibidos);
        liberar_memoria(desplazamientos);
        liberar_memoria(tamanos);
    }

    printf("Nodo %d: Finalizando...\n", rank);
    MPI_Finalize();
    return 0;
}
EOF

echo -e "${COLOR_GREEN}✓ nodo.c corregido creado${COLOR_NC}"

# Recompilar solo el nodo
echo -e "${COLOR_YELLOW}Recompilando nodo MPI...${COLOR_NC}"
if mpicc -Wall -Wextra -g -O2 -c nodo.c -o obj/nodo.o 2>/dev/null || mpicc -Wall -Wextra -g -O2 -c nodo.c -o nodo.o; then
    echo -e "${COLOR_GREEN}✓ Compilación del nodo exitosa${COLOR_NC}"
else
    echo -e "${COLOR_RED}✗ Error compilando nodo${COLOR_NC}"
    exit 1
fi

# Crear ejecutable
if [ -f "obj/nodo.o" ]; then
    mpicc -Wall -Wextra -g -O2 -o nodo obj/nodo.o
elif [ -f "nodo.o" ]; then
    mpicc -Wall -Wextra -g -O2 -o nodo nodo.o
    rm -f nodo.o
fi

if [ -x "./nodo" ]; then
    echo -e "${COLOR_GREEN}✓ Ejecutable ./nodo creado exitosamente${COLOR_NC}"
else
    echo -e "${COLOR_RED}✗ Error creando ejecutable${COLOR_NC}"
    exit 1
fi

echo ""
echo -e "${COLOR_GREEN}=== CORRECCIÓN COMPLETADA ===${COLOR_NC}"
echo ""
echo "✅ Mejoras implementadas en nodo.c:"
echo "   • Gestión de memoria más robusta"
echo "   • Soporte para archivos de hasta 5MB"
echo "   • Uso de MPI_Gatherv para tamaños variables"
echo "   • Mejor manejo de errores y liberación de memoria"
echo "   • Filtrado de palabras muy cortas"
echo "   • Buffers dinámicos para evitar desbordamientos"
echo ""
echo "🧪 Para probar:"
echo "   Terminal 1: ./server"
echo "   Terminal 2: ./client archivos/el_quijote.txt 127.0.0.1"
echo ""
echo -e "${COLOR_BLUE}¡El procesamiento MPI ahora debería manejar el archivo grande sin errores!${COLOR_NC}"
