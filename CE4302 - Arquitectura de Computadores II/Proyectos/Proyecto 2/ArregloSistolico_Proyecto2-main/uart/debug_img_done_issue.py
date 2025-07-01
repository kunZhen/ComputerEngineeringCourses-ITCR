#!/usr/bin/env python3
"""
Debug del problema img_done
El comando R responde BUSY (0x42) en lugar de enviar resultados
Esto significa que img_done no está siendo true
"""

import serial
import time

def debug_img_done():
    port = input("Puerto (Enter para COM18): ").strip() or "COM18"
    
    try:
        ser = serial.Serial(port, 9600, timeout=2)
        time.sleep(1)
        print(f"✅ Conectado a {port}")
        
        print("🔍 DEBUGGING ESTADO img_done")
        print("=" * 50)
        
        # Test 1: Estado inicial
        print("\n1️⃣ ESTADO INICIAL:")
        ser.write(b'?')
        response = ser.read(1)
        if response:
            print(f"   Status: 0x{response[0]:02X} ('{chr(response[0])}')")
            if response[0] == 0x41:    # A
                print("   → IDLE (listo para procesar)")
            elif response[0] == 0x42:  # B
                print("   → BUSY (procesando)")
            elif response[0] == 0x44:  # D
                print("   → DONE (img_done = true)")
            else:
                print(f"   → DESCONOCIDO")
        
        # Test 2: Comando START y monitoreo
        print("\n2️⃣ COMANDO START + MONITOREO:")
        ser.write(b'S')
        start_response = ser.read(1)
        if start_response:
            print(f"   Start response: 0x{start_response[0]:02X} ('{chr(start_response[0])}')")
            
            if start_response[0] == 0x41:  # A = ACK
                print("   ✅ Procesamiento iniciado")
                
                # Monitorear estado cada 100ms por 5 segundos
                for i in range(50):
                    time.sleep(0.1)
                    ser.write(b'?')
                    status = ser.read(1)
                    if status:
                        if status[0] == 0x44:  # D = DONE
                            print(f"   ✅ DONE detectado en iteración {i} (~{i*100}ms)")
                            break
                        elif status[0] == 0x42:  # B = BUSY
                            if i % 10 == 0:  # Print cada segundo
                                print(f"   ⏳ BUSY en {i*100}ms...")
                        else:
                            print(f"   ❓ Estado extraño: 0x{status[0]:02X}")
                else:
                    print("   ⚠️ Timeout - no se detectó DONE en 5 segundos")
            else:
                print(f"   ❌ Start falló: 0x{start_response[0]:02X}")
        
        # Test 3: Estado final y comando R
        print("\n3️⃣ ESTADO FINAL Y COMANDO R:")
        ser.write(b'?')
        final_status = ser.read(1)
        if final_status:
            print(f"   Status final: 0x{final_status[0]:02X} ('{chr(final_status[0])}')")
            
            print("   Intentando comando R...")
            ser.write(b'R')
            results_response = ser.read(1)
            if results_response:
                print(f"   Response R: 0x{results_response[0]:02X} ('{chr(results_response[0])}')")
                
                if results_response[0] == 0x42:  # B = BUSY
                    print("   ❌ PROBLEMA: img_done no está siendo true")
                    print("   📋 POSIBLES CAUSAS:")
                    print("       - Image processor no actualiza done signal")
                    print("       - Done signal se resetea automáticamente")
                    print("       - Conexión incorrecta entre modules")
                elif results_response[0] == 0x45:  # E = ERROR
                    print("   ⚠️ Sistema responde ERROR (comando inválido?)")
                else:
                    print("   ✅ Recibiendo datos (esperado)")
        
        # Test 4: Reseteo y retry
        print("\n4️⃣ TEST DE RESETEO:")
        print("   Presiona KEY[0] en la DE10 para reset...")
        time.sleep(3)
        
        # Verificar después de reset
        ser.write(b'?')
        reset_status = ser.read(1)
        if reset_status:
            print(f"   Status post-reset: 0x{reset_status[0]:02X} ('{chr(reset_status[0])}')")
        
        # Test 5: Múltiples START consecutivos
        print("\n5️⃣ MÚLTIPLES START CONSECUTIVOS:")
        for i in range(3):
            print(f"   Start #{i+1}:")
            ser.write(b'S')
            start_resp = ser.read(1)
            if start_resp:
                print(f"     Response: 0x{start_resp[0]:02X}")
            
            time.sleep(0.5)
            ser.write(b'?')
            status_resp = ser.read(1)
            if status_resp:
                print(f"     Status: 0x{status_resp[0]:02X}")
                
                # Si está DONE, intentar R
                if status_resp[0] == 0x44:
                    ser.write(b'R')
                    r_resp = ser.read(1)
                    if r_resp:
                        print(f"     R response: 0x{r_resp[0]:02X}")
        
        print("\n" + "=" * 50)
        print("🔍 DEBUG COMPLETADO")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if 'ser' in locals():
            ser.close()
            print("🔌 Desconectado")

if __name__ == "__main__":
    debug_img_done()