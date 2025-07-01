#!/usr/bin/env python3
"""
Convertidor de input.txt a data.mif para RAM del IP Catalog Intel/Altera
Convierte datos de imagen hexadecimales al formato Memory Initialization File (.mif)
"""

import sys
import os
from typing import List, Tuple

class HexToMifConverter:
    def __init__(self):
        # Configuración de direcciones de memoria (debe coincidir con el diseño)
        self.WEIGHTS_ADDR = 0x00000000  # Base address for weights
        self.INPUT_ADDR = 0x00000020    # Base address for input image  
        self.OUTPUT_ADDR = 0x00002800   # Base address for output image
        
        # Configuración de memoria
        self.MEM_DEPTH = 8192          # Tamaño total de memoria en palabras de 32-bit
        self.MEM_WIDTH = 32            # Ancho de cada palabra
        
        # Datos de la imagen
        self.image_width = 0
        self.image_height = 0
        self.image_data = []
        
        # Datos de pesos (matriz 4x4 por defecto)
        self.weight_width = 4
        self.weight_height = 4
        self.weight_data = [
            [-2, -1,  0,  1],  # Detección de bordes horizontal
            [-1,  1,  1,  2],  # Filtro de realce
            [ 0,  1,  2,  1],  # Filtro de suavizado
            [ 1,  2,  1,  0]   # Filtro diagonal
        ]

    def read_input_file(self, filename: str) -> bool:
        """Lee el archivo input.txt y extrae dimensiones y datos de imagen"""
        try:
            with open(filename, 'r') as f:
                lines = [line.strip() for line in f if line.strip()]
            
            if len(lines) < 3:
                print(f"Error: El archivo {filename} debe tener al menos 3 líneas")
                return False
                
            # Leer dimensiones de la imagen
            self.image_width = int(lines[0], 16)
            self.image_height = int(lines[1], 16)
            
            print(f"Dimensiones de imagen detectadas: {self.image_width} x {self.image_height}")
            
            # Leer datos de imagen (saltando las dos primeras líneas)
            self.image_data = lines[2:]
            
            expected_words = (self.image_width * self.image_height + 3) // 4  # 4 pixels por word
            actual_words = len(self.image_data)
            
            print(f"Palabras de datos esperadas: {expected_words}")
            print(f"Palabras de datos encontradas: {actual_words}")
            
            return True
            
        except FileNotFoundError:
            print(f"Error: No se pudo encontrar el archivo {filename}")
            return False
        except ValueError as e:
            print(f"Error al parsear valores hexadecimales: {e}")
            return False
        except Exception as e:
            print(f"Error inesperado: {e}")
            return False

    def set_custom_weights(self, weights: List[List[int]]):
        """Permite configurar pesos personalizados"""
        if len(weights) != 4 or any(len(row) != 4 for row in weights):
            raise ValueError("Los pesos deben ser una matriz 4x4")
        
        self.weight_data = weights
        print("Pesos personalizados configurados:")
        for i, row in enumerate(weights):
            print(f"  Fila {i}: {row}")

    def weights_to_hex_words(self) -> List[str]:
        """Convierte la matriz de pesos a palabras hexadecimales de 32-bit"""
        hex_words = []
        
        for row in self.weight_data:
            # Cada peso es un byte con signo, empaquetamos 4 en una palabra de 32-bit
            word = 0
            for i, weight in enumerate(row):
                # Convertir a byte con signo (complemento a 2)
                if weight < 0:
                    byte_val = (256 + weight) & 0xFF
                else:
                    byte_val = weight & 0xFF
                
                # Colocar en la posición correcta (MSB primero)
                word |= (byte_val << ((3-i) * 8))
            
            hex_words.append(f"{word:08X}")
        
        return hex_words

    def calculate_memory_layout(self) -> dict:
        """Calcula el layout de memoria con direcciones"""
        layout = {}
        
        # Direcciones de pesos (convertir de byte a word address)
        weights_word_addr = self.WEIGHTS_ADDR // 4
        layout['weight_width_addr'] = weights_word_addr
        layout['weight_height_addr'] = weights_word_addr + 1
        layout['weight_data_start'] = weights_word_addr + 2
        
        # Direcciones de imagen de entrada
        input_word_addr = self.INPUT_ADDR // 4
        layout['image_width_addr'] = input_word_addr
        layout['image_height_addr'] = input_word_addr + 1
        layout['image_data_start'] = input_word_addr + 2
        
        # Dirección de salida
        layout['output_start'] = self.OUTPUT_ADDR // 4
        
        return layout

    def generate_mif_content(self) -> List[str]:
        """Genera el contenido completo del archivo MIF"""
        lines = []
        
        # Header del archivo MIF
        lines.extend([
            f"-- Memory Initialization File for Image Processor",
            f"-- Generated from input.txt",
            f"-- Image size: {self.image_width} x {self.image_height}",
            f"-- Weight matrix: {self.weight_width} x {self.weight_height}",
            f"",
            f"DEPTH = {self.MEM_DEPTH};",
            f"WIDTH = {self.MEM_WIDTH};",
            f"ADDRESS_RADIX = HEX;",
            f"DATA_RADIX = HEX;",
            f"",
            f"CONTENT",
            f"BEGIN"
        ])
        
        # Calcular layout de memoria
        layout = self.calculate_memory_layout()
        
        # Obtener datos de pesos en formato hex
        weight_hex_words = self.weights_to_hex_words()
        
        # Escribir dimensiones de pesos
        lines.append(f"    {layout['weight_width_addr']:04X} : {self.weight_width:08X};  -- weight_width")
        lines.append(f"    {layout['weight_height_addr']:04X} : {self.weight_height:08X};  -- weight_height")
        
        # Escribir datos de pesos
        for i, weight_word in enumerate(weight_hex_words):
            addr = layout['weight_data_start'] + i
            lines.append(f"    {addr:04X} : {weight_word};  -- weight_row_{i}")
        
        # Escribir dimensiones de imagen
        lines.append(f"    {layout['image_width_addr']:04X} : {self.image_width:08X};  -- image_width")
        lines.append(f"    {layout['image_height_addr']:04X} : {self.image_height:08X};  -- image_height")
        
        # Escribir datos de imagen
        for i, image_word in enumerate(self.image_data):
            addr = layout['image_data_start'] + i
            # Asegurar que sea hexadecimal válido de 8 caracteres
            clean_word = image_word.upper().zfill(8)
            lines.append(f"    {addr:04X} : {clean_word};  -- image_data_{i}")
        
        # Llenar el resto con ceros
        last_used_addr = layout['image_data_start'] + len(self.image_data) - 1
        if last_used_addr < self.MEM_DEPTH - 1:
            lines.append(f"    [{last_used_addr+1:04X}..{self.MEM_DEPTH-1:04X}] : 00000000;  -- unused_memory")
        
        lines.extend([
            f"END;",
            f"",
            f"-- Memory Map:",
            f"-- 0x{self.WEIGHTS_ADDR:08X} - 0x{self.WEIGHTS_ADDR + 24:08X}: Weight data",
            f"-- 0x{self.INPUT_ADDR:08X} - 0x{self.INPUT_ADDR + 8 + len(self.image_data)*4:08X}: Input image",
            f"-- 0x{self.OUTPUT_ADDR:08X} - 0x{self.OUTPUT_ADDR + 8 + len(self.image_data)*4:08X}: Output image"
        ])
        
        return lines

    def write_mif_file(self, output_filename: str) -> bool:
        """Escribe el archivo MIF"""
        try:
            mif_content = self.generate_mif_content()
            
            with open(output_filename, 'w') as f:
                for line in mif_content:
                    f.write(line + '\n')
            
            print(f"Archivo MIF generado exitosamente: {output_filename}")
            print(f"Líneas escritas: {len(mif_content)}")
            return True
            
        except Exception as e:
            print(f"Error al escribir archivo MIF: {e}")
            return False

    def print_memory_summary(self):
        """Imprime un resumen del contenido de memoria"""
        layout = self.calculate_memory_layout()
        
        print("\n" + "="*60)
        print("RESUMEN DE MEMORIA GENERADA")
        print("="*60)
        
        print(f"Configuración de memoria:")
        print(f"  Profundidad: {self.MEM_DEPTH} palabras")
        print(f"  Ancho: {self.MEM_WIDTH} bits")
        
        print(f"\nDatos de pesos:")
        print(f"  Dirección base: 0x{self.WEIGHTS_ADDR:08X}")
        print(f"  Dimensiones: {self.weight_width} x {self.weight_height}")
        print(f"  Palabras usadas: {2 + len(self.weight_data)}")
        
        print(f"\nDatos de imagen:")
        print(f"  Dirección base: 0x{self.INPUT_ADDR:08X}")
        print(f"  Dimensiones: {self.image_width} x {self.image_height}")
        print(f"  Palabras de datos: {len(self.image_data)}")
        print(f"  Total píxeles: {self.image_width * self.image_height}")
        
        print(f"\nDirección de salida:")
        print(f"  Dirección base: 0x{self.OUTPUT_ADDR:08X}")
        
        print("="*60)

def main():
    """Función principal"""
    converter = HexToMifConverter()
    
    # Configurar nombres de archivos
    input_file = '../resources/files/input.txt'
    output_file = '../resources/files/data.mif'
    
    # Permitir argumentos de línea de comandos
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    
    print("Convertidor de input.txt a data.mif")
    print("="*40)
    
    # Leer archivo de entrada
    if not converter.read_input_file(input_file):
        return 1
    
    # Opcionalmente, permitir configurar pesos personalizados
    use_custom_weights = input("\n¿Desea usar pesos personalizados? (y/N): ").lower().startswith('y')
    
    if use_custom_weights:
        print("Ingrese los pesos de la matriz 4x4 (valores entre -128 y 127):")
        try:
            custom_weights = []
            for i in range(4):
                row_input = input(f"Fila {i} (4 valores separados por espacios): ")
                row = [int(x) for x in row_input.split()]
                if len(row) != 4:
                    raise ValueError("Debe ingresar exactamente 4 valores por fila")
                custom_weights.append(row)
            
            converter.set_custom_weights(custom_weights)
        except Exception as e:
            print(f"Error en pesos personalizados: {e}")
            print("Usando pesos por defecto...")
    
    # Generar archivo MIF
    if not converter.write_mif_file(output_file):
        return 1
    
    # Mostrar resumen
    converter.print_memory_summary()
    
    print(f"\n✅ Conversión completada exitosamente!")
    print(f"📁 Archivo generado: {output_file}")
    print(f"💡 Copie este archivo a su proyecto de Quartus para inicializar la RAM.")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())