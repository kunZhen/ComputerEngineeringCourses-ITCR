#!/usr/bin/env python3
"""
Script de debug detallado para diagnosticar el sistema completo
Investiga por qué solo devuelve 1/8 bytes en resultados
"""

import serial
import time
import sys

def hex_format(data):
    """Formato hexadecimal legible"""
    if isinstance(data, int):
        return f"{data:02X}"
    elif isinstance(data, bytes):
        return ' '.join(f"{b:02X}" for b in data)
    else:
        return f"{ord(data):02X}"

def send_command_detailed(ser, cmd, description, timeout=2.0):
    """Envía comando y analiza respuesta detalladamente"""
    print(f"\n--- {description} ---")
    
    # Limpiar buffer
    ser.flushInput()
    ser.flushOutput()
    time.sleep(0.1)
    
    # Enviar comando
    print(f"→ Enviando: {hex_format(cmd)} ('{chr(cmd)}')")
    ser.write(bytes([cmd]))
    
    # Recibir respuesta con timeout
    start_time = time.time()
    received_bytes = []
    
    while (time.time() - start_time) < timeout:
        if ser.in_waiting > 0:
            byte_data = ser.read(1)
            if byte_data:
                received_bytes.append(byte_data[0])
                print(f"← Recibido byte {len(received_bytes)}: {hex_format(byte_data[0])} ('{chr(byte_data[0]) if 32 <= byte_data[0] <= 126 else '?'}')")
                
                # Para comandos que esperan 1 solo byte
                if cmd in [0x50, 0x3F, 0x53]:  # P, ?, S
                    break
                    
                # Para comando R, esperar hasta 8 bytes o timeout de 1s sin nuevos datos
                if cmd == 0x52:  # R
                    last_byte_time = time.time()
                    
                    # Esperar más bytes con timeout corto
                    while (time.time() - last_byte_time) < 0.5 and len(received_bytes) < 8:
                        if ser.in_waiting > 0:
                            byte_data = ser.read(1)
                            if byte_data:
                                received_bytes.append(byte_data[0])
                                print(f"← Recibido byte {len(received_bytes)}: {hex_format(byte_data[0])} ('{chr(byte_data[0]) if 32 <= byte_data[0] <= 126 else '?'}')")
                                last_byte_time = time.time()
                        time.sleep(0.01)
                    break
        time.sleep(0.01)
    
    if not received_bytes:
        print("❌ No se recibió respuesta")
        return None
    
    print(f"📊 Total recibido: {len(received_bytes)} bytes: {hex_format(bytes(received_bytes))}")
    return received_bytes

def analyze_results_bytes(data_bytes):
    """Analiza los bytes de resultados recibidos"""
    print(f"\n🔍 ANÁLISIS DE RESULTADOS:")
    print(f"Bytes totales: {len(data_bytes)}")
    
    if len(data_bytes) >= 4:
        # Interpretar como MAC operations (little endian)
        mac_ops = (data_bytes[3] << 24) | (data_bytes[2] << 16) | (data_bytes[1] << 8) | data_bytes[0]
        print(f"MAC Operations: {mac_ops:,}")
        
    if len(data_bytes) >= 8:
        # Interpretar como Processing Cycles (little endian)
        cycles = (data_bytes[7] << 24) | (data_bytes[6] << 16) | (data_bytes[5] << 8) | data_bytes[4]
        print(f"Processing Cycles: {cycles:,}")
        
        if cycles > 0:
            print(f"Throughput: {mac_ops/cycles:.3f} MAC/cycle")
    else:
        print("⚠️ Datos incompletos para análisis completo")

def detailed_system_test():
    """Test detallado del sistema completo"""
    
    print("🔬 TEST DETALLADO DEL SISTEMA IMAGE PROCESSOR")
    print("=" * 60)
    
    # Configurar puerto serie
    port = input("Puerto serie (Enter para COM18): ").strip()
    if not port:
        port = "COM18"
    
    try:
        # Conectar con timeout más largo
        ser = serial.Serial(port, 9600, timeout=1)
        time.sleep(2)  # Dar tiempo para estabilización
        print(f"✅ Conectado a {port}")
        
        print(f"\n🔬 INICIANDO DIAGNÓSTICO DETALLADO")
        print("=" * 60)
        
        # Test 1: Ping básico
        ping_response = send_command_detailed(ser, 0x50, "TEST 1: PING")
        if not ping_response or ping_response[0] != 0x4F:
            print("❌ Ping failed")
            return
        
        # Test 2: Verificar que no es sistema debug
        echo_response = send_command_detailed(ser, 0x58, "TEST 2: VERIFICAR NO-ECHO")
        if echo_response and echo_response[0] == 0x58:
            print("❌ Sistema aún en modo debug (hace echo)")
            return
        elif echo_response and echo_response[0] == 0x45:
            print("✅ Sistema completo confirmado (responde ERROR a comando inválido)")
        
        # Test 3: Estado inicial
        status_response = send_command_detailed(ser, 0x3F, "TEST 3: ESTADO INICIAL")
        if status_response:
            if status_response[0] == 0x41:    # A
                print("📊 Estado: IDLE (listo para procesar)")
            elif status_response[0] == 0x42:  # B  
                print("📊 Estado: BUSY (procesando)")
            elif status_response[0] == 0x44:  # D
                print("📊 Estado: DONE (procesamiento terminado)")
            else:
                print(f"📊 Estado desconocido: {hex_format(status_response[0])}")
        
        # Test 4: Comando Start múltiples veces para ver comportamiento
        print(f"\n🔄 TEST 4: MÚLTIPLES COMANDOS START")
        for i in range(3):
            print(f"\n--- Intento {i+1} ---")
            start_response = send_command_detailed(ser, 0x53, f"START #{i+1}")
            
            # Verificar estado inmediatamente después
            time.sleep(0.1)
            status_response = send_command_detailed(ser, 0x3F, f"ESTADO POST-START #{i+1}")
            
            # Esperar un poco más
            time.sleep(1.0)
            final_status = send_command_detailed(ser, 0x3F, f"ESTADO FINAL #{i+1}")
        
        # Test 5: Solicitar resultados con análisis detallado
        print(f"\n📊 TEST 5: SOLICITAR RESULTADOS DETALLADO")
        results_response = send_command_detailed(ser, 0x52, "SOLICITAR RESULTADOS", timeout=5.0)
        
        if results_response:
            analyze_results_bytes(results_response)
            
            # Si solo recibimos 1 byte, intentar solicitar más veces
            if len(results_response) < 8:
                print(f"\n🔁 INTENTOS ADICIONALES (recibido {len(results_response)}/8 bytes)")
                
                for attempt in range(3):
                    print(f"\n--- Intento adicional {attempt + 1} ---")
                    time.sleep(0.5)
                    additional_response = send_command_detailed(ser, 0x52, f"RESULTADOS INTENTO {attempt + 1}")
                    
                    if additional_response and len(additional_response) > len(results_response):
                        print("✅ Recibidos más bytes!")
                        analyze_results_bytes(additional_response)
                        break
        else:
            print("❌ No se recibieron resultados")
        
        # Test 6: Verificar si hay bytes pendientes en el buffer
        print(f"\n📋 TEST 6: VERIFICAR BUFFER")
        time.sleep(1.0)
        if ser.in_waiting > 0:
            pending_bytes = ser.read(ser.in_waiting)
            print(f"📨 Bytes pendientes en buffer: {hex_format(pending_bytes)}")
        else:
            print("📭 No hay bytes pendientes")
        
        print(f"\n" + "=" * 60)
        print("🔬 DIAGNÓSTICO COMPLETADO")
        
    except serial.SerialException as e:
        print(f"❌ Error de conexión serie: {e}")
    except KeyboardInterrupt:
        print(f"\n⏹️ Test interrumpido por el usuario")
    except Exception as e:
        print(f"❌ Error inesperado: {e}")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("🔌 Desconectado")

if __name__ == "__main__":
    detailed_system_test()