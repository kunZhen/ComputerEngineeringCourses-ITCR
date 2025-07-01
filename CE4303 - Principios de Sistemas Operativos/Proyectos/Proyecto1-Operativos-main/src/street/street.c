#include "street.h"

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <signal.h>
#include <sys/socket.h>

int server_fd = -1;
int client_fd = -1;
int client_fd2 = -1;
static CEmutex_t socket_mutex;
static size_t message_id = 0;

street Street;
waitline left_street;
waitline right_street;

CEmutex_t street_mutex;

car emptycar = {{-1, NULL, NULL}, -1, -1, -1, -1, -1, -1, -1};

void street_tryout() {
  if (CEmutex_init(&street_mutex) != 0) {
    perror("Error to initialize street_mutex");
    return;
  }
  start_server();
  Street_init("street/street.config");
  streetcontent();
  CarGUI();
  destroy_street();
}

void init_server_socket() {
  struct sockaddr_in address;
  int on = 1;  // Cambiamos el nombre de la variable a 'on'
  int addrlen = sizeof(address);

  // create a socket object
  if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
    perror("Error to create socket");
    exit(EXIT_FAILURE);
  }

  // Configurar opciones de reutilización de puerto
  if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on))) {
    perror("Error in setsockopt SO_REUSEADDR");
    exit(EXIT_FAILURE);
  }

  // Opción específica para Linux
  #ifdef SO_REUSEPORT
  if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEPORT, &on, sizeof(on))) {
    perror("Error in setsockopt SO_REUSEPORT");
    // No salimos aquí, solo registramos el error
  }
  #endif

  // Resto del código sin cambios...
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = INADDR_ANY;
  address.sin_port = htons(SOCKET_PORT);

  if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
    perror("Error on bind");
    exit(EXIT_FAILURE);
  }

  if (listen(server_fd, 3) < 0) {
    perror("Error on listen");
    exit(EXIT_FAILURE);
  }
  const int port = SOCKET_PORT;
  printf("Server listening on port %d, waiting for connections...\n", port);
}

void *accept_connections(void *arg) {
  struct sockaddr_in address;
  int addrlen = sizeof(address);

  while (1) {
    // accept the incoming connection
    int new_client_fd =
        accept(server_fd, (struct sockaddr *)&address, (socklen_t *)&addrlen);
    if (new_client_fd < 0) {
      perror("Error in accept");
      continue;
    }

    printf("Client connected with fd %d\n", new_client_fd);

    // protect access to client_fd and client_fd2 with the mutex
    CEmutex_lock(&socket_mutex);

    if (client_fd == -1) {
      client_fd = new_client_fd;
      printf("Assigned to client_fd\n");
    } else if (client_fd2 == -1) {
      client_fd2 = new_client_fd;
      printf("Assigned to client_fd2\n");
    } else {
      // The server only accepts 2 clients at a time
      printf("Server is full. Closing new connection fd %d\n", new_client_fd);
      close(new_client_fd);
    }

    CEmutex_unlock(&socket_mutex);
  }
  return NULL;
}

void start_server() {
  if (CEmutex_init(&socket_mutex) != 0) {
    perror("Error to initialize socket_mutex");
    return;
  }
  // init_server_socket();
  init_server_socket();

  // ignore SIGPIPE
  signal(SIGPIPE, SIG_IGN);

  // create the accept thread
  CEthread_t accept_thread;
  if (CEthread_create(&accept_thread, accept_connections, NULL) != 0) {
    fprintf(stderr, "Error to create accept_thread\n");
    exit(EXIT_FAILURE);
  }
}

int send_data() {
  // ------------------- Send message to GUI ---------------------
  char buffer[BUFFER_SIZE];
  int offset = 0;
  int n;
  // build the content to send
  offset += snprintf(buffer + offset, sizeof(buffer) - offset, "Street: ");
  for (int i = 0; i < Street.size; i++) {
    car carprinter = Street.street[i];
    offset += snprintf(buffer + offset, sizeof(buffer) - offset, "%d ",
                       carprinter.typecar);
  }
  offset +=
      snprintf(buffer + offset, sizeof(buffer) - offset, "\nDirection: %s",
               (Street.direction) ? ("Right") : ("Left"));
  offset +=
      snprintf(buffer + offset, sizeof(buffer) - offset, "\nTiempoReal: %s",
               (Street.TiempoReal) ? ("true") : ("false"));
  offset +=
      snprintf(buffer + offset, sizeof(buffer) - offset, "\nYellow Light: %s",
               (Street.Yellowlight) ? ("true") : ("false"));
  offset += snprintf(buffer + offset, sizeof(buffer) - offset, "\nLeft:[");
  for (int i = 0; i < left_street.capacity; i++) {
    car carprinter = left_street.waiting[i];
    offset += snprintf(buffer + offset, sizeof(buffer) - offset, "%d ",
                       carprinter.typecar);
  }
  offset += snprintf(buffer + offset, sizeof(buffer) - offset, "]");
  offset += snprintf(buffer + offset, sizeof(buffer) - offset, "\nRight:[");
  for (int i = 0; i < right_street.capacity; i++) {
    car carprinter = right_street.waiting[i];
    offset += snprintf(buffer + offset, sizeof(buffer) - offset, "%d ",
                       carprinter.typecar);
  }
  offset += snprintf(buffer + offset, sizeof(buffer) - offset, "]\n");

  // send the message
  CEmutex_lock(&socket_mutex);

  if (client_fd > 0) {
    // Set socket to non-blocking mode
    int flags = fcntl(client_fd, F_GETFL, 0);
    fcntl(client_fd, F_SETFL, flags | O_NONBLOCK);

    message_id++;
    offset += snprintf(buffer + offset, sizeof(buffer) - offset,
                       "Message ID: %ld\nEND_OF_MESSAGE\n", message_id);
    n = send(client_fd, buffer, strlen(buffer), 0);

    if (n < 0) {
      if (errno == EPIPE || errno == ECONNRESET || errno == EAGAIN ||
          errno == EWOULDBLOCK) {
        perror("Error sending message to client_fd");
        // Close the socket and clean up
        close(client_fd);
        client_fd = -1;
        message_id--;
      } else {
        perror("Unexpected error in send() to client_fd");
      }
    }
  }

  if (client_fd2 > 0) {
    // Set socket to non-blocking mode
    int flags = fcntl(client_fd2, F_GETFL, 0);
    fcntl(client_fd2, F_SETFL, flags | O_NONBLOCK);

    message_id++;
    n = send(client_fd2, buffer, strlen(buffer), 0);

    if (n < 0) {
      if (errno == EPIPE || errno == ECONNRESET || errno == EAGAIN ||
          errno == EWOULDBLOCK) {
        perror("Error sending message to client_fd2");
        // Close the socket and clean up
        close(client_fd2);
        client_fd2 = -1;
        message_id--;
      } else {
        perror("Unexpected error in send() to client_fd2");
      }
    }
  }

  CEmutex_unlock(&socket_mutex);
  return 0;
}

void Street_init(const char *nombre_archivo) {
  Street.managed_cars = 0;
  Street.running = true;
  Street.direction = false;
  Street.TiempoReal = true;
  Street.RRiter = 0;
  Street.RRID = -2;

  FILE *file;
  char line[MAX_LINE_LENGTH];
  char clave[128];
  char valor[128];

  // Abre el archivo en modo lectura
  file = fopen(nombre_archivo, "r");
  if (file == NULL) {
    perror("Error al abrir el archivo");
    return;
  }

  // Lee el archivo línea por línea
  while (fgets(line, sizeof(line), file)) {
    // Elimina el salto de línea al final
    line[strcspn(line, "\n")] = 0;
    // Separa la clave y el valor
    if (sscanf(line, "%127[^=]=%127s", clave, valor) == 2) {
      if (strcmp(clave, "length") == 0) {
        Street.size = atoi(valor);
        create_street();
      } else if (strcmp(clave, "c_schedule") == 0) {
        Street.street_scheduling = atoi(valor);
      } else if (strcmp(clave, "W") == 0) {
        Street.W = atoi(valor);
      } else if (strcmp(clave, "time") == 0) {
        Street.time = atoi(valor);
      } else if (strcmp(clave, "speed") == 0) {
        Street.carspeeds[0] = atoi(&valor[0]);
        Street.carspeeds[1] = atoi(&valor[2]);
        Street.carspeeds[2] = atoi(&valor[4]);
      } else if (strcmp(clave, "left") == 0) {
        left_street.capacity = 0;
        waitline_init(false, valor);
        Street.TiempoReal = scheduler(Street.thread_scheduling, left_street.waiting,
                                    left_street.capacity, emptycar);
      } else if (strcmp(clave, "right") == 0) {
        right_street.capacity = 0;
        waitline_init(true, valor);
        Street.TiempoReal = scheduler(Street.thread_scheduling, right_street.waiting,
                                    right_street.capacity, emptycar);
      } else if (strcmp(clave, "queuelength") == 0) {
        right_street.maxcapacity = atoi(valor);
        left_street.maxcapacity = atoi(valor);
        waitline_create();
      } else if (strcmp(clave, "t_schedule") == 0) {
        Street.thread_scheduling = atoi(valor);
      }
    }
  }
  // Cierra el archivo
  fclose(file);
}

void create_street() {
  Street.street = malloc(Street.size * sizeof(car));
  Street.cars_in = 0;
  if (Street.street == NULL) {
    perror("Error al asignar memoria");
    return;
  }

  // Inicializar el arreglo
  for (int i = 0; i < Street.size; i++) {
    Street.street[i] = emptycar;
  }
}

void destroy_street() {
  free(right_street.waiting);
  free(left_street.waiting);
  free(Street.street);
}

void waitline_init(bool right, char *list) {
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < atoi(&list[i * 2]); j++) {
      addcardummy(right, i + 1);
    }
  }
  streetcontent();
}

void waitline_create() {
  right_street.waiting = malloc(right_street.maxcapacity * sizeof(car));
  left_street.waiting = malloc(left_street.maxcapacity * sizeof(car));
}

void addcardummy(bool right, int type) {
  CEthread_t newthread;
  car newCar = {newthread, 
                  Street.managed_cars++, // id
                  -1, // posicion
                  Street.carspeeds[type - 1], // velocidad
                  (1.0 / Street.carspeeds[type - 1]) * Street.size, //tiempo total - inversa de la velocidad (tiempo por unidad) multiplicado por la longitud de la calle
                  (1.0 / Street.carspeeds[type - 1]) * Street.size, //tiempo restante
                  type, // tipo de carro
                  (Street.thread_scheduling == 4) ? (false) : (true)}; // permiso

  if (right) {
    if (right_street.capacity == right_street.maxcapacity) {
      printf("No se puede agregar en right\n");
    } else {
      right_street.waiting[right_street.capacity++] = newCar;
    }
  } else {
    if (left_street.capacity == left_street.maxcapacity) {
      printf("No se puede agregar en left\n");
    } else {
      left_street.waiting[left_street.capacity++] = newCar;
    }
  }
}

void *carmover(void *arg) {
  int adder = (Street.direction) ? (1) : (-1);
  int position = (Street.direction) ? (0) : (Street.size - 1);
  car car2move = Street.street[position];
  float delay = (1.0 / car2move.speed) * 1e6;

  while (Street.running) {
    // La velocidad se refleja en el delay
    usleep(delay);
    if ((position == Street.size - 1) &&
        (Street.direction)) {  // El carro debe salir por la derecha
      CEmutex_lock(&street_mutex);
      Street.street[Street.size - 1] = emptycar;
      Street.cars_in--;
      CEmutex_unlock(&street_mutex);
      streetcontent();
      break;
    } else if ((position == 0) &&
               (!Street.direction)) {  // El carro debe salir por la izquierda
      CEmutex_lock(&street_mutex);
      Street.street[0] = emptycar;
      Street.cars_in--;
      CEmutex_unlock(&street_mutex);
      streetcontent();
      break;
    } else if (Street.street[position + 1].ID != -1 &&
               Street.direction) {  // Hay un carro ocupando el lugar
      if (Street.thread_scheduling ==
          5) {  // Si se esta en tiempo real no cumple con el deadline
        Street.TiempoReal = false;
      }
      continue;
    } else if (Street.street[position - 1].ID != -1 &&
               (!Street.direction)) {  // Hay un carro ocupando el lugar
      if (Street.thread_scheduling ==
          5) {  // Si se esta en tiempo real no cumple con el deadline
        Street.TiempoReal = false;
      }
      continue;
    } else {  // el carro se mueve
      car2move = Street.street[position];
      if (car2move.Permission) {
        CEmutex_lock(&street_mutex);
        Street.street[position] = emptycar;
        position += adder;
        car2move.position = position;
        car2move.tiempo_restante -= delay / 1e6;
        Street.street[position] = car2move;
        streetcontent();
        CEmutex_unlock(&street_mutex);
      } else {
        continue;
      }
    }
  }
  CEthread_end(NULL);  // Convert to long to avoid casting warnings
  return NULL;
}

void streetcontent() {
  FILE *archivo = fopen("Street.txt", "w");

  // Verifica si el archivo se abrió correctamente
  if (archivo == NULL) {
    perror("Error al abrir el archivo");
  }

  // Imprimir el contenido del arreglo

  for (int i = 0; i < Street.size; i++) {
    car carprinter = Street.street[i];
    // fprintf(archivo,"[Id=%d,Speed=%d,Type=%d]
    // ",carprinter.ID,carprinter.speed,carprinter.typecar);
    fprintf(archivo, "%d ", carprinter.typecar);
  }
  fprintf(archivo, "\nDirection: %s", (Street.direction) ? ("Right") : ("Left"));
  fprintf(archivo, "\nTiempoReal: %s",
          (Street.TiempoReal) ? ("true") : ("false"));
  fprintf(archivo, "\nYellow Light: %s",
          (Street.Yellowlight) ? ("true") : ("false"));
  fprintf(archivo, "\nLeft:[");
  for (int i = 0; i < left_street.capacity; i++) {
    car carprinter = left_street.waiting[i];
    // fprintf(archivo,"[Id=%d,Speed=%d,Type=%d]
    // ",carprinter.ID,carprinter.speed,carprinter.typecar);
    fprintf(archivo, "%d ", carprinter.typecar);
  }
  fprintf(archivo, "]\nRight:[");
  for (int i = 0; i < right_street.capacity; i++) {
    car carprinter = right_street.waiting[i];
    // fprintf(archivo,"[Id=%d,Speed=%d,Type=%d]
    // ",carprinter.ID,carprinter.speed,carprinter.typecar);
    fprintf(archivo, "%d ", carprinter.typecar);
  }
  fprintf(archivo, "]");

  // Cierra el archivo
  fclose(archivo);
  send_data();
}

void CarGUI() {
  char respuesta[100];  // Buffer para almacenar el nombre
  int cartype = 1;
  const char *carstrings[] = {"Normal", "Deportivo", "Ambulancia"};
  char miString[3];

  // GUI Mensaje inicial
  printf("\nSeleccione una opción para iniciar:\n"
        "Comandos:\n"
        "    a:    🚗 Carro normal\n"
        "    b:    🏎️  Carro deportivo\n"
        "    c:    🚨 Carro emergencia\n\n"
        "    r:    ⏩ Agregar carro a la derecha\n"
        "    l:    ⏪ Agregar carro a la izquierda\n\n"
        "    q: ❌ Cerrar el server\n"
        "Ingrese su elección: ");
  scanf("%99s", respuesta);

  // Hilo para el manejo del street
  CEthread_t Street_thread;  // Identificador del hilo
  if (CEthread_create(&Street_thread, (void *)&Street_Schedule, (void *)NULL) !=
      0) {
    fprintf(stderr, "Error al crear el hilo\n");
    return;
  }

  while (Street.running) {
    printf("\nEscriba su comando:\n");
    printf("Carro por agregar %s\n", carstrings[cartype - 1]);

    // Imprimir un mensaje en la terminal y leer el nombre
    scanf("%99s", respuesta);  // Evitar desbordamiento

    if (strcmp(respuesta, "q") == 0) {
      Street.running = false;
    } else if (strcmp(respuesta, "a") == 0) {
      cartype = 1;  // Cambiar a carro normal
    } else if (strcmp(respuesta, "b") == 0) {
      cartype = 2;  // Cambiar a carro deportivo
    } else if (strcmp(respuesta, "c") == 0) {
      cartype = 3;  // Cambiar a carro emergencia
    } else if (strcmp(respuesta, "r") == 0) {
      CEmutex_lock(&street_mutex);
      addcardummy(true, cartype);  // Agregar carro a la derecha
      Street.TiempoReal = scheduler(Street.thread_scheduling, right_street.waiting,
                                  right_street.capacity, GetSlowestCar());
      if (Street.thread_scheduling) {
        CheckRealTime();
      }
      streetcontent();

      CEmutex_unlock(&street_mutex);
    } else if (strcmp(respuesta, "l") == 0) {
      CEmutex_lock(&street_mutex);
      addcardummy(false, cartype);  // Agregar carro a la izquierda
      Street.TiempoReal = scheduler(Street.thread_scheduling, left_street.waiting,
                                  left_street.capacity, GetSlowestCar());
      if (Street.thread_scheduling) {
        CheckRealTime();
      }
      streetcontent();

      CEmutex_unlock(&street_mutex);
    }
  }

  // Esperar finalizacion del manejo del street
  if (CEthread_join(Street_thread, NULL) != 0) {
    fprintf(stderr, "Error al esperar el hilo del Street\n");
    return;
  }

  printf("Saliendo del programa. ¡Adiós!\n");
}

void *Street_Schedule(void *arg) {
  // Variables de control actuales
  int w = 0;
  int timer = 0;

  // Variables de tiempo
  time_t start_time, current_time;
  start_time = time(NULL);

  while (Street.running) {
    if (Street.thread_scheduling == 4) {
      Street.RRiter++;
      if (QUANTUM_mSEC < Street.RRiter) {
        Street.RRiter = 0;
        Street_RR();
        scheduler(Street.thread_scheduling, right_street.waiting, right_street.capacity,
                 emptycar);
        scheduler(Street.thread_scheduling, left_street.waiting, left_street.capacity,
                 emptycar);
      }
    }
    if (Street.street_scheduling == 1) {  // W
      if (w == Street.W) {
        YellowStreet();  // Esperar a que los carros crucen
        w = 0;
        Street.direction = !Street.direction;
      } else {  // No se han cumplido los tiempos
        CheckRealTime();
        w += EnterStreet(0, !Street.direction);
      }
    } else if (Street.street_scheduling == 2) {  // Time
      current_time = time(NULL);
      if (difftime(current_time, start_time) >= (float)Street.time) {
        YellowStreet();  // Esperar a que el street se vacie
        Street.direction = !Street.direction;
        start_time = time(NULL);
      } else {
        CheckRealTime();
        EnterStreet(0, !Street.direction);
      }
    } else if (Street.street_scheduling == 3) {  // Modo FIFO
      // Determinar si hay vehículos esperando
    if (left_street.capacity == 0 && right_street.capacity == 0) {
        // No hay vehículos esperando, no hacemos nada
        usleep(1000);
    } else if (left_street.capacity > 0 && right_street.capacity == 0) {
        // Solo hay vehículos en la izquierda
        if (Street.direction) {  // Ya estamos en dirección derecha (->), los vehículos entran desde la izquierda
            CheckRealTime();
            EnterStreet(0, false);  // false para left_street
        } else {  // Necesitamos cambiar a dirección derecha
            YellowStreet();
            Street.direction = true;  // Cambiar a dirección derecha (->)
        }
    } else if (right_street.capacity > 0 && left_street.capacity == 0) {
        // Solo hay vehículos en la derecha
        if (!Street.direction) {  // Ya estamos en dirección izquierda (<-), los vehículos entran desde la derecha
            CheckRealTime();
            EnterStreet(0, true);  // true para right_street
        } else {  // Necesitamos cambiar a dirección izquierda
            YellowStreet();
            Street.direction = false;  // Cambiar a dirección izquierda (<-)
        }
    } else {
        // Hay vehículos en ambas direcciones, aplicar FIFO
        // Como alternativa simplificada, usamos los IDs para aproximar el orden de llegada
        int left_id = left_street.waiting[0].ID;
        int right_id = right_street.waiting[0].ID;
        
        if (left_id < right_id) {  // El de la izquierda llegó primero
            if (Street.direction) {  // Ya estamos en dirección derecha (->)
                CheckRealTime();
                EnterStreet(0, false);  // false para left_street
            } else {  // Necesitamos cambiar a dirección derecha
                YellowStreet();
                Street.direction = true;  // Cambiar a dirección derecha (->)
            }
        } else {  // El de la derecha llegó primero
            if (!Street.direction) {  // Ya estamos en dirección izquierda (<-)
                CheckRealTime();
                EnterStreet(0, true);  // true para right_street
            } else {  // Necesitamos cambiar a dirección izquierda
                YellowStreet();
                Street.direction = false;  // Cambiar a dirección izquierda (<-)
            }
        }
    }
    } else {
      printf("Error en la seleccion de scheduler\n");
      Street.running = false;
    }
    usleep(1000);  // Revision cada mili segundo
  }
}

void YellowStreet() {
  Street.Yellowlight = true;
  while (Street.Yellowlight && Street.running) {
    if (Street.cars_in == 0) {
      Street.Yellowlight = false;
    }
    if (Street.thread_scheduling == 4) {
      Street.RRiter++;
      if (QUANTUM_mSEC < Street.RRiter) {
        Street.RRiter = 0;
        Street_RR();
        scheduler(Street.thread_scheduling, right_street.waiting, right_street.capacity,
                 emptycar);
        scheduler(Street.thread_scheduling, left_street.waiting, left_street.capacity,
                 emptycar);
      }
    }
    CheckRealTime();

    usleep(1000);
  }
}

int EnterStreet(int Waitpos, bool queue) {
  int newposition = (Street.direction) ? (0) : (Street.size - 1);
  if (Street.street[newposition].ID != -1) {  // La posicion incial esta ocupada
    return 0;
  } else if (!Street.direction && right_street.capacity == 0) {
    return 0;
  } else if (Street.direction && left_street.capacity == 0) {
    return 0;
  } else {
    CEmutex_lock(&street_mutex);
    car newcar = GetEnterCar(Waitpos, queue);
    newcar.position = newposition;
    if (Street.cars_in == 0) {
      Street.RRID = newcar.ID;
      newcar.Permission = true;
    }
    Street.street[newcar.position] = newcar;
    Street.cars_in++;

    streetcontent();
    CEmutex_unlock(&street_mutex);
    if (CEthread_create(&Street.street[newcar.position].thread,
                        (void *)&carmover, (void *)NULL) != 0) {
      fprintf(stderr, "Error al crear el hilo\n");
      return 0;
    }
    return 1;
  }
}

car GetEnterCar(int index, bool queue) {
  if (queue) {
    car newCar = right_street.waiting[index];
    for (int i = index + 1; i < right_street.capacity; i++) {
      right_street.waiting[i - 1] =
          right_street.waiting[i];  // Corrimiento de los carros en espera
    }
    right_street.capacity--;
    right_street.waiting[right_street.capacity] =
        emptycar;  // Borrado del ultimo carro
    return newCar;
  } else {
    car newCar = left_street.waiting[index];
    for (int i = index + 1; i < left_street.capacity; i++) {
      left_street.waiting[i - 1] =
          left_street.waiting[i];  // Corrimiento de los carros en espera
    }
    left_street.capacity--;
    left_street.waiting[left_street.capacity] = emptycar;  // Borrado del ultimo
                                                      // carro
    return newCar;
  }
}

car GetSlowestCar() {
  car Cariter, SlowestCar;
  SlowestCar = emptycar;

  for (int i = 0; i < Street.size; i++) {
    Cariter = Street.street[i];
    if (Cariter.ID == -1) {  // No tomo en cuanta los espacios vacios
      continue;
    }
    if (SlowestCar.tiempo_restante < Cariter.tiempo_restante) {
      SlowestCar = Cariter;
    }
  }
  // printf("Slowcar: %f\n", SlowestCar.tiempo_restante);

  return SlowestCar;
}

void Street_RR() {
  CEmutex_lock(&street_mutex);
  int firstcar = -1;
  int Quantumended = Street.size;  // Me aseguro de minimo recorrer todo el street
  for (int i = 0; i < Street.size; i++) {
    if (Street.street[i].ID == -1) {  // No se toman en cuenta carros nulos
      continue;
    }
    if (firstcar == -1) {  // Se toma nota del primer carro por si acaso se dio
                            // vuelta al street de permisos
      firstcar = i;
    }
    if (Street.street[i].ID ==
        Street.RRID) {  // Es el carro que se le acabo el quantum
      // printf("Quantum ended for %d in position %d\n", Street.RRID, i);
      Street.street[i].Permission = false;
      Quantumended = i;
    }
    if (Quantumended < i) {  // Es el proximo en tener el quantum
      Street.street[i].Permission = true;
      Street.RRID = Street.street[i].ID;
      // printf("Quantum granted to %d in position %d\n", Street.RRID, i);
      CEmutex_unlock(&street_mutex);
      return;
    }
  }
  if (firstcar == -1) {  // No cars in the street
    Street.RRID = -2;
    CEmutex_unlock(&street_mutex);
    return;
  }
  Street.street[firstcar].Permission = true;
  Street.RRID = Street.street[firstcar].ID;
  CEmutex_unlock(&street_mutex);
}

void CheckRealTime() {
  if (Street.thread_scheduling ==
      5) {  
    if (Street.Yellowlight) {
      if (right_street.capacity != 0 || left_street.capacity != 0) {
        Street.TiempoReal = false;
      }
    }
    if (Street.direction) {  
      if (right_street.capacity !=
          0) {  
        Street.TiempoReal = false;
      }
    } else {  
      if (left_street.capacity !=
          0) {  
        Street.TiempoReal = false;
      }
    }
  }
}