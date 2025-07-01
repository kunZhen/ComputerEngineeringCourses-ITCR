#include "biblioteca.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

static int serial_fd = -1;

int inicializar_mano(const char *puerto) {
    serial_fd = open(puerto, O_RDWR | O_NOCTTY | O_NDELAY);
    if (serial_fd == -1) {
        perror("No se pudo abrir el puerto serial");
        return -1;
    }

    struct termios opciones;
    tcgetattr(serial_fd, &opciones);
    cfsetispeed(&opciones, B9600);
    cfsetospeed(&opciones, B9600);
    opciones.c_cflag |= (CLOCAL | CREAD);
    opciones.c_cflag &= ~CSIZE;
    opciones.c_cflag |= CS8;
    opciones.c_cflag &= ~PARENB;
    opciones.c_cflag &= ~CSTOPB;
    opciones.c_cflag &= ~CRTSCTS;
    opciones.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    opciones.c_iflag &= ~(IXON | IXOFF | IXANY);
    opciones.c_oflag &= ~OPOST;

    tcsetattr(serial_fd, TCSANOW, &opciones);
    usleep(1000000);  // Espera por sincronización
    return 0;
}

void enviar_comando(char comando) {
    if (serial_fd != -1) {
        write(serial_fd, &comando, 1);
        usleep(150000);  // Espera para que el Arduino procese
    }
}

void mover_derecha()  { enviar_comando('R'); }
void mover_izquierda(){ enviar_comando('L'); }
void bajar_dedo()     { enviar_comando('D'); }
void subir_dedo()     { enviar_comando('U'); }
void mover_arriba()   { enviar_comando('Q'); }
void mover_abajo()    { enviar_comando('W'); }

void cerrar_mano() {
    if (serial_fd != -1) {
        close(serial_fd);
        serial_fd = -1;
    }
}
