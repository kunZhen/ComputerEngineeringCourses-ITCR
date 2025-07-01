#!/usr/bin/env python3
"""
Test para verificar si img_done se resetea entre comandos
Verifica estado inmediatamente antes de comando R
"""

import serial
import time

def immediate_status_test():
    port = input("Puerto (Enter para COM18): ").strip() or "COM18"
    
    try:
        ser = serial.Serial(port, 9600, timeout=1)
        time.sleep(1)
        print(f"✅ Conectado a {port}")
        
        print("🔍 TEST DE ESTADO INMEDIATO")
        print("=" * 40)
        
        # Test 1: Estado seguido inmediatamente de comando R
        print("\n1️⃣ ESTADO → COMANDO R (inmediato):")
        ser.flushInput()
        
        # Comando ? (estado)
        ser.write(b'?')
        status_response = ser.read(1)
        print(f"   Status: 0x{status_response[0]:02X} ('{chr(status_response[0])}')")
        
        # Comando R inmediatamente después (sin delay)
        ser.write(b'R')
        results_response = ser.read(1)
        print(f"   Results: 0x{results_response[0]:02X} ('{chr(results_response[0])}')")
        
        # Test 2: Con micro-delay
        print("\n2️⃣ ESTADO → COMANDO R (micro-delay 10ms):")
        ser.flushInput()
        
        ser.write(b'?')
        status_response = ser.read(1)
        print(f"   Status: 0x{status_response[0]:02X}")
        
        time.sleep(0.01)  # 10ms delay
        ser.write(b'R')
        results_response = ser.read(1)
        print(f"   Results: 0x{results_response[0]:02X}")
        
        # Test 3: Con delay más largo
        print("\n3️⃣ ESTADO → COMANDO R (delay 100ms):")
        ser.flushInput()
        
        ser.write(b'?')
        status_response = ser.read(1)
        print(f"   Status: 0x{status_response[0]:02X}")
        
        time.sleep(0.1)  # 100ms delay
        ser.write(b'R')
        results_response = ser.read(1)
        print(f"   Results: 0x{results_response[0]:02X}")
        
        # Test 4: Secuencia rápida múltiple
        print("\n4️⃣ SECUENCIA RÁPIDA MÚLTIPLE:")
        for i in range(5):
            ser.flushInput()
            
            # Status inmediato
            ser.write(b'?')
            status = ser.read(1)
            
            # Results inmediato
            ser.write(b'R')
            results = ser.read(1)
            
            print(f"   #{i+1}: Status=0x{status[0]:02X}, Results=0x{results[0]:02X}")
        
        # Test 5: START → STATUS → RESULTS en secuencia
        print("\n5️⃣ START → STATUS → RESULTS:")
        ser.flushInput()
        
        # START
        ser.write(b'S')
        start_resp = ser.read(1)
        print(f"   START: 0x{start_resp[0]:02X}")
        
        # STATUS inmediatamente
        ser.write(b'?')
        status_resp = ser.read(1)
        print(f"   STATUS: 0x{status_resp[0]:02X}")
        
        # RESULTS inmediatamente
        ser.write(b'R')
        results_resp = ser.read(1)
        print(f"   RESULTS: 0x{results_resp[0]:02X}")
        
        print("\n" + "=" * 40)
        print("🔍 ANÁLISIS:")
        
        if results_resp[0] == 0x42:  # BUSY
            print("❌ img_done NO está siendo true")
            print("📋 POSIBLES CAUSAS:")
            print("   - img_done se resetea automáticamente")
            print("   - img_done solo dura 1 ciclo de clock")
            print("   - Problema en image_processor FSM")
            print("   - Conexión incorrecta entre módulos")
        elif results_resp[0] == 0x80:
            print("✅ img_done está siendo true")
            print("⚠️ Problema en envío de múltiples bytes")
        else:
            print(f"❓ Respuesta inesperada: 0x{results_resp[0]:02X}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if 'ser' in locals():
            ser.close()
            print("🔌 Desconectado")

if __name__ == "__main__":
    immediate_status_test()