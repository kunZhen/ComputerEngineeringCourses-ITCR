# ============================================================================
# CMakeLists.txt - Archivo de configuración de compilación principal
# ============================================================================

# Directorios de inclusión para archivos de cabecera
# Permite que los archivos fuente accedan a los headers en estos directorios
include_directories(${CMAKE_SOURCE_DIR}/src/lib)
include_directories(${CMAKE_SOURCE_DIR}/src/street)

# Agrega el subdirectorio que contiene el código de la biblioteca
# Construirá todos los destinos definidos en src/lib/CMakeLists.txt
add_subdirectory(lib)

# Agrega el subdirectorio para el planificador
# Construirá todos los destinos definidos en src/scheduler/CMakeLists.txt
add_subdirectory(scheduler)

# Define el ejecutable principal utilizando el nombre del proyecto
# El ejecutable incluye main.c y street/street.c como archivos fuente
add_executable(${PROJECT_NAME} main.c street/street.c)

# Vincula el ejecutable principal con las bibliotecas requeridas
# CEthreads y scheduler son bibliotecas necesarias para la ejecución
target_link_libraries(${PROJECT_NAME} CEthreads scheduler)

# Agrega los tests al proceso de compilación
# Compilará todos los archivos de prueba definidos en src/tests/CMakeLists.txt
# add_subdirectory(tests)

# ============================================================================
# Comandos personalizados para copiar archivos si son modificados
# ============================================================================

# Copia gui.py al directorio de salida de ejecución si es modificado
# OUTPUT define el archivo de salida que será creado por este comando
# COMMAND especifica el comando a ejecutar
# DEPENDS indica que este comando depende del archivo fuente original
# COMMENT proporciona un mensaje informativo durante la compilación
add_custom_command(
    OUTPUT ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/GUI.py
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_SOURCE_DIR}/src/gui/GUI.py ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/gui.py
    DEPENDS ${CMAKE_SOURCE_DIR}/src/gui/GUI.py
    COMMENT "Copiando gui.py al directorio de salida de ejecución"
)

# Copia street.config al directorio de salida de ejecución si es modificado
# Nota: Este archivo se coloca en un subdirectorio street/ dentro del directorio de salida
add_custom_command(
    OUTPUT ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/street/street.config
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_SOURCE_DIR}/src/street/street.config ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/street/street.config
    DEPENDS ${CMAKE_SOURCE_DIR}/src/street/street.config
    COMMENT "Copiando street.config al directorio de salida de ejecución"
)

# ============================================================================
# Asegura que la copia de archivos ocurra como parte del proceso de compilación
# ============================================================================

# Define un objetivo personalizado llamado 'copy_files' que depende de todos los
# archivos de salida definidos en los comandos anteriores
# ALL asegura que este objetivo sea ejecutado por defecto al compilar
add_custom_target(copy_files ALL
    DEPENDS ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/GUI.py
            ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/street/street.config
)

# Agrega el objetivo copy_files como una dependencia del ejecutable principal
# Esto garantiza que los archivos sean copiados antes de que se complete la compilación
# del ejecutable principal
add_dependencies(${PROJECT_NAME} copy_files)