#!/usr/bin/env python3
"""
Script de Prueba para Comunicación FPGA-PC mediante HC-05
Autor: Sistema de Procesamiento de Imágenes
Fecha: 2025

Uso:
    python hc05_test.py [puerto]
    
Ejemplo:
    python hc05_test.py COM8        # Windows
    python hc05_test.py /dev/ttyUSB0 # Linux
"""

import serial
import time
import struct
import sys
import threading
from typing import Optional, Tuple

class HC05Controller:
    """Controlador para comunicación con FPGA via HC-05"""
    
    # Comandos del protocolo
    CMD_START = b'S'      # 0x53
    CMD_STATUS = b'?'     # 0x3F
    CMD_RESULTS = b'R'    # 0x52
    CMD_PING = b'P'       # 0x50
    
    # Respuestas esperadas
    RSP_ACK = b'A'        # 0x41
    RSP_BUSY = b'B'       # 0x42
    RSP_DONE = b'D'       # 0x44
    RSP_ERROR = b'E'      # 0x45
    RSP_PONG = b'O'       # 0x4F
    
    def __init__(self, port: str, baudrate: int = 9600, timeout: float = 2.0):
        """
        Inicializar conexión HC-05
        
        Args:
            port: Puerto serie (ej: 'COM8', '/dev/ttyUSB0')
            baudrate: Velocidad en baudios (default: 9600)
            timeout: Timeout para operaciones serie (segundos)
        """
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.serial_conn: Optional[serial.Serial] = None
        self.connected = False
        
    def connect(self) -> bool:
        """Conectar al HC-05"""
        try:
            self.serial_conn = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=self.timeout,
                xonxoff=False,
                rtscts=False,
                dsrdtr=False
            )
            
            # Esperar a que se establezca la conexión
            time.sleep(2)
            
            # Test de conectividad
            if self.ping():
                self.connected = True
                print(f"✓ Conectado exitosamente a {self.port}")
                return True
            else:
                print("✗ No hay respuesta del dispositivo")
                self.disconnect()
                return False
                
        except serial.SerialException as e:
            print(f"✗ Error de conexión: {e}")
            return False
    
    def disconnect(self):
        """Desconectar del HC-05"""
        if self.serial_conn and self.serial_conn.is_open:
            self.serial_conn.close()
        self.connected = False
        print("Desconectado")
    
    def send_command(self, command: bytes) -> Optional[bytes]:
        """
        Enviar comando y esperar respuesta
        
        Args:
            command: Comando a enviar (1 byte)
            
        Returns:
            Respuesta recibida o None si hay error
        """
        if not self.connected or not self.serial_conn:
            print("✗ No conectado")
            return None
            
        try:
            # Limpiar buffer de entrada
            self.serial_conn.reset_input_buffer()
            
            # Enviar comando
            self.serial_conn.write(command)
            print(f"→ Enviado: {command.hex().upper()}")
            
            # Esperar respuesta
            response = self.serial_conn.read(1)
            if len(response) == 1:
                print(f"← Recibido: {response.hex().upper()}")
                return response
            else:
                print("✗ Timeout - sin respuesta")
                return None
                
        except serial.SerialException as e:
            print(f"✗ Error de comunicación: {e}")
            return None
    
    def ping(self) -> bool:
        """Test de conectividad (Ping)"""
        print("\n--- TEST PING ---")
        response = self.send_command(self.CMD_PING)
        success = response == self.RSP_PONG
        print(f"Resultado: {'✓ PONG' if success else '✗ Sin respuesta'}")
        return success
    
    def start_processing(self) -> bool:
        """Iniciar procesamiento de imagen"""
        print("\n--- INICIAR PROCESAMIENTO ---")
        response = self.send_command(self.CMD_START)
        
        if response == self.RSP_ACK:
            print("✓ Procesamiento iniciado")
            return True
        elif response == self.RSP_BUSY:
            print("⚠ Sistema ocupado - procesando")
            return False
        else:
            print("✗ Error al iniciar procesamiento")
            return False
    
    def get_status(self) -> str:
        """Consultar estado del sistema"""
        response = self.send_command(self.CMD_STATUS)
        
        if response == self.RSP_ACK:
            return "IDLE"
        elif response == self.RSP_BUSY:
            return "PROCESSING"
        elif response == self.RSP_DONE:
            return "DONE"
        elif response == self.RSP_ERROR:
            return "ERROR"
        else:
            return "UNKNOWN"
    
    def wait_for_completion(self, max_wait: int = 60) -> bool:
        """
        Esperar a que termine el procesamiento
        
        Args:
            max_wait: Tiempo máximo de espera (segundos)
            
        Returns:
            True si terminó exitosamente, False si timeout
        """
        print("\n--- ESPERANDO FINALIZACIÓN ---")
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            status = self.get_status()
            print(f"Estado: {status}")
            
            if status == "DONE":
                print("✓ Procesamiento completado")
                return True
            elif status == "ERROR":
                print("✗ Error en procesamiento")
                return False
            elif status == "IDLE":
                print("⚠ Sistema inactivo - posible error")
                return False
            
            time.sleep(1)  # Esperar 1 segundo antes de consultar nuevamente
        
        print("✗ Timeout esperando finalización")
        return False
    
    def get_results(self) -> Optional[Tuple[int, int]]:
        """
        Obtener resultados del procesamiento
        
        Returns:
            Tupla (mac_operations, processing_cycles) o None si hay error
        """
        print("\n--- OBTENER RESULTADOS ---")
        
        # Verificar que esté listo
        if self.get_status() != "DONE":
            print("✗ Procesamiento no completado")
            return None
        
        try:
            # Limpiar buffer
            self.serial_conn.reset_input_buffer()
            
            # Enviar comando de resultados
            self.serial_conn.write(self.CMD_RESULTS)
            print(f"→ Comando resultados enviado")
            
            # Leer 8 bytes (2 valores de 32 bits)
            result_data = self.serial_conn.read(8)
            
            if len(result_data) == 8:
                # Desempaquetar datos (little-endian)
                mac_ops = struct.unpack('<I', result_data[0:4])[0]
                cycles = struct.unpack('<I', result_data[4:8])[0]
                
                print(f"✓ Operaciones MAC: {mac_ops:,}")
                print(f"✓ Ciclos de procesamiento: {cycles:,}")
                
                if cycles > 0:
                    throughput = mac_ops / cycles
                    print(f"✓ Throughput: {throughput:.2f} MAC/ciclo")
                
                return (mac_ops, cycles)
            else:
                print(f"✗ Datos incompletos: {len(result_data)}/8 bytes")
                return None
                
        except Exception as e:
            print(f"✗ Error obteniendo resultados: {e}")
            return None

def print_banner():
    """Mostrar banner del programa"""
    print("="*60)
    print("    FPGA Image Processor - Test de Comunicación HC-05")
    print("="*60)

def print_menu():
    """Mostrar menú de opciones"""
    print("\n--- MENÚ DE OPCIONES ---")
    print("1. Test de conectividad (Ping)")
    print("2. Consultar estado")
    print("3. Iniciar procesamiento")
    print("4. Esperar finalización")
    print("5. Obtener resultados")
    print("6. Procesamiento completo (automático)")
    print("7. Monitor continuo de estado")
    print("0. Salir")
    print("-" * 25)

def monitor_status(controller: HC05Controller, duration: int = 30):
    """Monitor continuo de estado"""
    print(f"\n--- MONITOR DE ESTADO ({duration}s) ---")
    start_time = time.time()
    
    try:
        while time.time() - start_time < duration:
            status = controller.get_status()
            timestamp = time.strftime("%H:%M:%S")
            print(f"[{timestamp}] Estado: {status}")
            time.sleep(2)
    except KeyboardInterrupt:
        print("\nMonitor interrumpido por usuario")

def automatic_processing(controller: HC05Controller):
    """Ejecutar procesamiento completo automático"""
    print("\n=== PROCESAMIENTO AUTOMÁTICO ===")
    
    # 1. Verificar conexión
    if not controller.ping():
        return False
    
    # 2. Iniciar procesamiento
    if not controller.start_processing():
        return False
    
    # 3. Esperar finalización
    if not controller.wait_for_completion(max_wait=120):
        return False
    
    # 4. Obtener resultados
    results = controller.get_results()
    if results:
        print("\n🎉 Procesamiento completado exitosamente!")
        return True
    else:
        print("\n❌ Error obteniendo resultados")
        return False

def main():
    """Función principal"""
    print_banner()
    
    # Obtener puerto serie
    if len(sys.argv) > 1:
        port = sys.argv[1]
    else:
        port = input("Ingrese el puerto serie (ej: COM8, /dev/ttyUSB0): ").strip()
        if not port:
            print("Puerto no válido")
            return
    
    # Crear controlador
    controller = HC05Controller(port)
    
    # Conectar
    if not controller.connect():
        return
    
    try:
        # Menú principal
        while True:
            print_menu()
            choice = input("Seleccione una opción: ").strip()
            
            if choice == '0':
                break
            elif choice == '1':
                controller.ping()
            elif choice == '2':
                status = controller.get_status()
                print(f"Estado actual: {status}")
            elif choice == '3':
                controller.start_processing()
            elif choice == '4':
                controller.wait_for_completion()
            elif choice == '5':
                controller.get_results()
            elif choice == '6':
                automatic_processing(controller)
            elif choice == '7':
                duration = int(input("Duración del monitor (segundos): ") or "30")
                monitor_status(controller, duration)
            else:
                print("Opción no válida")
                
    except KeyboardInterrupt:
        print("\nPrograma interrumpido por usuario")
    finally:
        controller.disconnect()

if __name__ == "__main__":
    main()