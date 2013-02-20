function(add_c_defines)
  set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS ${ARGN})
endfunction(add_c_defines)

if (APPLE)
  add_c_defines(DARWIN=1 _DARWIN_C_SOURCE)
endif ()

## preprocessor definitions we want everywhere
add_c_defines(
  _FILE_OFFSET_BITS=64
  _LARGEFILE64_SOURCE
  __STDC_FORMAT_MACROS
  __STDC_LIMIT_MACROS
  __LONG_LONG_SUPPORTED
  )
if (NOT CMAKE_SYSTEM_NAME STREQUAL FreeBSD)
  ## on FreeBSD these types of macros actually remove functionality
  add_c_defines(
    _SVID_SOURCE
    _XOPEN_SOURCE=600
    )
endif ()

## add TOKU_PTHREAD_DEBUG for debug builds
set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS_DEBUG TOKU_PTHREAD_DEBUG=1)
set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS_RELWITHDEBINFO TOKU_PTHREAD_DEBUG=1)
set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS_RELWITHDEBINFO _FORTIFY_SOURCE=2)

## coverage
option(USE_GCOV "Use gcov for test coverage." OFF)
if (USE_GCOV)
  if (NOT CMAKE_CXX_COMPILER_ID MATCHES GNU)
    message(FATAL_ERROR "Must use the GNU compiler to compile for test coverage.")
  endif ()
  find_program(COVERAGE_COMMAND NAMES gcov47 gcov)
endif (USE_GCOV)

include(CheckCCompilerFlag)
include(CheckCXXCompilerFlag)

## adds a compiler flag if the compiler supports it
macro(set_cflags_if_supported_named flag flagname)
  check_c_compiler_flag("${flag}" HAVE_C_${flagname})
  if (HAVE_C_${flagname})
    set(CMAKE_C_FLAGS "${flag} ${CMAKE_C_FLAGS}")
  endif ()
  check_cxx_compiler_flag("${flag}" HAVE_CXX_${flagname})
  if (HAVE_CXX_${flagname})
    set(CMAKE_CXX_FLAGS "${flag} ${CMAKE_CXX_FLAGS}")
  endif ()
endmacro(set_cflags_if_supported_named)

## adds a compiler flag if the compiler supports it
macro(set_cflags_if_supported)
  foreach(flag ${ARGN})
    check_c_compiler_flag(${flag} HAVE_C_${flag})
    if (HAVE_C_${flag})
      set(CMAKE_C_FLAGS "${flag} ${CMAKE_C_FLAGS}")
    endif ()
    check_cxx_compiler_flag(${flag} HAVE_CXX_${flag})
    if (HAVE_CXX_${flag})
      set(CMAKE_CXX_FLAGS "${flag} ${CMAKE_CXX_FLAGS}")
    endif ()
  endforeach(flag)
endmacro(set_cflags_if_supported)

## adds a linker flag if the compiler supports it
macro(set_ldflags_if_supported)
  foreach(flag ${ARGN})
    check_cxx_compiler_flag(${flag} HAVE_${flag})
    if (HAVE_${flag})
      set(CMAKE_EXE_LINKER_FLAGS "${flag} ${CMAKE_EXE_LINKER_FLAGS}")
      set(CMAKE_SHARED_LINKER_FLAGS "${flag} ${CMAKE_SHARED_LINKER_FLAGS}")
    endif ()
  endforeach(flag)
endmacro(set_ldflags_if_supported)

## disable some warnings
set_cflags_if_supported(
  -Wno-missing-field-initializers
  -Wstrict-null-sentinel
  -Winit-self
  -Wswitch
  -Wtrampolines
  -Wlogical-op
  -Wmissing-format-attribute
  -Wno-error=missing-format-attribute
  -Wno-error=address-of-array-temporary
  -fno-rtti
  -fno-exceptions
  )
## set_cflags_if_supported_named("-Weffc++" -Weffcpp)

## Clang has stricter POD checks.  So, only enable this warning on our other builds (Linux + GCC)
if (NOT CMAKE_CXX_COMPILER_ID MATCHES Clang)
  set_cflags_if_supported(
    -Wpacked
    )
endif ()

## this hits with optimized builds somewhere in ftleaf_split, we don't
## know why but we don't think it's a big deal
set_cflags_if_supported(
  -Wno-error=strict-overflow
  )
set_ldflags_if_supported(
  -Wno-error=strict-overflow
  )

## set extra debugging flags and preprocessor definitions
set(CMAKE_C_FLAGS_DEBUG "-g3 -O0 ${CMAKE_C_FLAGS_DEBUG}")
set(CMAKE_CXX_FLAGS_DEBUG "-g3 -O0 ${CMAKE_CXX_FLAGS_DEBUG}")

## The default for this is -g -O2 -DNDEBUG.
## Since we want none of those for drd, we just overwrite it.
set(CMAKE_C_FLAGS_RELWITHDEBINFO "-g3 -O1")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "-g3 -O1")

## set extra release flags
if (APPLE AND CMAKE_CXX_COMPILER_ID STREQUAL Clang)
  # have tried -flto and -O4, both make our statically linked executables break apple's linker
  set(CMAKE_C_FLAGS_RELEASE "-g -O3 ${CMAKE_C_FLAGS_RELEASE} -UNDEBUG")
  set(CMAKE_CXX_FLAGS_RELEASE "-g -O3 ${CMAKE_CXX_FLAGS_RELEASE} -UNDEBUG")
else ()
  # we overwrite this because the default passes -DNDEBUG and we don't want that
  set(CMAKE_C_FLAGS_RELEASE "-g -O3 -flto -fuse-linker-plugin ${CMAKE_C_FLAGS_RELEASE} -UNDEBUG")
  set(CMAKE_CXX_FLAGS_RELEASE "-g -O3 -flto -fuse-linker-plugin ${CMAKE_CXX_FLAGS_RELEASE} -UNDEBUG")
  set(CMAKE_EXE_LINKER_FLAGS "-g -fuse-linker-plugin ${CMAKE_EXE_LINKER_FLAGS}")
  set(CMAKE_SHARED_LINKER_FLAGS "-g -fuse-linker-plugin ${CMAKE_SHARED_LINKER_FLAGS}")
endif ()

## set warnings
set_cflags_if_supported(
  -Wextra
  -Wbad-function-cast
  -Wno-missing-noreturn
  -Wstrict-prototypes
  -Wmissing-prototypes
  -Wmissing-declarations
  -Wpointer-arith
  -Wmissing-format-attribute
  -Wshadow
  ## other flags to try:
  #-Wunsafe-loop-optimizations
  #-Wpointer-arith
  #-Wc++-compat
  #-Wc++11-compat
  #-Wwrite-strings
  #-Wzero-as-null-pointer-constant
  #-Wlogical-op
  #-Wvector-optimization-performance
  )

if (CMAKE_CXX_COMPILER_ID STREQUAL Clang)
  message(WARNING "Disabling -Wcast-align with clang.  TODO: fix casting and re-enable it.")
else ()
  set_cflags_if_supported(-Wcast-align)
endif ()

## always want these
set(CMAKE_C_FLAGS "-Wall -Werror ${CMAKE_C_FLAGS}")
set(CMAKE_CXX_FLAGS "-Wall -Werror ${CMAKE_CXX_FLAGS}")

## need to set -stdlib=libc++ to get real c++11 support on darwin
if (APPLE)
  if (CMAKE_GENERATOR STREQUAL Xcode)
    set(CMAKE_XCODE_ATTRIBUTE_CLANG_CXX_LIBRARY "libc++")
  else ()
    add_definitions(-stdlib=libc++)
  endif ()
endif ()

# pick language dialect
set(CMAKE_C_FLAGS "-std=c99 ${CMAKE_C_FLAGS}")
check_cxx_compiler_flag(-std=c++11 HAVE_STDCXX11)
check_cxx_compiler_flag(-std=c++0x HAVE_STDCXX0X)
if (HAVE_STDCXX11)
  set(CMAKE_CXX_FLAGS "-std=c++11 ${CMAKE_CXX_FLAGS}")
elseif (HAVE_STDCXX0X)
  set(CMAKE_CXX_FLAGS "-std=c++0x ${CMAKE_CXX_FLAGS}")
else ()
  message(FATAL_ERROR "${CMAKE_CXX_COMPILER} doesn't support -std=c++11 or -std=c++0x, you need one that does.")
endif ()

function(add_space_separated_property type obj propname val)
  get_property(oldval ${type} ${obj} PROPERTY ${propname})
  if (oldval MATCHES NOTFOUND)
    set_property(${type} ${obj} PROPERTY ${propname} "${val}")
  else ()
    set_property(${type} ${obj} PROPERTY ${propname} "${val} ${oldval}")
  endif ()
endfunction(add_space_separated_property)

## this function makes sure that the libraries passed to it get compiled
## with gcov-needed flags, we only add those flags to our libraries
## because we don't really care whether our tests get covered
function(maybe_add_gcov_to_libraries)
  if (USE_GCOV)
    foreach(lib ${ARGN})
      add_space_separated_property(TARGET ${lib} COMPILE_FLAGS --coverage)
      add_space_separated_property(TARGET ${lib} LINK_FLAGS --coverage)
      target_link_libraries(${lib} gcov)
    endforeach(lib)
  endif (USE_GCOV)
endfunction(maybe_add_gcov_to_libraries)
