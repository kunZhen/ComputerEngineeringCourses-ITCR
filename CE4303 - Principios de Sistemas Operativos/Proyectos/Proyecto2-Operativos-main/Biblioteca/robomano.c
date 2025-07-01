#include "robomano.h"
#include <fcntl.h>
#include <unistd.h>
#include <ctype.h>
#include <string.h>
#include <stdio.h>

#define DEV_PATH "/dev/robomano"

/* Distribución del teclado (índices columna 0-9, 0-8, 0-6) */
static const char *rows[3] = {
    "qwertyuiop",   /* fila 0 */
    "asdfghjkl",    /* fila 1 – G está en col 4            */
    "zxcvbnm"       /* fila 2 */
};

static const int ORIG_ROW = 1, ORIG_COL = 4;   /* coordenadas de G */

static int fd = -1;                            /* descriptor global */

/* Envía un byte de comando al driver (/dev/robomano) */
static inline void send(char c) { write(fd, &c, 1); }

/* Obtiene fila/columna de la letra; 0 si existe, -1 si no está en el mapa */
static int coords(char ch, int *row, int *col)
{
    ch = tolower((unsigned char)ch);
    for (int r = 0; r < 3; ++r) {
        const char *p = strchr(rows[r], ch);
        if (p) { *row = r; *col = p - rows[r]; return 0; }
    }
    return -1;
}

/* ---- envía comandos para una sola letra -------------------------------- */
/* ---- envía comandos para una sola letra -------------------------------- */
static void type_letter(char ch)
{
    int r, c;
    if (coords(ch, &r, &c) != 0) return;   /* ignora caracteres fuera de mapa */

    /* ----- mover en vertical ----- */
    if (r < ORIG_ROW)
        for (int i = 0; i < ORIG_ROW - r; ++i) send('Q');   /* subir */
    else if (r > ORIG_ROW)
        for (int i = 0; i < r - ORIG_ROW; ++i) send('W');   /* bajar */

    /* ----- mover en horizontal ---- */
    if (c < ORIG_COL)
        for (int i = 0; i < ORIG_COL - c; ++i) send('L');   /* izquierda */
    else if (c > ORIG_COL)
        for (int i = 0; i < c - ORIG_COL; ++i) send('R');   /* derecha */

    /* presionar y soltar */
    send('D');
    send('U');
}


/* ------------------- API pública --------------------------------------- */
int robomano_init(void)
{
    fd = open(DEV_PATH, O_WRONLY);
    if (fd < 0) { perror("open /dev/robomano"); return -1; }
    return 0;
}

void robomano_write_word(const char *w)
{
    for (; *w; ++w)
        type_letter(*w);
}

void robomano_close(void)
{
    if (fd >= 0) close(fd);
    fd = -1;
}
