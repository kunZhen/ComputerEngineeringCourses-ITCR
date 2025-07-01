
#ifndef BIBLIOTECA_H
#define BIBLIOTECA_H


// Inicializa la comunicación con el dispositivo físico
int inicializar_mano(const char *puerto);

// Funciones de movimiento
void mover_derecha();
void mover_izquierda();
void bajar_dedo();
void subir_dedo();
void mover_arriba();
void mover_abajo();

// Cierra el puerto serial
void cerrar_mano();



#endif //BIBLIOTECA_H
