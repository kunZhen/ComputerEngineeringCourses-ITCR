# CMakeLists.txt para la biblioteca CEthreads
# Versión mínima requerida de CMake (3.10 provee buen soporte para características modernas)
cmake_minimum_required(VERSION 3.10.0)

### Configuración básica del proyecto ###
# Establecemos el nombre de la biblioteca como variable para fácil reuso y mantenimiento
# (Facilita cambios de nombre o reestructuraciones futuras)
set(LIB_NAME CEthreads)

### Creación de la biblioteca compartida ###
# Generamos una biblioteca dinámica/shared library (.so, .dll, .dylib) a partir del código fuente
# SHARED: Indica que es una biblioteca compartida
# Se asume que existe un archivo fuente con el mismo nombre de la biblioteca (.c)
add_library(${LIB_NAME} SHARED ${LIB_NAME}.c)

### Propiedades de la biblioteca ###
set_target_properties(${LIB_NAME} PROPERTIES
    # Versión completa de la biblioteca (formato major.minor.patch)
    # IMPORTANTE: PROJECT_VERSION debe estar definido en el CMakeLists.txt padre
    VERSION ${PROJECT_VERSION}
    
    # Versión de compatibilidad binaria (SOVERSION)
    # Debería incrementarse solo cuando hay cambios incompatibles en la ABI
    # Usamos solo la versión major para mantener compatibilidad mientras sea posible
    SOVERSION ${PROJECT_VERSION_MAJOR}
    
    # Especifica el archivo header público que se instalará con la biblioteca
    # Este header será accesible para los usuarios de la biblioteca
    PUBLIC_HEADER ${LIB_NAME}.h)

### Instalación del sistema ###
install(TARGETS ${LIB_NAME}
    # Destino para la biblioteca compartida (usamos variable estándar CMake)
    # CMAKE_INSTALL_LIBDIR: típicamente 'lib' o 'lib64' en sistemas Linux
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    
    # Instalación de headers públicos
    # CMAKE_INSTALL_INCLUDEDIR: normalmente 'include' en sistemas Unix
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})