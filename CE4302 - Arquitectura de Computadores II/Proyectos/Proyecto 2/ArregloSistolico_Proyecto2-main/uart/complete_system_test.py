#!/usr/bin/env python3
"""
Test específico para el Sistema Completo de Image Processor
Después de cambiar del módulo debug al sistema completo
"""

import serial
import time
import struct

class ImageProcessorTester:
    """Tester específico para el sistema completo"""
    
    # Comandos del sistema completo
    CMD_PING = b'P'       # 0x50
    CMD_START = b'S'      # 0x53  
    CMD_STATUS = b'?'     # 0x3F
    CMD_RESULTS = b'R'    # 0x52
    
    # Respuestas esperadas del sistema completo
    RSP_PONG = b'O'       # 0x4F
    RSP_ACK = b'A'        # 0x41
    RSP_BUSY = b'B'       # 0x42
    RSP_DONE = b'D'       # 0x44
    RSP_ERROR = b'E'      # 0x45
    
    def __init__(self, port: str):
        self.port = port
        self.ser = None
        
    def connect(self):
        """Conectar al puerto serie"""
        try:
            self.ser = serial.Serial(
                port=self.port,
                baudrate=9600,
                timeout=2
            )
            print(f"✅ Conectado a {self.port}")
            return True
        except Exception as e:
            print(f"❌ Error conectando: {e}")
            return False
    
    def disconnect(self):
        """Desconectar"""
        if self.ser:
            self.ser.close()
        print("Desconectado")
    
    def send_command(self, cmd: bytes) -> bytes:
        """Enviar comando y obtener respuesta"""
        if not self.ser:
            return b''
            
        try:
            self.ser.reset_input_buffer()
            self.ser.write(cmd)
            print(f"→ Enviado: {cmd.hex().upper()} ('{cmd.decode()}')")
            
            response = self.ser.read(1)
            if response:
                print(f"← Recibido: {response.hex().upper()} ('{response.decode() if response.isalpha() else '?'}')")
                return response
            else:
                print("❌ Sin respuesta")
                return b''
                
        except Exception as e:
            print(f"❌ Error: {e}")
            return b''
    
    def test_system_identification(self):
        """Test 1: Identificar si es sistema debug o completo"""
        print("\n" + "="*50)
        print("TEST 1: IDENTIFICACIÓN DEL SISTEMA")
        print("="*50)
        
        # Test ping
        response = self.send_command(self.CMD_PING)
        if response == self.RSP_PONG:
            print("✅ Ping/Pong correcto - Sistema operativo")
        else:
            print(f"❌ Respuesta ping incorrecta: esperado {self.RSP_PONG.hex()}")
            return False
        
        # Test comando arbitrario para detectar modo
        response = self.send_command(b'X')  # Comando inexistente
        if response == b'X':
            print("⚠️ Respuesta echo - SISTEMA DEBUG ACTIVO")
            print("   Debes cambiar al top level completo (de10_standard_top)")
            return False
        elif response == self.RSP_ERROR or response == b'':
            print("✅ No hace echo - SISTEMA COMPLETO ACTIVO")
            return True
        else:
            print(f"? Respuesta inesperada: {response.hex()}")
            return False
    
    def test_status_commands(self):
        """Test 2: Comandos de estado del sistema completo"""
        print("\n" + "="*50)
        print("TEST 2: COMANDOS DE ESTADO")
        print("="*50)
        
        # Test status
        response = self.send_command(self.CMD_STATUS)
        if response in [self.RSP_ACK, self.RSP_BUSY, self.RSP_DONE]:
            if response == self.RSP_ACK:
                print("✅ Estado: IDLE - Sistema listo")
            elif response == self.RSP_BUSY:
                print("✅ Estado: BUSY - Procesando")
            elif response == self.RSP_DONE:
                print("✅ Estado: DONE - Procesamiento terminado")
            return True
        else:
            print(f"❌ Respuesta status incorrecta: {response.hex() if response else 'sin respuesta'}")
            return False
    
    def test_processing_cycle(self):
        """Test 3: Ciclo completo de procesamiento"""
        print("\n" + "="*50)
        print("TEST 3: CICLO DE PROCESAMIENTO COMPLETO")
        print("="*50)
        
        # 1. Verificar estado inicial
        print("\n--- Verificando estado inicial ---")
        status = self.send_command(self.CMD_STATUS)
        if status == self.RSP_BUSY:
            print("⚠️ Sistema ocupado, esperando...")
            if not self.wait_for_idle():
                return False
        
        # 2. Iniciar procesamiento
        print("\n--- Iniciando procesamiento ---")
        response = self.send_command(self.CMD_START)
        if response == self.RSP_ACK:
            print("✅ Procesamiento iniciado")
        elif response == self.RSP_BUSY:
            print("⚠️ Sistema ya estaba procesando")
        else:
            print(f"❌ Error iniciando: {response.hex() if response else 'sin respuesta'}")
            return False
        
        # 3. Monitorear progreso
        print("\n--- Monitoreando progreso ---")
        if not self.monitor_processing():
            return False
        
        # 4. Obtener resultados
        print("\n--- Obteniendo resultados ---")
        return self.get_results()
    
    def wait_for_idle(self, timeout=30):
        """Esperar hasta que el sistema esté idle"""
        start_time = time.time()
        while time.time() - start_time < timeout:
            status = self.send_command(self.CMD_STATUS)
            if status == self.RSP_ACK:
                print("✅ Sistema ahora idle")
                return True
            time.sleep(1)
        
        print("❌ Timeout esperando idle")
        return False
    
    def monitor_processing(self, max_time=120):
        """Monitorear el procesamiento hasta completar"""
        start_time = time.time()
        last_status = None
        
        while time.time() - start_time < max_time:
            status = self.send_command(self.CMD_STATUS)
            
            if status != last_status:
                elapsed = int(time.time() - start_time)
                if status == self.RSP_BUSY:
                    print(f"[{elapsed:3d}s] Estado: PROCESSING...")
                elif status == self.RSP_DONE:
                    print(f"[{elapsed:3d}s] Estado: DONE ✅")
                    return True
                elif status == self.RSP_ERROR:
                    print(f"[{elapsed:3d}s] Estado: ERROR ❌")
                    return False
                last_status = status
            
            time.sleep(2)  # Check cada 2 segundos
        
        print("❌ Timeout - procesamiento muy lento")
        return False
    
    def get_results(self):
        """Obtener y mostrar resultados"""
        try:
            # Verificar que esté done
            status = self.send_command(self.CMD_STATUS)
            if status != self.RSP_DONE:
                print(f"❌ No está done para obtener resultados: {status.hex()}")
                return False
            
            # Solicitar resultados
            self.ser.reset_input_buffer()
            self.ser.write(self.CMD_RESULTS)
            print(f"→ Solicitando resultados...")
            
            # Leer 8 bytes de resultados
            result_data = self.ser.read(8)
            if len(result_data) != 8:
                print(f"❌ Datos incompletos: {len(result_data)}/8 bytes")
                print(f"   Datos recibidos: {result_data.hex()}")
                return False
            
            # Desempaquetar resultados (little-endian)
            mac_ops = struct.unpack('<I', result_data[0:4])[0]
            cycles = struct.unpack('<I', result_data[4:8])[0]
            
            print("✅ RESULTADOS OBTENIDOS:")
            print(f"   MAC Operations: {mac_ops:,}")
            print(f"   Processing Cycles: {cycles:,}")
            
            if cycles > 0:
                throughput = mac_ops / cycles
                print(f"   Throughput: {throughput:.3f} MAC/cycle")
            
            # Validar que los resultados sean razonables
            if mac_ops > 0 and cycles > 0:
                print("✅ Resultados válidos")
                return True
            else:
                print("⚠️ Resultados sospechosos (ceros)")
                return False
                
        except Exception as e:
            print(f"❌ Error obteniendo resultados: {e}")
            return False
    
    def run_complete_test(self):
        """Ejecutar test completo del sistema"""
        print("🧪 INICIANDO TEST COMPLETO DEL SISTEMA")
        print("="*60)
        
        success_count = 0
        total_tests = 3
        
        # Test 1: Identificación
        if self.test_system_identification():
            success_count += 1
        else:
            print("\n❌ FALLO CRÍTICO: Sistema debug activo")
            print("   SOLUCIÓN: Cambiar top level a 'de10_standard_top'")
            return False
        
        # Test 2: Comandos de estado
        if self.test_status_commands():
            success_count += 1
        
        # Test 3: Procesamiento completo
        if self.test_processing_cycle():
            success_count += 1
        
        # Resultado final
        print("\n" + "="*60)
        print(f"RESULTADO FINAL: {success_count}/{total_tests} tests exitosos")
        
        if success_count == total_tests:
            print("🎉 SISTEMA COMPLETAMENTE FUNCIONAL")
            return True
        else:
            print("⚠️ Sistema parcialmente funcional")
            return False

def main():
    """Función principal"""
    print("🧪 TEST DEL SISTEMA COMPLETO IMAGE PROCESSOR")
    print("="*50)
    
    port = input("Puerto serie (Enter para COM18): ").strip()
    if not port:
        port = "COM18"
    
    tester = ImageProcessorTester(port)
    
    if not tester.connect():
        return
    
    try:
        # Esperar un poco para estabilizar
        time.sleep(1)
        
        # Ejecutar test completo
        success = tester.run_complete_test()
        
        if success:
            print("\n🚀 ¡Sistema listo para uso en producción!")
        else:
            print("\n🔧 Sistema requiere ajustes")
            
    except KeyboardInterrupt:
        print("\nTest interrumpido por usuario")
    finally:
        tester.disconnect()

if __name__ == "__main__":
    main()