// street.h
#ifndef STREET_H
#define STREET_H
#include <CEthreads.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "../scheduler/scheduler.h"

#ifndef SOCKET_PORT
#define SOCKET_PORT 5000
#endif

#ifndef BUFFER_SIZE
#define BUFFER_SIZE 2048
#endif

#define MAX_LINE_LENGTH 256

typedef struct {
  car *waiting;
  int maxcapacity;
  int capacity;
} waitline;

typedef struct {
  int managed_cars;  // De momento uso los ids de aqui
  int cars_in;
  int size;
  car *street;

  int W;
  int time;
  int carspeeds[3];

  int street_scheduling;  // 1 EQUIDAD
                         // 2 LETRERO
                         // 3 FIFO

  int thread_scheduling;  // 1 FCFS
                          // 2 SJF
                          // 3 Prioridad
                          // 4 RR
                          // 3 RealTime

  bool direction;  // True derecha, false izquierda
  bool running;

  bool Yellowlight;  // Esta variable es sobre todo para interfaz, una especie
                     // de alerta de luz amarilla

  bool TiempoReal;
  int RRiter;
  int RRID;

} street;

extern street Street;
extern waitline left_street;
extern waitline right_street;

void street_tryout();

void Street_init(const char *nombre_archivo);

void create_street();
void waitline_create();
void destroy_street();

void waitline_init(bool right, char *list);

void addcardummy(bool right, int type);

void *carmover(void *arg);

void enterstreet();

void streetcontent();

void *Street_Schedule(void *arg);

void CarGUI();

void YellowStreet();

int EnterStreet(int Waitpos, bool queue);

car GetEnterCar(int index, bool queue);

car GetSlowestCar();

void Street_RR();

void CheckRealTime();

void init_server_socket();

void *accept_connections(void *arg);

void start_server();

int send_data();

#endif  