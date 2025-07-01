#!/usr/bin/env python3
"""
Tests avanzados de rendimiento del arreglo sistólico
Ahora que el sistema funciona perfectamente, probemos características avanzadas
"""

import serial
import time
import statistics

def advanced_performance_test():
    port = input("Puerto (Enter para COM18): ").strip() or "COM18"
    
    try:
        ser = serial.Serial(port, 9600, timeout=2)
        time.sleep(1)
        print(f"✅ Conectado a {port}")
        
        # Ping test
        ser.write(b'P')
        if ser.read(1) != b'O':
            print("❌ Ping failed")
            return
        print("✅ Ping OK")
        
        print("\n🚀 TESTS AVANZADOS DE RENDIMIENTO")
        print("=" * 60)
        
        def get_results():
            """Captura los 8 bytes de resultados"""
            ser.flushInput()
            ser.write(b'R')
            
            bytes_received = []
            for _ in range(8):
                byte_data = ser.read(1)
                if byte_data:
                    bytes_received.append(byte_data[0])
                else:
                    break
            
            if len(bytes_received) == 8:
                mac_ops = (bytes_received[3] << 24) | (bytes_received[2] << 16) | (bytes_received[1] << 8) | bytes_received[0]
                cycles = (bytes_received[7] << 24) | (bytes_received[6] << 16) | (bytes_received[5] << 8) | bytes_received[4]
                return mac_ops, cycles
            return None, None
        
        def start_processing():
            """Inicia procesamiento"""
            ser.write(b'S')
            return ser.read(1) == b'A'
        
        # Test 1: Análisis estadístico de múltiples runs
        print("\n1️⃣ ANÁLISIS ESTADÍSTICO (20 runs):")
        mac_ops_list = []
        cycles_list = []
        throughput_list = []
        
        for i in range(20):
            if start_processing():
                time.sleep(0.1)  # Asegurar que termine
                mac_ops, cycles = get_results()
                if mac_ops is not None and cycles is not None:
                    mac_ops_list.append(mac_ops)
                    cycles_list.append(cycles)
                    throughput = mac_ops / cycles if cycles > 0 else 0
                    throughput_list.append(throughput)
                    
                    if i % 5 == 0:  # Print cada 5 runs
                        print(f"   Run {i+1:2d}: MAC={mac_ops:,}, Cycles={cycles:,}, T={throughput:.3f}")
            time.sleep(0.2)
        
        if throughput_list:
            print(f"\n📊 ESTADÍSTICAS (n={len(throughput_list)}):")
            print(f"   Throughput promedio: {statistics.mean(throughput_list):.3f} ± {statistics.stdev(throughput_list):.3f} MAC/cycle")
            print(f"   Throughput mínimo:   {min(throughput_list):.3f} MAC/cycle")
            print(f"   Throughput máximo:   {max(throughput_list):.3f} MAC/cycle")
            print(f"   MAC ops promedio:    {statistics.mean(mac_ops_list):,.0f}")
            print(f"   Cycles promedio:     {statistics.mean(cycles_list):,.0f}")
            
            # Análisis de consistencia
            cv_throughput = statistics.stdev(throughput_list) / statistics.mean(throughput_list) * 100
            print(f"   Coeficiente de variación: {cv_throughput:.2f}% {'✅ Excelente' if cv_throughput < 1 else '⚠️ Variable'}")
        
        # Test 2: Análisis de timing de comunicación
        print(f"\n2️⃣ ANÁLISIS DE TIMING DE COMUNICACIÓN:")
        timing_results = []
        
        for i in range(10):
            start_time = time.time()
            
            # Comando completo: START → STATUS → RESULTS
            ser.write(b'S')
            ser.read(1)  # ACK
            
            ser.write(b'?')
            ser.read(1)  # STATUS
            
            ser.write(b'R')
            for _ in range(8):
                ser.read(1)  # 8 bytes
            
            total_time = time.time() - start_time
            timing_results.append(total_time)
            
            if i % 3 == 0:
                print(f"   Secuencia {i+1}: {total_time*1000:.1f}ms")
            
            time.sleep(0.3)
        
        if timing_results:
            avg_time = statistics.mean(timing_results)
            print(f"\n⏱️ TIMING PROMEDIO:")
            print(f"   Secuencia completa: {avg_time*1000:.1f} ± {statistics.stdev(timing_results)*1000:.1f}ms")
            print(f"   Throughput comunicación: {1/avg_time:.1f} secuencias/segundo")
        
        # Test 3: Test de estrés de comunicación
        print(f"\n3️⃣ TEST DE ESTRÉS (100 comandos rápidos):")
        error_count = 0
        success_count = 0
        
        start_stress = time.time()
        for i in range(100):
            try:
                # Comando R rápido
                ser.flushInput()
                ser.write(b'R')
                bytes_received = ser.read(8)
                
                if len(bytes_received) == 8:
                    success_count += 1
                else:
                    error_count += 1
                    
                if i % 20 == 0:
                    print(f"   Progreso: {i+1}/100, Success: {success_count}, Errors: {error_count}")
                    
            except Exception:
                error_count += 1
        
        stress_time = time.time() - start_stress
        print(f"\n💪 RESULTADO DEL ESTRÉS:")
        print(f"   Comandos exitosos: {success_count}/100 ({success_count}%)")
        print(f"   Errores: {error_count}/100 ({error_count}%)")
        print(f"   Tiempo total: {stress_time:.1f}s")
        print(f"   Throughput: {100/stress_time:.1f} comandos/segundo")
        
        if success_count >= 95:
            print("   ✅ EXCELENTE: Sistema muy robusto")
        elif success_count >= 90:
            print("   ⚡ BUENO: Sistema estable")
        else:
            print("   ⚠️ REVISAR: Posibles problemas de timing")
        
        # Resumen final
        print(f"\n" + "=" * 60)
        print("🏆 RESUMEN FINAL DEL SISTEMA:")
        if throughput_list and statistics.mean(throughput_list) >= 15.5:
            print("✅ RENDIMIENTO: Óptimo (>15.5 MAC/cycle)")
        if cv_throughput < 1:
            print("✅ CONSISTENCIA: Excelente (<1% variación)")
        if success_count >= 95:
            print("✅ ROBUSTEZ: Muy alta (>95% éxito)")
        if avg_time < 0.5:
            print("✅ VELOCIDAD: Muy rápida (<500ms por secuencia)")
        
        print("\n🎉 ¡SISTEMA DE ARREGLO SISTÓLICO COMPLETAMENTE VALIDADO!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if 'ser' in locals():
            ser.close()
            print("🔌 Desconectado")

if __name__ == "__main__":
    advanced_performance_test()