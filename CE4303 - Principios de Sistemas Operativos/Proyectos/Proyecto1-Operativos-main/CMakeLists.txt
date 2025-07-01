# Configuración básica del proyecto
cmake_minimum_required(VERSION 3.10.0)  # Versión con soporte para modernas políticas y características

# Definición principal del proyecto
project(schedulingCars)  # Establece variables importantes: PROJECT_NAME, CMAKE_PROJECT_NAME, etc.

# Configuración de definiciones de compilador
add_definitions(-D_GNU_SOURCE)  # Habilita extensiones GNU para acceso a características específicas
                                # (Ej: pthread_setname_npc en Linux, strdup, etc.)

# Configuración de directorios de salida
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)  # Todos los ejecutables se generarán en /bin
                                                             # dentro del directorio de build

# Configuración del lenguaje
enable_language(C)  # Asegura el soporte para C (normalmente detectado automáticamente)
set(CMAKE_C_STANDARD 11)  # Requiere el estándar C11 (características como _Generic, static_assert, etc.)

# Integración con CTest para pruebas
#include(CTest)  # Habilita el sistema de testing de CMake (permite add_test, ctest commands)

# Estructura del proyecto
add_subdirectory(src)  # Incluye el subdirectorio donde están los componentes principales
                       # (asume que contiene CMakeLists.txt para bibliotecas/ejecutables)

# Gestión de variables del proyecto
set(PROJECT_NAME ${CMAKE_PROJECT_NAME})  # Crea alias para uso consistente en todo el proyecto

# Gestión de recursos
file(COPY images/ DESTINATION ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/images/)  # Copia recursos al directorio de salida
                                                                          # (útil para acceso en tiempo de ejecución)