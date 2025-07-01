#!/usr/bin/env python3
"""
Test simple para verificar los 8 bytes del fix
Usa la misma base que robust_results_test.py que funciona
"""

import serial
import time

def simple_8byte_test():
    port = input("Puerto (Enter para COM18): ").strip() or "COM18"
    
    try:
        ser = serial.Serial(port, 9600, timeout=2)  # Mismo timeout que scripts que funcionan
        time.sleep(1)
        print(f"✅ Conectado a {port}")
        
        # Ping test (igual que los otros scripts)
        ser.write(b'P')
        ping_response = ser.read(1)
        if ping_response != b'O':
            print("❌ Ping failed")
            return
        print("✅ Ping OK")
        
        print("\n🎯 TEST DE 8 BYTES POST-FIX")
        print("=" * 40)
        print("⚠️ OBSERVA LEDR[7] - debe parpadear")
        print("=" * 40)
        
        # Test usando la misma lógica que robust_results_test.py
        def capture_results():
            ser.flushInput()
            ser.write(b'R')
            print("→ Comando R enviado")
            
            received_bytes = []
            start_time = time.time()
            last_byte_time = time.time()
            
            print("← Esperando bytes...")
            
            # Captura igual que robust_results_test.py pero más iteraciones
            while (time.time() - last_byte_time) < 3.0:  # 3 segundos timeout
                if ser.in_waiting > 0:
                    byte_data = ser.read(1)
                    if byte_data:
                        received_bytes.append(byte_data[0])
                        elapsed = time.time() - start_time
                        print(f"   Byte {len(received_bytes)}: 0x{byte_data[0]:02X} ({elapsed*1000:.1f}ms)")
                        last_byte_time = time.time()
                        
                        # Si tenemos 8 bytes, terminar inmediatamente
                        if len(received_bytes) >= 8:
                            print("✅ 8 bytes recibidos!")
                            break
                            
                time.sleep(0.01)  # Polling cada 10ms (igual que robust_results_test.py)
            
            return received_bytes
        
        # Ejecutar test
        bytes_received = capture_results()
        
        # Análisis de resultados
        print(f"\n📊 RESULTADO FINAL:")
        print(f"Bytes recibidos: {len(bytes_received)}/8")
        
        if len(bytes_received) > 0:
            hex_string = ' '.join(f"0x{b:02X}" for b in bytes_received)
            print(f"Datos: {hex_string}")
        
        # Interpretación
        if len(bytes_received) >= 4:
            mac_ops = (bytes_received[3] << 24) | (bytes_received[2] << 16) | (bytes_received[1] << 8) | bytes_received[0]
            print(f"\n📈 MAC Operations: {mac_ops:,}")
            
            if len(bytes_received) >= 8:
                cycles = (bytes_received[7] << 24) | (bytes_received[6] << 16) | (bytes_received[5] << 8) | bytes_received[4]
                print(f"📈 Processing Cycles: {cycles:,}")
                if cycles > 0:
                    print(f"📈 Throughput: {mac_ops/cycles:.3f} MAC/cycle")
        
        # Evaluación
        print(f"\n" + "=" * 40)
        if len(bytes_received) == 8:
            print("🎉 ¡FIX EXITOSO!")
            print("✅ Sistema funciona perfectamente")
        elif len(bytes_received) > 1:
            print("⚡ Fix parcial")
            print(f"✅ Enviando {len(bytes_received)} bytes")
            print("⚠️ Revisar lógica WAIT_TX_COMPLETE")
        else:
            print("❌ Fix no aplicado")
            print("🔧 Usar versión robusta con sending_results_flag")
        
        # Test de consistencia simple
        print(f"\n🔄 TEST DE CONSISTENCIA:")
        for i in range(3):
            time.sleep(0.5)
            bytes_test = capture_results()
            print(f"   Intento {i+1}: {len(bytes_test)} bytes")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if 'ser' in locals():
            ser.close()
            print("🔌 Desconectado")

if __name__ == "__main__":
    simple_8byte_test()