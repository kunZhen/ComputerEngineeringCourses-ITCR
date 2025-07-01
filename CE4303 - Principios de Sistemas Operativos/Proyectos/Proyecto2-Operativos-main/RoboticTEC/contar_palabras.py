#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import re
from collections import Counter

def contar_palabras(ruta_archivo, top_n=None):
    """
    Lee un archivo de texto, tokeniza las palabras, las normaliza
    y devuelve un Counter con las frecuencias.
    """
    contador = Counter()
    patron = re.compile(r"\b\w+\b", re.UNICODE)

    with open(ruta_archivo, 'r', encoding='utf-8') as f:
        for linea in f:
            # Convertir a minúsculas y extraer palabras
            palabras = patron.findall(linea.lower())
            contador.update(palabras)

    if top_n:
        return contador.most_common(top_n)
    else:
        return contador.most_common()

def main():
    parser = argparse.ArgumentParser(
        description="Cuenta las palabras más comunes en un archivo de texto."
    )
    parser.add_argument(
        'archivo',
        help="Ruta al archivo .txt a analizar"
    )
    parser.add_argument(
        '-n', '--top',
        type=int,
        default=10,
        help="Número de palabras más frecuentes a mostrar (por defecto: 10)"
    )
    args = parser.parse_args()

    resultados = contar_palabras(args.archivo, top_n=args.top)

    print(f"Las {args.top} palabras más frecuentes en '{args.archivo}' son:\n")
    for palabra, frecuencia in resultados:
        print(f"{palabra:15} {frecuencia}")

if __name__ == "__main__":
    main()
