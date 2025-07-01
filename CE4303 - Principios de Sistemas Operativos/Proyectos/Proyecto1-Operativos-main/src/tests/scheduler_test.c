#include "../include/scheduler.h"
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <unistd.h>

// Función de prueba para simular el trabajo de un hilo
void* test_thread_function(void* arg) {
    int id = *(int*)arg;
    printf("Hilo de prueba %d ejecutándose\n", id);
    sleep(1);  // Simula trabajo
    return NULL;
}

// Función para crear un hilo de prueba
CEthread_t create_test_thread(int id) {
    CEthread_t thread;
    thread.tid = id;
    // Aquí normalmente llamarías a CEthread_create, pero para pruebas
    // simplemente estamos asignando un ID
    return thread;
}

// Función para probar la inicialización del scheduler
void test_scheduler_init() {
    printf("\n===== Prueba de inicialización =====\n");
    scheduler_init(SCHED_CE_FCFS);
    printf("Scheduler inicializado en modo FCFS\n");
    
    // Reinicializar con otro modo
    scheduler_init(SCHED_CE_SJF);
    printf("Scheduler reinicializado en modo SJF\n");
}

// Función para probar la adición de hilos
void test_add_threads() {
    printf("\n===== Prueba de adición de hilos =====\n");
    
    // Limpiar estado previo
    scheduler_init(SCHED_CE_FCFS);
    
    // Agregar algunos hilos a la cola izquierda
    for (int i = 1; i <= 5; i++) {
        CEthread_t thread = create_test_thread(i);
        scheduler_add_thread(thread, i*10, i, i*100, 1);  // Izquierda
    }
    
    // Agregar algunos hilos a la cola derecha
    for (int i = 6; i <= 10; i++) {
        CEthread_t thread = create_test_thread(i);
        scheduler_add_thread(thread, i*10, i, i*100, 0);  // Derecha
    }
    
    // Verificar que hay hilos en ambas colas
    assert(scheduler_has_threads_left());
    assert(scheduler_has_threads_right());
    assert(scheduler_has_threads());
    
    printf("Hilos agregados correctamente a ambas colas\n");
}

// Función para probar la selección de hilos según el algoritmo
void test_thread_selection() {
    printf("\n===== Prueba de selección de hilos =====\n");
    
    // Probar FCFS (First Come First Served)
    scheduler_init(SCHED_CE_FCFS);
    
    // Agregar hilos en orden conocido
    for (int i = 1; i <= 3; i++) {
        CEthread_t thread = create_test_thread(i);
        scheduler_add_thread(thread, i*30, i, i*50, 1);  // Izquierda
    }
    
    // El primero en llegar debe ser el primero en salir
    CEthread_t next = scheduler_next_thread_from_left();
    printf("FCFS: El siguiente hilo debería ser ID=1, es: ID=%d\n", next.tid);
    assert(next.tid == 1);
    
    // Probar SJF (Shortest Job First)
    scheduler_init(SCHED_CE_SJF);
    
    // Agregar hilos con tiempos estimados en orden inverso
    CEthread_t thread1 = create_test_thread(1);
    CEthread_t thread2 = create_test_thread(2);
    CEthread_t thread3 = create_test_thread(3);
    
    scheduler_add_thread(thread3, 30, 3, 300, 0);  // Derecha, tiempo más largo
    scheduler_add_thread(thread1, 10, 1, 100, 0);  // Derecha, tiempo más corto
    scheduler_add_thread(thread2, 20, 2, 200, 0);  // Derecha, tiempo medio
    
    // El de menor tiempo estimado debe ser el primero
    next = scheduler_next_thread_from_right();
    printf("SJF: El siguiente hilo debería ser ID=1 (tiempo=10), es: ID=%d\n", next.tid);
    assert(next.tid == 1);
    
    // Probar prioridad
    scheduler_init(SCHED_CE_PRIORITY);
    
    // Agregar hilos con prioridades diferentes
    thread1 = create_test_thread(1);
    thread2 = create_test_thread(2);
    thread3 = create_test_thread(3);
    
    scheduler_add_thread(thread3, 30, 3, 300, 1);  // Izquierda, prioridad baja
    scheduler_add_thread(thread1, 10, 1, 100, 1);  // Izquierda, prioridad alta
    scheduler_add_thread(thread2, 20, 2, 200, 1);  // Izquierda, prioridad media
    
    // El de mayor prioridad (número más bajo) debe ser el primero
    next = scheduler_next_thread_from_left();
    printf("Priority: El siguiente hilo debería ser ID=1 (prioridad=1), es: ID=%d\n", next.tid);
    assert(next.tid == 1);
}

// Función para probar la extracción de hilos
void test_thread_extraction() {
    printf("\n===== Prueba de extracción de hilos =====\n");
    
    scheduler_init(SCHED_CE_FCFS);
    
    // Agregar 3 hilos a cada cola
    for (int i = 1; i <= 3; i++) {
        CEthread_t thread = create_test_thread(i);
        scheduler_add_thread(thread, i*10, i, i*100, 1);  // Izquierda
    }
    
    for (int i = 4; i <= 6; i++) {
        CEthread_t thread = create_test_thread(i);
        scheduler_add_thread(thread, i*10, i, i*100, 0);  // Derecha
    }
    
    // Extraer todos los hilos de la izquierda
    while (scheduler_has_threads_left()) {
        CEthread_t next = scheduler_next_thread_from_left();
        printf("Extrayendo hilo izquierdo: ID=%d\n", next.tid);
    }
    
    // Extraer todos los hilos de la derecha
    while (scheduler_has_threads_right()) {
        CEthread_t next = scheduler_next_thread_from_right();
        printf("Extrayendo hilo derecho: ID=%d\n", next.tid);
    }
    
    // Verificar que no quedan hilos
    assert(!scheduler_has_threads());
    printf("Todas las colas están vacías\n");
}

// Función principal que ejecuta todas las pruebas
int main(int argc, char* argv[]) {
    printf("Iniciando pruebas del scheduler...\n");
    
    test_scheduler_init();
    test_add_threads();
    test_thread_selection();
    test_thread_extraction();
    
    printf("\n===== Todas las pruebas completadas con éxito =====\n");
    return 0;
}