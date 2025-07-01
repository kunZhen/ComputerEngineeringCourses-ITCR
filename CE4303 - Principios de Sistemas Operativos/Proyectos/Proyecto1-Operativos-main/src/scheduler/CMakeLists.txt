# CMakeLists.txt para la biblioteca scheduler (calendar)
# Versión mínima requerida de CMake
cmake_minimum_required(VERSION 3.10.0)

### Configuración básica del proyecto ###
# Variable para nombre de la biblioteca - permite fácil reutilización y mantenimiento
# (Cambiar el nombre en un solo lugar afecta todo el archivo)
set(CALENDAR_NAME scheduler)

### Creación de biblioteca compartida ###
# Genera una biblioteca dinámica/shared library a partir del código fuente
add_library(${CALENDAR_NAME}
    SHARED             # Tipo: biblioteca compartida (.so, .dll, etc.)
    ${CALENDAR_NAME}.c # Archivo fuente principal (asume scheduler.c)
)

### Propiedades avanzadas de la biblioteca ###
set_target_properties(${CALENDAR_NAME} PROPERTIES
    # Versión semántica completa (major.minor.patch)
    # Debe estar definida en el CMakeLists.txt padre
    VERSION ${PROJECT_VERSION}
    
    # Versión de compatibilidad binaria (ABI)
    # Se usa solo major para indicar compatibilidad hacia atrás
    SOVERSION ${PROJECT_VERSION_MAJOR}
    
    # Header público que define la API de la biblioteca
    # Este archivo se instalará para uso externo
    PUBLIC_HEADER ${CALENDAR_NAME}.h)

### Configuración de instalación ###
install(TARGETS ${CALENDAR_NAME}
    # Destino para la biblioteca compilada
    # CMAKE_INSTALL_LIBDIR: variable estándar (lib, lib64, etc.)
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    
    # Instalación de headers públicos
    # Los usuarios incluirán con #include <scheduler.h>
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})