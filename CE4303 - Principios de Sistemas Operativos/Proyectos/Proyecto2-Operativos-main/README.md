# Proyecto2-Operativos

# Introducción 
Este proyecto se centra en el diseño e implementación de un sistema distribuido de procesamiento de texto utilizando paralelismo real mediante la biblioteca MPI (Message Passing Interface), comunicación en red mediante sockets TCP/IP, y control de hardware físico (una mano robótica) a través de un driver de carácter desarrollado en espacio de kernel.

El objetivo principal es recibir un archivo de texto cifrado desde un cliente, descifrarlo y analizarlo en paralelo para identificar la palabra más repetida. Este resultado es finalmente escrito físicamente por una mano robótica controlada por un Arduino, conectada a través del dispositivo especial /dev/robomano gestionado por un módulo del kernel Linux.

Este documento explica brevemente los fundamentos teóricos utilizados (comunicación por sockets, paralelismo con MPI, cifrado tipo César, drivers de carácter, y control de servos con Arduino), describe la arquitectura general del sistema, detalla el comportamiento de cada componente implementado (cliente, servidor, nodos, biblioteca, driver y Arduino), y presenta los resultados y observaciones obtenidas.

Se espera que este escrito sirva como referencia técnica y de documentación funcional para entender y reproducir el sistema, así como para futuras mejoras o ampliaciones del proyecto.


# Instalar OpenMPI
```
cd RoboticTEC
sudo apt update
sudo apt install openmpi-bin libopenmpi-dev
```

# Verificar Instalacion
```
mpicc --version
mpirun --version
```

# Ejecutar nodo
```
mpicc nodo.c -o nodo
```

# Compilar Servidor
```
gcc server.c -o server
./server
```


# En una terminal (servidor MPI: 4 procesos en localhost)
```
mpirun -np 4 ./server 5000
```

# En otra terminal (cliente)
```
gcc -Wall -Wextra -std=c11 -o client client.c
./client archivos/el_quijote.txt 127.0.0.1
```
