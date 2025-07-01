#!/usr/bin/env python3
"""
Script de Debug Avanzado para HC-05
Ayuda a identificar problemas de comunicación paso a paso
"""

import serial
import time
import sys
from serial.tools import list_ports

def list_serial_ports():
    """Listar todos los puertos serie disponibles"""
    print("\n=== PUERTOS SERIE DISPONIBLES ===")
    ports = list_ports.comports()
    
    if not ports:
        print("❌ No se encontraron puertos serie")
        return []
    
    for i, port in enumerate(ports):
        print(f"{i+1}. {port.device} - {port.description}")
        if "Bluetooth" in port.description:
            print(f"   ✅ Puerto Bluetooth detectado")
    
    return [port.device for port in ports]

def test_port_basic(port_name):
    """Test básico de apertura de puerto"""
    print(f"\n=== TEST BÁSICO PUERTO {port_name} ===")
    
    try:
        ser = serial.Serial(
            port=port_name,
            baudrate=9600,
            bytesize=8,
            parity='N',
            stopbits=1,
            timeout=1
        )
        
        print(f"✅ Puerto abierto exitosamente")
        print(f"   - Baudrate: {ser.baudrate}")
        print(f"   - Timeout: {ser.timeout}")
        print(f"   - Is Open: {ser.is_open}")
        
        ser.close()
        return True
        
    except Exception as e:
        print(f"❌ Error abriendo puerto: {e}")
        return False

def test_loopback(port_name):
    """Test de loopback (si tienes jumper TX-RX)"""
    print(f"\n=== TEST LOOPBACK {port_name} ===")
    print("Conecta un jumper entre TX y RX del HC-05 para este test")
    input("Presiona Enter cuando esté listo...")
    
    try:
        ser = serial.Serial(port_name, 9600, timeout=2)
        
        test_data = [b'A', b'U', b'P', b'?', b'S']
        success_count = 0
        
        for data in test_data:
            ser.reset_input_buffer()
            ser.write(data)
            print(f"→ Enviado: {data.decode()}")
            
            response = ser.read(1)
            if response == data:
                print(f"✅ Echo correcto: {response.decode()}")
                success_count += 1
            else:
                print(f"❌ Echo incorrecto: esperado {data.hex()}, recibido {response.hex()}")
        
        ser.close()
        
        if success_count == len(test_data):
            print("✅ Loopback test EXITOSO - HC-05 funciona")
            return True
        else:
            print(f"⚠️ Loopback parcial: {success_count}/{len(test_data)}")
            return False
            
    except Exception as e:
        print(f"❌ Error en loopback test: {e}")
        return False

def test_fpga_simple(port_name):
    """Test simplificado con FPGA"""
    print(f"\n=== TEST FPGA SIMPLE {port_name} ===")
    
    try:
        ser = serial.Serial(port_name, 9600, timeout=3)
        
        # Test múltiples comandos con timeouts diferentes
        commands = [
            (b'P', "Ping"),
            (b'?', "Status"),
            (b'S', "Start"),
            (b'A', "Arbitrary")
        ]
        
        for cmd, name in commands:
            print(f"\n--- Test {name} ---")
            ser.reset_input_buffer()
            
            # Enviar comando
            ser.write(cmd)
            print(f"→ Enviado: {cmd.hex().upper()} ('{cmd.decode()}')")
            
            # Esperar respuesta con timeout progresivo
            for timeout_ms in [100, 500, 1000, 2000]:
                ser.timeout = timeout_ms / 1000
                response = ser.read(1)
                
                if response:
                    print(f"✅ Respuesta en {timeout_ms}ms: {response.hex().upper()} ('{response.decode() if response.isalpha() else '?'}')")
                    break
            else:
                print(f"❌ Sin respuesta después de 2000ms")
            
            time.sleep(0.5)  # Pausa entre comandos
        
        ser.close()
        
    except Exception as e:
        print(f"❌ Error en test FPGA: {e}")

def test_continuous_listen(port_name, duration=10):
    """Escuchar puerto continuamente"""
    print(f"\n=== ESCUCHA CONTINUA {port_name} ({duration}s) ===")
    print("Esperando cualquier dato de la FPGA...")
    
    try:
        ser = serial.Serial(port_name, 9600, timeout=0.1)
        start_time = time.time()
        byte_count = 0
        
        while time.time() - start_time < duration:
            data = ser.read(1)
            if data:
                byte_count += 1
                print(f"[{time.time()-start_time:.1f}s] Byte #{byte_count}: {data.hex().upper()} ('{data.decode() if data.isalpha() else '?'}')")
        
        ser.close()
        
        if byte_count == 0:
            print("❌ No se recibieron datos")
        else:
            print(f"✅ Se recibieron {byte_count} bytes")
            
    except Exception as e:
        print(f"❌ Error en escucha continua: {e}")

def test_send_continuous(port_name, duration=10):
    """Enviar datos continuamente"""
    print(f"\n=== ENVÍO CONTINUO {port_name} ({duration}s) ===")
    print("Enviando comandos Ping cada segundo...")
    
    try:
        ser = serial.Serial(port_name, 9600, timeout=0.5)
        start_time = time.time()
        ping_count = 0
        
        while time.time() - start_time < duration:
            ping_count += 1
            ser.write(b'P')
            print(f"[{time.time()-start_time:.1f}s] Ping #{ping_count} enviado")
            
            # Verificar si hay respuesta
            response = ser.read(1)
            if response:
                print(f"    ✅ Respuesta: {response.hex().upper()}")
            
            time.sleep(1)
        
        ser.close()
        print(f"📤 Total pings enviados: {ping_count}")
        
    except Exception as e:
        print(f"❌ Error en envío continuo: {e}")

def main():
    """Función principal de debug"""
    print("🔧 HERRAMIENTA DE DEBUG HC-05 + FPGA 🔧")
    print("="*50)
    
    # Listar puertos disponibles
    available_ports = list_serial_ports()
    
    if not available_ports:
        print("No hay puertos disponibles. Verifica:")
        print("1. HC-05 esté encendido")
        print("2. HC-05 esté emparejado con Windows")
        print("3. Drivers Bluetooth instalados")
        return
    
    # Seleccionar puerto
    if len(sys.argv) > 1:
        port = sys.argv[1]
    else:
        print(f"\nPuerto detectado automáticamente: {available_ports}")
        port = input(f"Ingresa puerto (Enter para {available_ports[0]}): ").strip()
        if not port:
            port = available_ports[0]
    
    print(f"\n🎯 Usando puerto: {port}")
    
    # Menú de tests
    while True:
        print("\n" + "="*40)
        print("MENÚ DE DEBUG")
        print("="*40)
        print("1. Test básico de puerto")
        print("2. Test loopback HC-05 (requiere jumper)")
        print("3. Test simple con FPGA")
        print("4. Escucha continua (10s)")
        print("5. Envío continuo (10s)")
        print("6. Test completo automático")
        print("0. Salir")
        
        choice = input("\nSelecciona opción: ").strip()
        
        if choice == '0':
            break
        elif choice == '1':
            test_port_basic(port)
        elif choice == '2':
            test_loopback(port)
        elif choice == '3':
            test_fpga_simple(port)
        elif choice == '4':
            test_continuous_listen(port)
        elif choice == '5':
            test_send_continuous(port)
        elif choice == '6':
            # Test completo
            print("\n🚀 EJECUTANDO TESTS AUTOMÁTICOS...")
            test_port_basic(port)
            test_fpga_simple(port)
            test_continuous_listen(port, 5)
        else:
            print("❌ Opción inválida")

if __name__ == "__main__":
    main()