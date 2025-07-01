#!/usr/bin/env python3
"""
Test rápido para verificar el fix de envío de resultados
Debe recibir exactamente 8 bytes del comando 'R'
"""

import serial
import time

def test_results_fix():
    port = input("Puerto (Enter para COM18): ").strip() or "COM18"
    
    try:
        ser = serial.Serial(port, 9600, timeout=3)
        time.sleep(1)
        print(f"✅ Conectado a {port}")
        
        # Test ping
        ser.write(b'P')
        response = ser.read(1)
        if response == b'O':
            print("✅ Ping OK")
        else:
            print("❌ Ping failed")
            return
        
        # Test comando R (resultados)
        print("\n🧪 Testing comando RESULTS...")
        ser.flushInput()
        ser.write(b'R')
        
        # Recibir con timeout de 5 segundos
        received_bytes = []
        start_time = time.time()
        
        while len(received_bytes) < 8 and (time.time() - start_time) < 5:
            if ser.in_waiting > 0:
                byte_data = ser.read(1)
                if byte_data:
                    received_bytes.append(byte_data[0])
                    print(f"Byte {len(received_bytes)}: 0x{byte_data[0]:02X}")
        
        print(f"\n📊 RESULTADO:")
        print(f"Bytes recibidos: {len(received_bytes)}/8")
        
        if len(received_bytes) == 8:
            # Interpretar datos (little endian)
            mac_ops = (received_bytes[3] << 24) | (received_bytes[2] << 16) | (received_bytes[1] << 8) | received_bytes[0]
            cycles = (received_bytes[7] << 24) | (received_bytes[6] << 16) | (received_bytes[5] << 8) | received_bytes[4]
            
            print(f"✅ FIX FUNCIONANDO!")
            print(f"MAC Operations: {mac_ops:,}")
            print(f"Processing Cycles: {cycles:,}")
            if cycles > 0:
                print(f"Throughput: {mac_ops/cycles:.3f} MAC/cycle")
        else:
            print(f"❌ Fix aún no aplicado (esperado: 8, recibido: {len(received_bytes)})")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if 'ser' in locals():
            ser.close()

if __name__ == "__main__":
    test_results_fix()