#ifndef SCHEDULER_H
#define SCHEDULER_H

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "../lib/CEthreads.h"

#define QUANTUM_mSEC 6000

typedef struct {
  CEthread_t thread;
  int ID;
  int position;
  int speed;
  float tiempo_total;
  float tiempo_restante;
  // Sirve de typecar
  int typecar;  // type: 1 Normal
                 //       2 Deportivo
                 //       3 Ambulancia
  bool Permission;

} car;

bool scheduler(int option, car *procesos, int num_procesos, car slowestcar);

#endif  // CALENDAR_H
