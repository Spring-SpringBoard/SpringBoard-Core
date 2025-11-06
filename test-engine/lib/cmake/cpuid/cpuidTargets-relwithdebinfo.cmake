#----------------------------------------------------------------
# Generated CMake target import file for configuration "RELWITHDEBINFO".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "cpuid::cpuid" for configuration "RELWITHDEBINFO"
set_property(TARGET cpuid::cpuid APPEND PROPERTY IMPORTED_CONFIGURATIONS RELWITHDEBINFO)
set_target_properties(cpuid::cpuid PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELWITHDEBINFO "C"
  IMPORTED_LOCATION_RELWITHDEBINFO "${_IMPORT_PREFIX}/lib/libcpuid.a"
  )

list(APPEND _cmake_import_check_targets cpuid::cpuid )
list(APPEND _cmake_import_check_files_for_cpuid::cpuid "${_IMPORT_PREFIX}/lib/libcpuid.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
