# Buscar todos los archivos de test en la carpeta tests
file(GLOB TEST_SOURCES "*.c")

# Para cada archivo de test, crear un ejecutable
foreach(test_source ${TEST_SOURCES})
    # Extraer el nombre base del archivo (sin extensión)
    get_filename_component(test_name ${test_source} NAME_WE)
    
    # Crear un ejecutable para este test
    add_executable(${test_name} ${test_source})
    
    # Vincular con la biblioteca principal (que contiene tu código)
    target_link_libraries(${test_name} proyecto_lib)
    
    # Registrar como test en CMake
    add_test(NAME ${test_name} COMMAND ${test_name})
endforeach()