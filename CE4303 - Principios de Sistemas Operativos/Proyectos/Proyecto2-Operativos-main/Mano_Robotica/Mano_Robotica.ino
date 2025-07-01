#include <Servo.h>

Servo servo1;  // Servo en pin 8
Servo servo2;  // Servo en pin 9
Servo servo3;  // Servo en pin 10

int angulo_servo1 = 57; // Angulo inicial para el servo 1
int angulo_servo2 = 130; // Angulo inicial para el servo 2
int angulo_servo3 = 9; // Angulo inicial para el servo 3

int contadorMovimientos = 0;  // Contador global para los movimientos

// Funcion para poner el dedo en la posicion inicial (tecla 'G')
void pos_inicial(){
  angulo_servo1 = 57; // Angulo inicial para el servo 1
  angulo_servo2 = 130; // Angulo inicial para el servo 2
  angulo_servo3 = 9; // Angulo inicial para el servo 3
  contadorMovimientos = 0;
  servo1.write(angulo_servo1);
  servo2.write(angulo_servo2);
  servo3.write(angulo_servo3);
  
  
  }

// Funcion para bajar el dedo y presionar una tecla
void bajar_dedo(int angle) {
  int angle_servo2 = angle - 8;  // Calcular el nuevo ángulo
  
  int currentAngle = servo2.read();  // Obtener el ángulo actual del servo
  int step = (angle_servo2 > currentAngle) ? 1 : -1;  // Determinar la dirección (aumentar o disminuir)

  // Mover el servo gradualmente al nuevo ángulo
  while (currentAngle != angle_servo2) {
    currentAngle += step;  // Aumentar o disminuir el ángulo en cada paso
    servo2.write(currentAngle);  // Mover el servo al nuevo ángulo
    delay(30);  // Esperar un pequeño intervalo antes de mover el servo nuevamente
  }
}

// Funcion para subir el dedo y removerlo de la tecla
void subir_dedo(int angle) {
  int angle_servo2 = angle + 8;  // Calcular el nuevo ángulo al sumar 8 unidades
  
  int currentAngle = servo2.read();  // Obtener el ángulo actual del servo
  int step = (angle_servo2 > currentAngle) ? 1 : -1;  // Determinar la dirección (aumentar o disminuir)

  // Mover el servo gradualmente al nuevo ángulo
  while (currentAngle != angle_servo2) {
    currentAngle += step;  // Aumentar o disminuir el ángulo en cada paso
    servo2.write(currentAngle);  // Mover el servo al nuevo ángulo
    delay(15);  // Esperar un pequeño intervalo antes de mover el servo nuevamente
  }
  delay(30);
}

// Funcion para mover el dedo a la derecha 
void mover_dedo_derecha(int angle) {
  int angle_servo1 = angle - 8;  // Calcular el nuevo ángulo al restar 8 unidades
  
  int currentAngle = servo1.read();  // Obtener el ángulo actual del servo1
  int step = (angle_servo1 > currentAngle) ? 1 : -1;  // Determinar la dirección (aumentar o disminuir)

  // Mover el servo gradualmente al nuevo ángulo
  while (currentAngle != angle_servo1) {
    currentAngle += step;  // Aumentar o disminuir el ángulo en cada paso
    servo1.write(currentAngle);  // Mover el servo1 al nuevo ángulo
    delay(15);  // Esperar un pequeño intervalo antes de mover el servo nuevamente
  }

  contadorMovimientos++;  // Incrementamos el contador por moverse a la derecha

      // Si se ha movido 2S veces a la derecha, ajustamos el ángulo de servo3
      if (contadorMovimientos == 2) {
        angulo_servo3 += 6;  // Sumar 2 unidades al ángulo de servo3
        servo3.write(angulo_servo3);  // Mover el servo3
        Serial.print("Desfase corregido, servo3 a ángulo: ");
        Serial.println(angulo_servo3);
      } 

      else if (contadorMovimientos == 4 || contadorMovimientos == 5){
        angulo_servo2 -= 8;  // Sumar 2 unidades al ángulo de servo2
        servo2.write(angulo_servo2);  // Mover el servo2
        Serial.print("Desfase corregido, servo2 a ángulo: ");
        Serial.println(angulo_servo2);
        angulo_servo3 += 6;  // Sumar 2 unidades al ángulo de servo3
        servo3.write(angulo_servo3);  // Mover el servo3
        Serial.print("Desfase corregido, servo3 a ángulo: ");
        Serial.println(angulo_servo3);
        
        }

      else if (contadorMovimientos == -2 || contadorMovimientos == -3){
        angulo_servo3 -= 4;  // Sumar 2 unidades al ángulo de servo3
        servo3.write(angulo_servo3);  // Mover el servo3
        Serial.print("Desfase corregido, servo3 a ángulo: ");
        Serial.println(angulo_servo3);
          
        }

      Serial.print("Mover a la derecha -> nuevo ángulo: ");
      Serial.println(angulo_servo1);
}

// Funcion para mover dedo a la izquierda
void mover_dedo_izquierda(int angle) {
  int angle_servo1 = angle + 8;  // Calcular el nuevo ángulo al sumar 8 unidades
  
  int currentAngle = servo1.read();  // Obtener el ángulo actual del servo1
  int step = (angle_servo1 > currentAngle) ? 1 : -1;  // Determinar la dirección (aumentar o disminuir)

  // Mover el servo gradualmente al nuevo ángulo
  while (currentAngle != angle_servo1) {
    currentAngle += step;  // Aumentar o disminuir el ángulo en cada paso
    servo1.write(currentAngle);  // Mover el servo1 al nuevo ángulo
    delay(15);  // Esperar un pequeño intervalo antes de mover el servo nuevamente
  }

  contadorMovimientos--;  // Decrementamos el contador por moverse a la izquierda

      // Si se ha movido 2S veces a la derecha, ajustamos el ángulo de servo3
      if (contadorMovimientos == 1) {
        angulo_servo3 -= 6;  // Sumar 2 unidades al ángulo de servo3
        servo3.write(angulo_servo3);  // Mover el servo3
        Serial.print("Desfase corregido, servo3 a ángulo: ");
        Serial.println(angulo_servo3);
       
      } 
       else if (contadorMovimientos == 3 || contadorMovimientos == 4){
        angulo_servo2 += 8;  // Sumar 2 unidades al ángulo de servo2
        delay(40)
;        servo2.write(angulo_servo2);  // Mover el servo2
        Serial.print("Desfase corregido, servo2 a ángulo: ");
        Serial.println(angulo_servo2);
        angulo_servo3 -= 4;  // Sumar 2 unidades al ángulo de servo3
        servo3.write(angulo_servo3);  // Mover el servo3
        Serial.print("Desfase corregido, servo3 a ángulo: ");
        Serial.println(angulo_servo3);
        
        }
      
      else if (contadorMovimientos == -3 || contadorMovimientos == -4){
        angulo_servo3 += 4;  // Sumar 2 unidades al ángulo de servo3
        servo3.write(angulo_servo3);  // Mover el servo3
        Serial.print("Desfase corregido, servo3 a ángulo: ");
        Serial.println(angulo_servo3);
          
        }

      Serial.print("Mover a la izquierda -> nuevo ángulo: ");
      Serial.println(angulo_servo1);
}

// Funcion para mover dedo al siguiente escalon del teclado
void mover_dedo_arriba(int angle) {
  int angle_servo3 = angle + 9;  // Calcular el nuevo ángulo al sumar 9 unidades
  
  int currentAngle = servo3.read();  // Obtener el ángulo actual del servo3
  int step = (angle_servo3 > currentAngle) ? 1 : -1;  // Determinar la dirección (aumentar o disminuir)

  // Mover el servo gradualmente al nuevo ángulo
  while (currentAngle != angle_servo3) {
    currentAngle += step;  // Aumentar o disminuir el ángulo en cada paso
    servo3.write(currentAngle);  // Mover el servo3 al nuevo ángulo
    delay(15);  // Esperar un pequeño intervalo antes de mover el servo nuevamente
  }
}

// Funcion para mover el dedo a un escalon abajo en el teclado
void mover_dedo_abajo(int angle) {
  int angle_servo3 = angle - 9;  // Calcular el nuevo ángulo al restar 9 unidades
  
  int currentAngle = servo3.read();  // Obtener el ángulo actual del servo3
  int step = (angle_servo3 > currentAngle) ? 1 : -1;  // Determinar la dirección (aumentar o disminuir)

  // Mover el servo gradualmente al nuevo ángulo
  while (currentAngle != angle_servo3) {
    currentAngle += step;  // Aumentar o disminuir el ángulo en cada paso
    servo3.write(currentAngle);  // Mover el servo3 al nuevo ángulo
    delay(15);  // Esperar un pequeño intervalo antes de mover el servo nuevamente
  }
}



void setup() {
  Serial.begin(9600);

  servo1.attach(8);
  servo2.attach(9);
  servo3.attach(10);

  servo1.write(angulo_servo1);
  servo2.write(angulo_servo2);
  servo3.write(angulo_servo3);

  Serial.println("Luego escribe R (derecha) o L (izquierda) para ajustar el ángulo.");
}

void loop() {
  if (Serial.available() > 0) {
    char input = toupper(Serial.read());  // Leer el carácter y convertirlo a mayúscula
    
      // Si se recibe 'R' (mover a la derecha)
      if (input == 'R') {
      mover_dedo_derecha(angulo_servo1);  // Usamos la función para mover a la derecha
      angulo_servo1 = angulo_servo1 - 8;  // Actualizamos el ángulo
      
    } 
    // Si se recibe 'L' (mover a la izquierda)
    else if (input == 'L') {
      mover_dedo_izquierda(angulo_servo1);  // Usamos la función para mover a la izquierda
      angulo_servo1 = angulo_servo1 + 10;  // Actualizamos el ángulo
      
    }
    // Si se recibe 'D' (mover hacia abajo)
    else if (input == 'D') {
      bajar_dedo(angulo_servo2);  // Usamos la función para bajar el dedo en servo2
      angulo_servo2 = angulo_servo2 - 8;  // Ajustamos el ángulo de servo2
      Serial.print("Mover hacia abajo -> nuevo ángulo: ");
      Serial.println(angulo_servo2);
    }
    // Si se recibe 'U' (mover hacia arriba)
    else if (input == 'U') {
      subir_dedo(angulo_servo2);  // Usamos la función para subir el dedo en servo2
      angulo_servo2 = angulo_servo2 + 8;  // Ajustamos el ángulo de servo2
      Serial.print("Mover hacia arriba -> nuevo ángulo: ");
      Serial.println(angulo_servo2);
      pos_inicial();
      delay(100);
      
    }
    // Si se recibe 'Q' (mover el dedo hacia arriba en servo3)
    else if (input == 'Q') {
      mover_dedo_arriba(angulo_servo3);  // Llamamos a la función para mover el dedo hacia arriba en servo3
      angulo_servo3 = angulo_servo3 + 9;  // Ajustamos el ángulo de servo3
      Serial.print("Mover el dedo hacia arriba (servo3) -> nuevo ángulo: ");
      Serial.println(angulo_servo3);
    }
    // Si se recibe 'W' (mover el dedo hacia abajo en servo3)
    else if (input == 'W') {
      mover_dedo_abajo(angulo_servo3);  // Llamamos a la función para mover el dedo hacia arriba en servo3
      angulo_servo3 = angulo_servo3 - 9;  // Ajustamos el ángulo de servo3
      Serial.print("Mover el dedo hacia arriba (servo3) -> nuevo ángulo: ");
      Serial.println(angulo_servo3);
      
    }

  }

  delay(15);  // Retardo para la estabilidad del servo
}
