include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(OHNavi_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(OHNavi_setup_options)
  option(OHNavi_ENABLE_HARDENING "Enable hardening" ON)
  option(OHNavi_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    OHNavi_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    OHNavi_ENABLE_HARDENING
    OFF)

  OHNavi_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR OHNavi_PACKAGING_MAINTAINER_MODE)
    option(OHNavi_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(OHNavi_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(OHNavi_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(OHNavi_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(OHNavi_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(OHNavi_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(OHNavi_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(OHNavi_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(OHNavi_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(OHNavi_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(OHNavi_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(OHNavi_ENABLE_PCH "Enable precompiled headers" OFF)
    option(OHNavi_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(OHNavi_ENABLE_IPO "Enable IPO/LTO" ON)
    option(OHNavi_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(OHNavi_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(OHNavi_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(OHNavi_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(OHNavi_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(OHNavi_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(OHNavi_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(OHNavi_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(OHNavi_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(OHNavi_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(OHNavi_ENABLE_PCH "Enable precompiled headers" OFF)
    option(OHNavi_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      OHNavi_ENABLE_IPO
      OHNavi_WARNINGS_AS_ERRORS
      OHNavi_ENABLE_USER_LINKER
      OHNavi_ENABLE_SANITIZER_ADDRESS
      OHNavi_ENABLE_SANITIZER_LEAK
      OHNavi_ENABLE_SANITIZER_UNDEFINED
      OHNavi_ENABLE_SANITIZER_THREAD
      OHNavi_ENABLE_SANITIZER_MEMORY
      OHNavi_ENABLE_UNITY_BUILD
      OHNavi_ENABLE_CLANG_TIDY
      OHNavi_ENABLE_CPPCHECK
      OHNavi_ENABLE_COVERAGE
      OHNavi_ENABLE_PCH
      OHNavi_ENABLE_CACHE)
  endif()

  OHNavi_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (OHNavi_ENABLE_SANITIZER_ADDRESS OR OHNavi_ENABLE_SANITIZER_THREAD OR OHNavi_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(OHNavi_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(OHNavi_global_options)
  if(OHNavi_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    OHNavi_enable_ipo()
  endif()

  OHNavi_supports_sanitizers()

  if(OHNavi_ENABLE_HARDENING AND OHNavi_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR OHNavi_ENABLE_SANITIZER_UNDEFINED
       OR OHNavi_ENABLE_SANITIZER_ADDRESS
       OR OHNavi_ENABLE_SANITIZER_THREAD
       OR OHNavi_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${OHNavi_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${OHNavi_ENABLE_SANITIZER_UNDEFINED}")
    OHNavi_enable_hardening(OHNavi_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(OHNavi_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(OHNavi_warnings INTERFACE)
  add_library(OHNavi_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  OHNavi_set_project_warnings(
    OHNavi_warnings
    ${OHNavi_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(OHNavi_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(OHNavi_options)
  endif()

  include(cmake/Sanitizers.cmake)
  OHNavi_enable_sanitizers(
    OHNavi_options
    ${OHNavi_ENABLE_SANITIZER_ADDRESS}
    ${OHNavi_ENABLE_SANITIZER_LEAK}
    ${OHNavi_ENABLE_SANITIZER_UNDEFINED}
    ${OHNavi_ENABLE_SANITIZER_THREAD}
    ${OHNavi_ENABLE_SANITIZER_MEMORY})

  set_target_properties(OHNavi_options PROPERTIES UNITY_BUILD ${OHNavi_ENABLE_UNITY_BUILD})

  if(OHNavi_ENABLE_PCH)
    target_precompile_headers(
      OHNavi_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(OHNavi_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    OHNavi_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(OHNavi_ENABLE_CLANG_TIDY)
    OHNavi_enable_clang_tidy(OHNavi_options ${OHNavi_WARNINGS_AS_ERRORS})
  endif()

  if(OHNavi_ENABLE_CPPCHECK)
    OHNavi_enable_cppcheck(${OHNavi_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(OHNavi_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    OHNavi_enable_coverage(OHNavi_options)
  endif()

  if(OHNavi_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(OHNavi_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(OHNavi_ENABLE_HARDENING AND NOT OHNavi_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR OHNavi_ENABLE_SANITIZER_UNDEFINED
       OR OHNavi_ENABLE_SANITIZER_ADDRESS
       OR OHNavi_ENABLE_SANITIZER_THREAD
       OR OHNavi_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    OHNavi_enable_hardening(OHNavi_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
