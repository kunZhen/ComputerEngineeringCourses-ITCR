# Proyecto1-Operativos

## Requisitos previos
- CMake (versión 3.16 o superior)
- Compilador C compatible con C11
- Git (opcional - para clonar el repositorio)

## Pasos para compilar y ejecutar

### 1. Clonar el repositorio (si aún no lo has hecho)

```bash
git clone https://github.com/EmilioTec10/Proyecto1-Operativos.git
cd Proyecto1-Operativos
```

### 2. Crear el directorio de compilación y navegar a él

```bash
mkdir -p build
cd build
```

### 3. Generar los archivos de compilación con CMake

```bash
cmake ..
```

### 4. Compilar el proyecto
```bash
make
```

```bash
cd bin
```

```bash
cd ./schedulingCars
```

## Configurar el Modo Equidad W

### 1. Modo W con FCFS (t_schedule=1)

```bash
c_schedule=1  # Modo W
W=2           # 2 vehículos cruzan antes de cambiar dirección
t_schedule=1  # FCFS
```

Comportamiento esperado:

Los vehículos entraran a la calle en el orden exacto en que llegaron a la cola de espera
Después de que 2 vehículos hayan cruzado, la dirección cambiará
Si hay ambulancias, tendrán prioridad (debido a la función adjustPatrol)

### 2. Modo W con SJF (t_schedule=2)

```bash
c_schedule=1  # Modo W
W=2           # 2 vehículos cruzan antes de cambiar dirección
t_schedule=2  # SJF
```

Los vehículos con menor tiempo de cruce (generalmente los más rápidos) entrarán primero
Los vehículos deportivos entrarán antes que los normales debido a su mayor velocidad
Después de que 2 vehículos hayan cruzado, la dirección cambiará
Las ambulancias siguen teniendo prioridad sobre todos, independientemente de su velocidad

### 3. Modo W con Prioridad (t_schedule=3)

```bash
c_schedule=1  # Modo W
W=2           # 2 vehículos cruzan antes de cambiar dirección
t_schedule=3  # Prioridad
```

Comportamiento esperado:

Los vehículos se ordenan por tipo: Ambulancias (3) → Deportivos (2) → Normales (1)
Después de que 2 vehículos hayan cruzado, la dirección cambiará
Este modo garantiza explícitamente que las ambulancias tienen la máxima prioridad

### 4. Modo W con Round Robin (t_schedule=4)

```bash
c_schedule=1  # Modo W
W=2           # 2 vehículos cruzan antes de cambiar dirección
t_schedule=4  # Round Robin
```

Comportamiento esperado:

Los vehículos entran a la calle en orden rotativo, dando oportunidad a cada uno
Una vez dentro de la calle, cada vehículo recibe un quantum de tiempo para moverse
Después de que 2 vehículos hayan cruzado, la dirección cambiará
Las ambulancias siguen teniendo prioridad por la función adjustPatrol
La variable QUANTUM_mSEC (definida como 3000) determina el tiempo que cada vehículo puede moverse antes de ceder el turno

### 5. Modo W con Tiempo Real (t_schedule=5)

Garantías estrictas: El sistema es de "tiempo real duro" (hard real-time), ya que cualquier retraso se considera un fallo (se establece TiempoReal = false).
Condiciones para tiempo real:

- No debe haber más de un vehículo esperandor
- El vehículo esperando debe poder cruzar antes de que termine el vehículo más lento en la calle
- No debe haber vehículos esperando en la dirección opuesta durante el cambio de luz
- No debe haber bloqueos en la calle (un vehículo impedido para avanzar)


Indicador de estado: El flag Street.TiempoReal actúa como un indicador que muestra si el sistema ha logrado mantener sus garantías de tiempo real hasta el momento.

```bash
c_schedule=1  # Modo W
W=2           # 2 vehículos cruzan antes de cambiar dirección
t_schedule=5  # Tiempo Real
```

Comportamiento esperado:

El sistema verifica si los vehículos pueden cumplir con sus plazos de entrega
Solo permite la entrada de vehículos que puedan cruzar la calle dentro del tiempo permitido
Si hay más de un vehículo en la cola, se considera que no se puede cumplir con tiempo real
Después de que 2 vehículos hayan cruzado, la dirección cambiará
La variable Street.TiempoReal se establece en false si no se cumplen las condiciones de tiempo real

## Configurar el Modo Letrero

### 1. Modo Time con FCFS (t_schedule=1)

```bash
c_schedule=2  # Modo Time
time=10       # 10 segundos antes de cambiar dirección
t_schedule=1  # FCFS
```

Comportamiento esperado:

Los vehículos entrarán a la calle en el orden exacto en que llegaron a la cola de espera.
Después de 10 segundos, independientemente de cuántos vehículos hayan entrado, la dirección cambiará.
Si hay ambulancias, tendrán prioridad debido a la función adjustPatrol() que se ejecuta al final de cualquier algoritmo de planificación.
Durante los 10 segundos, entrarán tantos vehículos como sea posible en orden FCFS.

### 2. Modo Time con SJF (t_schedule=2)

```bash
c_schedule=2  # Modo Time
time=10       # 10 segundos antes de cambiar dirección
t_schedule=2  # SJF
```

Comportamiento esperado:

Los vehículos con menor tiempo de cruce (los más rápidos) entrarán primero a la calle.
Después de 10 segundos, independientemente de cuántos vehículos hayan entrado, la dirección cambiará.
Durante los 10 segundos, el sistema intentará maximizar el número de vehículos que pueden cruzar priorizando los más rápidos.
Las ambulancias siguen teniendo prioridad absoluta debido a adjustPatrol().

### 3. Modo Time con Prioridad (t_schedule=3)

```bash
c_schedule=2  # Modo Time
time=10       # 10 segundos antes de cambiar dirección
t_schedule=3  # Prioridad
```

Comportamiento esperado:

Los vehículos se ordenarán por tipo: Ambulancias (3) → Deportivos (2) → Normales (1).
Después de 30 segundos, independientemente del estado de las colas, la dirección cambiará.
Durante los 30 segundos, todos los vehículos de mayor prioridad cruzarán antes que cualquiera de menor prioridad.


### 4. Modo Time con Round Robin (t_schedule=4)

```bash
c_schedule=2  # Modo Time
time=10       # 10 segundos antes de cambiar dirección
t_schedule=4  # Round Robin
```

Comportamiento esperado:

Los vehículos entrarán a la calle en orden rotativo, dando oportunidad a cada uno.
Una vez dentro de la calle, cada vehículo recibirá un quantum de tiempo (QUANTUM_mSEC, definido como 3000 ms) para moverse.
Después de 30 segundos, la dirección cambiará independientemente de cuántos vehículos hayan cruzado.
La variable Street.RRiter se incrementa con cada ciclo, y cuando supera QUANTUM_mSEC, se ejecuta Street_RR() para alternar el permiso entre vehículos.

### 5. Modo Time con Tiempo Real (t_schedule=5)
```bash
c_schedule=2  # Modo Time
time=10       # 10 segundos antes de cambiar dirección
t_schedule=5  # Tiempo Real
```

Comportamiento esperado:

El sistema verifica si los vehículos pueden cumplir con sus plazos de entrega antes de permitirles entrar.
Solo se permite la entrada de vehículos que puedan cruzar la calle dentro del tiempo permitido.
Después de 30 segundos, la dirección cambiará, independientemente de si todos los vehículos han podido cruzar.
La variable Street.TiempoReal se establece en false si no se pueden cumplir las restricciones de tiempo real.

## Configurar el Modo FIFO