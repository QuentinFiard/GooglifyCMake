include(ExternalProject)

# Options and paths to external libraries.
option(SKIP_PORTABILITY_WARNINGS "Skip portability warnings" OFF)
# Set the following two values to use external Boost libraries.
set(BOOST_ROOT "" CACHE STRING "Boost install directory")
set(BOOST_TIME_ZONE_CSV "" CACHE STRING "Boost time zone csv datafile")
if (IS_IOS)
  set(ICU_CROSS_BUILD "" CACHE STRING "ICU executable build")
  if (NOT ICU_CROSS_BUILD)
    message(WARNING "Please define ICU_CROSS_BUILD if you intend to compile ICU.")
  endif ()
endif ()

set(SUPPORT_DIR ${CMAKE_CURRENT_LIST_DIR}/support)
set(THIRD_PARTY_BINARY_DIR ${PROJECT_BINARY_DIR}/third_party)
set(THIRD_PARTY_SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/third_party)

# Required to disable steps in an external project.
set(NOP echo "")

# Required executables.
find_program(ANT ant)
if (${ANT} STREQUAL ANT-NOTFOUND)
  message(FATAL_ERROR "Please install Ant available at http://ant.apache.org/.")
endif ()
find_program(GIT git)
if (${GIT} STREQUAL GIT-NOTFOUND)
  message(FATAL_ERROR "Please install Git available at http://git-scm.com/.")
endif ()
find_program(HG hg)
if (${HG} STREQUAL HG-NOTFOUND)
  message(FATAL_ERROR "Please install Mercurial available at http://mercurial.selenic.com.")
endif ()
find_program(SVN svn)
if (${SVN} STREQUAL SVN-NOTFOUND)
  message(FATAL_ERROR "Please install SVN available at http://subversion.apache.org/.")
endif ()

set(SET_INSTALL_NAMES "${SUPPORT_DIR}/set_install_names.sh")
set(CREATE_FAT_LIBS "${SUPPORT_DIR}/create_fat_libs.sh")

################################################################################
# Public interface.
################################################################################
function(get_include_directories LIB OUT)
  set(${OUT} ${${${LIB}_target}_includes} PARENT_SCOPE)
endfunction()

function(get_libraries LIB OUT)
  set(${OUT} ${${LIB}} PARENT_SCOPE)
endfunction()

function(get_target LIB OUT)
  set(TARGET ${${LIB}_target})
  if ("${TARGET}" STREQUAL "")
    set(${OUT} ${LIB}-NOTFOUND PARENT_SCOPE)
    return()
  endif ()
  set(${OUT} ${TARGET} PARENT_SCOPE)
endfunction()

################################################################################
# Private interface.
################################################################################
function(set_prefix OUT PREFIX)
  set(${OUT} ${THIRD_PARTY_BINARY_DIR}/${PREFIX} PARENT_SCOPE)
endfunction()

function(add_target OUT NAME)
  set(${OUT}_PREFIX ${THIRD_PARTY_BINARY_DIR}/${NAME} PARENT_SCOPE)
  set(TARGET third_party.${NAME}_target)
  set(${OUT}_TARGET ${TARGET} PARENT_SCOPE)
  set(${TARGET} ${TARGET} PARENT_SCOPE)
endfunction()

macro(set_libraries NAME DIR)
  # Defines the target of the library, by default it is equal to the name of
  # library suffixed with _target.
  set(FULL_NAME third_party.${NAME})
  set(${FULL_NAME}_target ${FULL_NAME}_target)
  set(third_party.${NAME})
  if (BUILD_SHARED_LIBS AND NOT "${DIR}" STREQUAL "")
    list(APPEND third_party.${NAME} -L${DIR})
  endif ()
  foreach (LIB ${ARGN})
    if (BUILD_SHARED_LIBS)
      list(APPEND third_party.${NAME} -l${LIB})
    else ()
      list(APPEND third_party.${NAME} ${DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}${LIB}${CMAKE_STATIC_LIBRARY_SUFFIX})
    endif ()
  endforeach ()
endmacro()

macro(set_target_for_libraries TARGET)
  foreach (LIB ${ARGN})
    set(third_party.${LIB}_target ${TARGET})
  endforeach ()
endmacro()

macro(add_framework_dependencies NAME)
  foreach (FRAMEWORK ${ARGN})
    list(APPEND third_party.${NAME} "-framework ${FRAMEWORK}")
  endforeach ()
endmacro()

macro(add_library_dependencies NAME)
  foreach (LIB ${ARGN})
    if (NOT DEFINED ${LIB})
      # We assume that LIB is a system library.
      list(APPEND third_party.${NAME} -l${LIB})
    else ()
      list(APPEND third_party.${NAME} ${${LIB}})
    endif ()
  endforeach ()
endmacro()

macro(add_include_dependencies NAME)
  get_include_directories(third_party.${NAME} INCLUDES)
  foreach (LIB ${ARGN})
    get_include_directories(${LIB} LIB_INCLUDES)
    list(APPEND INCLUDES ${LIB_INCLUDES})
  endforeach ()
  set_include_directories(${NAME} ${INCLUDES})
endmacro()

function(add_external_project NAME)
  if (NOT "$ENV{BUILD_3RD_PARTY_LIBRARIES}")
    return ()
  endif ()
  ExternalProject_Add(${NAME} ${ARGN})
  set_target_properties(${NAME} PROPERTIES EXCLUDE_FROM_ALL TRUE)
  if (NOT NAME MATCHES "^third_party.libcxx")
    add_dependencies(${NAME} ${LIBCXX_TARGET})
  endif ()
endfunction()

function(add_external_project_step)
  if (NOT "$ENV{BUILD_3RD_PARTY_LIBRARIES}")
    return ()
  endif ()
  ExternalProject_Add_Step(${ARGN})
endfunction()

function(set_include_directories LIB)
  set(TARGET ${third_party.${LIB}_target})
  set(INCLUDE_DIRECTORIES ${TARGET}_includes)
  set(${INCLUDE_DIRECTORIES} ${ARGN} PARENT_SCOPE)
endfunction()

function(add_install_name_step LIB)
  if (NOT "$ENV{BUILD_3RD_PARTY_LIBRARIES}")
    return ()
  endif ()
  if (BUILD_SHARED_LIBS)
    add_external_project_step(${${LIB}_TARGET} set_install_names
      COMMAND
          ${SET_INSTALL_NAMES} ${CMAKE_INSTALL_NAME_TOOL}
              ${CMAKE_SHARED_LIBRARY_SUFFIX}
      DEPENDEES install
      DEPENDS ${SET_INSTALL_NAMES}
      WORKING_DIRECTORY ${${LIB}_PREFIX}/lib)
  endif ()
endfunction()

function(add_target_dependencies LIB)
  if (NOT "$ENV{BUILD_3RD_PARTY_LIBRARIES}")
    return ()
  endif ()
  set(TARGET "${${LIB}_TARGET}")
  add_dependencies(${TARGET} ${ARGN})
endfunction()

function(get_source_dir LIB OUT)
  set(${OUT} "${${LIB}_PREFIX}/src/${${LIB}_TARGET}" PARENT_SCOPE)
endfunction()

function(get_download_target LIB OUT)
  set(${OUT} "${${LIB}_TARGET}_download" PARENT_SCOPE)
endfunction()

function(get_download_source_dir LIB OUT)
  get_download_target(${LIB} DOWNLOAD_TARGET)
  set(${OUT} "${${LIB}_PREFIX}/src/${DOWNLOAD_TARGET}" PARENT_SCOPE)
endfunction()



# Forward declarations.
add_target(AFNETWORKING afnetworking)
add_target(APR apr)
add_target(APR_UTIL apr-util)
add_target(ARABICA arabica)
add_target(BERKELEY_DB berkeley-db)
add_target(BISON bison)
add_target(BOOST boost)
add_target(BSDIFF bsdiff)
add_target(BZIP2 bzip2)
add_target(CAIRO cairo)
add_target(CLANG clang)
add_target(CLANG_OMP clang_omp)
add_target(CLDR cldr)
add_target(CLOSURE_COMPILER closure-compiler)
add_target(CLOSURE_LIBRARY closure-library)
add_target(CLUSTER cluster)
add_target(COUNTRY_INFOS country_infos)
add_target(CPP_NETLIB cpp-netlib)
add_target(CPP_NETLIB_URI cpp-netlib-uri)
add_target(CURL_ASIO curl-asio)
add_target(DIFF_MATCH_PATCH diff_match_patch)
add_target(DLIB dlib)
add_target(EIGEN eigen)
add_target(EXTRAE extrae)
add_target(FAST_IMAGE_CACHE fast_image_cache)
add_target(FB_GALLERY fb_gallery)
add_target(FFTW fftw)
add_target(FLEX flex)
add_target(FORMATTER_KIT formatter_kit)
add_target(FREETYPE freetype)
add_target(G2LOG g2log)
add_target(GCC gcc)
add_target(GDK_PIXBUF gdk-pixbuf)
add_target(GETTEXT gettext)
add_target(GFLAGS gflags)
add_target(GLIB glib)
add_target(GMOCK gmock)
add_target(GMP gmp)
add_target(GNOME_COMMON gnome-common)
add_target(GNUAUTOMAKE gnuautomake)
add_target(GNUBASH gnubash)
add_target(GNUGREP gnugrep)
add_target(GNUTAR gnutar)
add_target(GTEST gtest)
add_target(HAPROXY haproxy)
add_target(HTTPD httpd)
add_target(HTTPXX httpxx)
add_target(HWLOC hwloc)
add_target(ICU icu)
add_target(IMAGEMAGICK imagemagick)
add_target(IMAP_2007F imap-2007f)
add_target(INTEL_PCM intel_pcm)
add_target(IOS_NTP ios_ntp)
add_target(ISO_3166 iso_3166)
add_target(ISO_639 iso_639)
add_target(ISO_COUNTRY_FLAGS iso-country-flags)
add_target(IWYU iwyu)
add_target(JSONCPP jsoncpp)
add_target(JSONPATH jsonpath)
add_target(LDAP ldap)
add_target(LDAP_SASL ldap_sasl)
add_target(LEVELDB leveldb)
add_target(LIBCROCO libcroco)
add_target(LIBCURL libcurl)
add_target(LIBCXX libcxx)
add_target(LIBCXXABI libcxxabi)
add_target(LIBFFI libffi)
add_target(LIBICONV libiconv)
add_target(LIBJPG libjpg)
add_target(LIBMCRYPT libmcrypt)
add_target(LIBMHASH libmhash)
add_target(LIBPNG libpng)
add_target(LIBRSVG librsvg)
add_target(LIBUSB libusb)
add_target(LIBXML libxml)
add_target(LMDB lmdb)
add_target(LPSOLVE lpsolve)
add_target(MARISA_TRIE marisa_trie)
add_target(MAVEN maven)
add_target(MAVEN_LIBS maven_libs)
add_target(MCRYPT mcrypt)
add_target(MILI mili)
add_target(MOBILE_COMMERCE_IOS mobile_commerce_ios)
add_target(MOD_JK mod_jk)
add_target(MOD_WSGI mod_wsgi)
add_target(MPC mpc)
add_target(MPFR mpfr)
add_target(MPICH mpich)
add_target(MW_PHOTO_BROWSER mw_photo_browser)
add_target(MYSQL mysql)
add_target(MYSQLCPPCONN mysqlcppconn)
add_target(NGINX nginx)
add_target(NJK_WEB_VIEW_PROGRESS njk_web_view_progress)
add_target(NTP ntp)
add_target(OPENCV opencv)
add_target(OPENMP openmp)
add_target(OPENMPI openmpi)
add_target(OPENSSL openssl)
add_target(PANGO pango)
add_target(PAPI papi)
add_target(PCRE pcre)
add_target(PHP php)
add_target(PIXMAN pixman)
add_target(PKG_CONFIG pkg-config)
add_target(PRETTY_KIT pretty_kit)
add_target(PROTOBUF protobuf)
add_target(PROTOC protoc)
add_target(PROXY_LIBINTL proxy-libintl)
add_target(RAPIDXML rapidxml)
add_target(READLINE readline)
add_target(SHARK shark)
add_target(SQLITE3 sqlite3)
add_target(SSTOOLKIT sstoolkit)
add_target(SW_REVEAL_VIEW_CONTROLLER sw_reveal_view_controller)
add_target(TBB tbb)
add_target(UIALERTVIEW_BLOCKS uialertview_blocks)
add_target(UIIMAGE_ANIMATED_GIF uiimage_animated_gif)
add_target(VIRTUALENV virtualenv)
add_target(XZ xz)
add_target(ZLIB zlib)

# Library directories.
if ("${BOOST_ROOT}" STREQUAL "")
  set(BOOST_LIB_DIR ${BOOST_PREFIX}/lib)
else ()
  set(BOOST_LIB_DIR ${BOOST_ROOT}/lib)
endif ()
set(CLANG_LIB_DIR ${CLANG_PREFIX}/lib)
set(LLVM_LIB_DIR ${CLANG_LIB_DIR})
set(OPENCV_LIB_DIR ${OPENCV_PREFIX}/lib)

# Third-party libraries definitions.
set_libraries(afnetworking ${AFNETWORKING_PREFIX}/lib afnetworking)
set_libraries(arabica ${ARABICA_PREFIX}/lib arabica)
set_libraries(boost_atomic ${BOOST_LIB_DIR} boost_atomic)
set_libraries(boost_chrono ${BOOST_LIB_DIR} boost_chrono)
set_libraries(boost_context ${BOOST_LIB_DIR} boost_context)
set_libraries(boost_coroutine ${BOOST_LIB_DIR} boost_coroutine)
set_libraries(boost_date_time ${BOOST_LIB_DIR} boost_date_time)
set_libraries(boost_exception ${BOOST_LIB_DIR} boost_exception)
set_libraries(boost_filesystem ${BOOST_LIB_DIR} boost_filesystem)
set_libraries(boost_graph ${BOOST_LIB_DIR} boost_graph)
set_libraries(boost_graph_parallel ${BOOST_LIB_DIR} boost_graph_parallel)
set_libraries(boost_iostreams ${BOOST_LIB_DIR} boost_iostreams)
set_libraries(boost_locale ${BOOST_LIB_DIR} boost_locale)
set_libraries(boost_log ${BOOST_LIB_DIR} boost_log)
set_libraries(boost_math ${BOOST_LIB_DIR} boost_math)
set_libraries(boost_mpi ${BOOST_LIB_DIR} boost_mpi)
set_libraries(boost_program_options ${BOOST_LIB_DIR} boost_program_options)
set_libraries(boost_python ${BOOST_LIB_DIR} boost_python)
set_libraries(boost_random ${BOOST_LIB_DIR} boost_random)
set_libraries(boost_regex ${BOOST_LIB_DIR} boost_regex)
set_libraries(boost_serialization ${BOOST_LIB_DIR} boost_serialization)
set_libraries(boost_signals ${BOOST_LIB_DIR} boost_signals)
set_libraries(boost_system ${BOOST_LIB_DIR} boost_system)
set_libraries(boost_test ${BOOST_LIB_DIR} boost_test)
set_libraries(boost_thread ${BOOST_LIB_DIR} boost_thread)
set_libraries(boost_timer ${BOOST_LIB_DIR} boost_timer)
set_libraries(boost_wave ${BOOST_LIB_DIR} boost_wave)
set_libraries(bzip2 ${BZIP2_PREFIX}/lib bz2)
set_libraries(clang ${CLANG_LIB_DIR} clang)
set_libraries(clang_analysis ${CLANG_LIB_DIR} clangAnalysis)
set_libraries(clang_arcmigrate ${CLANG_LIB_DIR} clangARCMigrate)
set_libraries(clang_ast ${CLANG_LIB_DIR} clangAST)
set_libraries(clang_ast_matchers ${CLANG_LIB_DIR} clangASTMatchers)
set_libraries(clang_basic ${CLANG_LIB_DIR} clangBasic)
set_libraries(clang_code_gen ${CLANG_LIB_DIR} clangCodeGen)
set_libraries(clang_driver ${CLANG_LIB_DIR} clangDriver)
set_libraries(
    clang_dynamic_ast_matchers ${CLANG_LIB_DIR} clangDynamicASTMatchers)
set_libraries(clang_edit ${CLANG_LIB_DIR} clangEdit)
set_libraries(clang_format ${CLANG_LIB_DIR} clangFormat)
set_libraries(clang_frontend ${CLANG_LIB_DIR} clangFrontend)
set_libraries(clang_frontend_tool ${CLANG_LIB_DIR} clangFrontendTool)
set_libraries(clang_index ${CLANG_LIB_DIR} clangIndex)
set_libraries(clang_lex ${CLANG_LIB_DIR} clangLex)
set_libraries(clang_parse ${CLANG_LIB_DIR} clangParse)
set_libraries(clang_rewrite_core ${CLANG_LIB_DIR} clangRewriteCore)
set_libraries(clang_rewrite_frontend ${CLANG_LIB_DIR} clangRewriteFrontend)
set_libraries(clang_sema ${CLANG_LIB_DIR} clangSema)
set_libraries(clang_serialization ${CLANG_LIB_DIR} clangSerialization)
set_libraries(
    clang_static_analyzer_checkers ${CLANG_LIB_DIR} clangStaticAnalyzerCheckers)
set_libraries(
    clang_static_analyzer_core ${CLANG_LIB_DIR} clangStaticAnalyzerCore)
set_libraries(
    clang_static_analyzer_frontend ${CLANG_LIB_DIR} clangStaticAnalyzerFrontend)
set_libraries(clang_tooling ${CLANG_LIB_DIR} clangTooling)
set_libraries(cluster ${CLUSTER_PREFIX}/lib cluster)
set_libraries(cpp-netlib-uri ${CPP_NETLIB_URI_PREFIX}/lib network-uri)
set_libraries(curl-asio ${CURL_ASIO_PREFIX}/lib curlasio)
set_libraries(diff_match_patch ${DIFF_MATCH_PATCH_PREFIX}/lib diff_match_patch)
set_libraries(dlib ${DLIB_PREFIX}/lib dlib)
set_libraries(fast_image_cache ${FAST_IMAGE_CACHE_PREFIX}/lib fast_image_cache)
set_libraries(fb_gallery ${FB_GALLERY_PREFIX}/lib fb_gallery)
set_libraries(flex ${FLEX_PREFIX}/lib fl)
set_libraries(formatter_kit ${FORMATTER_KIT_PREFIX}/lib formatter_kit)
set_libraries(freetype ${FREETYPE_PREFIX}/lib freetype)
set_libraries(g2log ${G2LOG_PREFIX}/lib lib_activeobject lib_g2logger)
set_libraries(gflags ${GFLAGS_PREFIX}/lib gflags)
set_libraries(glib ${GLIB_PREFIX}/lib
              gio-2.0 glib-2.0 gmodule-2.0 gobject-2.0 gthread-2.0)
set_libraries(gmock ${GMOCK_PREFIX}/lib gmock gmock_main)
set_libraries(gmp ${GMP_PREFIX}/lib gmp)
set_libraries(gtest ${GTEST_PREFIX}/lib gtest gtest_main)
set_libraries(httpxx ${HTTPXX_PREFIX}/lib http_parser httpxx)
set_libraries(icu_data ${ICU_PREFIX}/lib icudata)
set_libraries(icu_i18n ${ICU_PREFIX}/lib icui18n)
set_libraries(icu_io ${ICU_PREFIX}/lib icuio)
set_libraries(icu_le ${ICU_PREFIX}/lib icule)
set_libraries(icu_lx ${ICU_PREFIX}/lib iculx)
set_libraries(icu_test ${ICU_PREFIX}/lib icutest)
set_libraries(icu_tu ${ICU_PREFIX}/lib icutu)
set_libraries(icu_uc ${ICU_PREFIX}/lib icuuc)
set_libraries(intel_pcm ${INTEL_PCM_PREFIX}/lib intel_pcm)
set_libraries(ios_ntp ${IOS_NTP_PREFIX}/lib ios_ntp)
set_libraries(imagemagick ${IMAGEMAGICK_PREFIX}/lib
              Magick++ MagickCore MagickWand)
set_libraries(jsoncpp ${JSONCPP_PREFIX}/lib jsoncpp)
set_libraries(jsonpath ${JSONPATH_PREFIX}/lib jsonpath)
set_libraries(hwloc ${HWLOC_PREFIX}/lib hwloc)
set_libraries(intel_pcm ${INTEL_PCM_PREFIX}/lib intel_pcm pthread)
set_libraries(leveldb ${LEVELDB_PREFIX}/lib leveldb)
set_libraries(libcurl ${LIBCURL_PREFIX}/lib curl)
set_libraries(libcxx ${LIBCXX_PREFIX}/lib c++)
set_libraries(libcxxabi ${LIBCXXABI_PREFIX}/lib c++abi)
set_libraries(libffi ${LIBFFI_PREFIX}/lib ffi)
set_libraries(libpng ${LIBPNG_PREFIX}/lib png)
set_libraries(libusb ${LIBUSB_PREFIX}/lib libusb-1.0)
if (IS_IOS)
  set(BUILD_SHARED_LIBS_OLD ${BUILD_SHARED_LIBS})
  set(BUILD_SHARED_LIBS ON)
  set_libraries(libxml ${CMAKE_IOS_SDK_ROOT}/usr/lib xml2)
  set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS_OLD})
else ()
  set_libraries(libxml ${LIBXML_PREFIX}/lib xml2)
endif ()
set_libraries(llvm_aarch64_asm_parser ${LLVM_LIB_DIR} LLVMAArch64AsmParser)
set_libraries(llvm_aarch64_asm_printer ${LLVM_LIB_DIR} LLVMAArch64AsmPrinter)
set_libraries(llvm_aarch64_code_gen ${LLVM_LIB_DIR} LLVMAArch64CodeGen)
set_libraries(llvm_aarch64_desc ${LLVM_LIB_DIR} LLVMAArch64Desc)
set_libraries(llvm_aarch64_disassembler ${LLVM_LIB_DIR} LLVMAArch64Disassembler)
set_libraries(llvm_aarch64_info ${LLVM_LIB_DIR} LLVMAArch64Info)
set_libraries(llvm_aarch64_utils ${LLVM_LIB_DIR} LLVMAArch64Utils)
set_libraries(llvm_analysis ${LLVM_LIB_DIR} LLVMAnalysis)
set_libraries(llvm_arm_asm_parser ${LLVM_LIB_DIR} LLVMARMAsmParser)
set_libraries(llvm_arm_asm_printer ${LLVM_LIB_DIR} LLVMARMAsmPrinter)
set_libraries(llvm_arm_code_gen ${LLVM_LIB_DIR} LLVMARMCodeGen)
set_libraries(llvm_arm_desc ${LLVM_LIB_DIR} LLVMARMDesc)
set_libraries(llvm_arm_disassembler ${LLVM_LIB_DIR} LLVMARMDisassembler)
set_libraries(llvm_arm_info ${LLVM_LIB_DIR} LLVMARMInfo)
set_libraries(llvm_asm_parser ${LLVM_LIB_DIR} LLVMAsmParser)
set_libraries(llvm_asm_printer ${LLVM_LIB_DIR} LLVMAsmPrinter)
set_libraries(llvm_bit_reader ${LLVM_LIB_DIR} LLVMBitReader)
set_libraries(llvm_bit_writer ${LLVM_LIB_DIR} LLVMBitWriter)
set_libraries(llvm_code_gen ${LLVM_LIB_DIR} LLVMCodeGen)
set_libraries(llvm_core ${LLVM_LIB_DIR} LLVMCore)
set_libraries(llvm_cpp_backend_code_gen ${LLVM_LIB_DIR} LLVMCppBackendCodeGen)
set_libraries(llvm_cpp_backend_info ${LLVM_LIB_DIR} LLVMCppBackendInfo)
set_libraries(llvm_debug_info ${LLVM_LIB_DIR} LLVMDebugInfo)
set_libraries(llvm_execution_engine ${LLVM_LIB_DIR} LLVMExecutionEngine)
set_libraries(llvm_hexagon_asm_printer ${LLVM_LIB_DIR} LLVMHexagonAsmPrinter)
set_libraries(llvm_hexagon_code_gen ${LLVM_LIB_DIR} LLVMHexagonCodeGen)
set_libraries(llvm_hexagon_desc ${LLVM_LIB_DIR} LLVMHexagonDesc)
set_libraries(llvm_hexagon_info ${LLVM_LIB_DIR} LLVMHexagonInfo)
set_libraries(llvm_inst_combine ${LLVM_LIB_DIR} LLVMInstCombine)
set_libraries(llvm_instrumentation ${LLVM_LIB_DIR} LLVMInstrumentation)
set_libraries(llvm_interpreter ${LLVM_LIB_DIR} LLVMInterpreter)
set_libraries(llvm_ipa ${LLVM_LIB_DIR} LLVMipa)
set_libraries(llvm_ipo ${LLVM_LIB_DIR} LLVMipo)
set_libraries(llvm_ir_reader ${LLVM_LIB_DIR} LLVMIRReader)
set_libraries(llvm_jit ${LLVM_LIB_DIR} LLVMJIT)
set_libraries(llvm_linker ${LLVM_LIB_DIR} LLVMLinker)
set_libraries(llvm_lto ${LLVM_LIB_DIR} LLVMLTO)
set_libraries(llvm_mc ${LLVM_LIB_DIR} LLVMMC)
set_libraries(llvm_mc_disassembler ${LLVM_LIB_DIR} LLVMMCDisassembler)
set_libraries(llvm_mc_jit ${LLVM_LIB_DIR} LLVMMCJIT)
set_libraries(llvm_mc_parser ${LLVM_LIB_DIR} LLVMMCParser)
set_libraries(llvm_mips_asm_parser ${LLVM_LIB_DIR} LLVMMipsAsmParser)
set_libraries(llvm_mips_asm_printer ${LLVM_LIB_DIR} LLVMMipsAsmPrinter)
set_libraries(llvm_mips_code_gen ${LLVM_LIB_DIR} LLVMMipsCodeGen)
set_libraries(llvm_mips_desc ${LLVM_LIB_DIR} LLVMMipsDesc)
set_libraries(llvm_mips_disassembler ${LLVM_LIB_DIR} LLVMMipsDisassembler)
set_libraries(llvm_mips_info ${LLVM_LIB_DIR} LLVMMipsInfo)
set_libraries(llvm_msp430_asm_printer ${LLVM_LIB_DIR} LLVMMSP430AsmPrinter)
set_libraries(llvm_msp430_code_gen ${LLVM_LIB_DIR} LLVMMSP430CodeGen)
set_libraries(llvm_msp430_desc ${LLVM_LIB_DIR} LLVMMSP430Desc)
set_libraries(llvm_msp430_info ${LLVM_LIB_DIR} LLVMMSP430Info)
set_libraries(llvm_nvptx_asm_printer ${LLVM_LIB_DIR} LLVMNVPTXAsmPrinter)
set_libraries(llvm_nvptx_code_gen ${LLVM_LIB_DIR} LLVMNVPTXCodeGen)
set_libraries(llvm_nvptx_desc ${LLVM_LIB_DIR} LLVMNVPTXDesc)
set_libraries(llvm_nvptx_info ${LLVM_LIB_DIR} LLVMNVPTXInfo)
set_libraries(llvm_obj_carcopts ${LLVM_LIB_DIR} LLVMObjCARCOpts)
set_libraries(llvm_object ${LLVM_LIB_DIR} LLVMObject)
set_libraries(llvm_option ${LLVM_LIB_DIR} LLVMOption)
set_libraries(llvm_power_pcasm_parser ${LLVM_LIB_DIR} LLVMPowerPCAsmParser)
set_libraries(llvm_power_pcasm_printer ${LLVM_LIB_DIR} LLVMPowerPCAsmPrinter)
set_libraries(llvm_power_pccode_gen ${LLVM_LIB_DIR} LLVMPowerPCCodeGen)
set_libraries(llvm_power_pcdesc ${LLVM_LIB_DIR} LLVMPowerPCDesc)
set_libraries(llvm_power_pcdisassembler ${LLVM_LIB_DIR} LLVMPowerPCDisassembler)
set_libraries(llvm_power_pcinfo ${LLVM_LIB_DIR} LLVMPowerPCInfo)
set_libraries(llvm_r600_asm_printer ${LLVM_LIB_DIR} LLVMR600AsmPrinter)
set_libraries(llvm_r600_code_gen ${LLVM_LIB_DIR} LLVMR600CodeGen)
set_libraries(llvm_r600_desc ${LLVM_LIB_DIR} LLVMR600Desc)
set_libraries(llvm_r600_info ${LLVM_LIB_DIR} LLVMR600Info)
set_libraries(llvm_runtime_dyld ${LLVM_LIB_DIR} LLVMRuntimeDyld)
set_libraries(llvm_scalar_opts ${LLVM_LIB_DIR} LLVMScalarOpts)
set_libraries(llvm_selection_dag ${LLVM_LIB_DIR} LLVMSelectionDAG)
set_libraries(llvm_sparc_asm_parser ${LLVM_LIB_DIR} LLVMSparcAsmParser)
set_libraries(llvm_sparc_asm_printer ${LLVM_LIB_DIR} LLVMSparcAsmPrinter)
set_libraries(llvm_sparc_code_gen ${LLVM_LIB_DIR} LLVMSparcCodeGen)
set_libraries(llvm_sparc_desc ${LLVM_LIB_DIR} LLVMSparcDesc)
set_libraries(llvm_sparc_disassembler ${LLVM_LIB_DIR} LLVMSparcDisassembler)
set_libraries(llvm_sparc_info ${LLVM_LIB_DIR} LLVMSparcInfo)
set_libraries(llvm_support ${LLVM_LIB_DIR} LLVMSupport)
set_libraries(llvm_system_zasm_parser ${LLVM_LIB_DIR} LLVMSystemZAsmParser)
set_libraries(llvm_system_zasm_printer ${LLVM_LIB_DIR} LLVMSystemZAsmPrinter)
set_libraries(llvm_system_zcode_gen ${LLVM_LIB_DIR} LLVMSystemZCodeGen)
set_libraries(llvm_system_zdesc ${LLVM_LIB_DIR} LLVMSystemZDesc)
set_libraries(llvm_system_zdisassembler ${LLVM_LIB_DIR} LLVMSystemZDisassembler)
set_libraries(llvm_system_zinfo ${LLVM_LIB_DIR} LLVMSystemZInfo)
set_libraries(llvm_table_gen ${LLVM_LIB_DIR} LLVMTableGen)
set_libraries(llvm_target ${LLVM_LIB_DIR} LLVMTarget)
set_libraries(llvm_transform_utils ${LLVM_LIB_DIR} LLVMTransformUtils)
set_libraries(llvm_vectorize ${LLVM_LIB_DIR} LLVMVectorize)
set_libraries(llvm_x86_asm_parser ${LLVM_LIB_DIR} LLVMX86AsmParser)
set_libraries(llvm_x86_asm_printer ${LLVM_LIB_DIR} LLVMX86AsmPrinter)
set_libraries(llvm_x86_code_gen ${LLVM_LIB_DIR} LLVMX86CodeGen)
set_libraries(llvm_x86_desc ${LLVM_LIB_DIR} LLVMX86Desc)
set_libraries(llvm_x86_disassembler ${LLVM_LIB_DIR} LLVMX86Disassembler)
set_libraries(llvm_x86_info ${LLVM_LIB_DIR} LLVMX86Info)
set_libraries(llvm_x86_utils ${LLVM_LIB_DIR} LLVMX86Utils)
set_libraries(llvm_xcore_asm_printer ${LLVM_LIB_DIR} LLVMXCoreAsmPrinter)
set_libraries(llvm_xcore_code_gen ${LLVM_LIB_DIR} LLVMXCoreCodeGen)
set_libraries(llvm_xcore_desc ${LLVM_LIB_DIR} LLVMXCoreDesc)
set_libraries(llvm_xcore_disassembler ${LLVM_LIB_DIR} LLVMXCoreDisassembler)
set_libraries(llvm_xcore_info ${LLVM_LIB_DIR} LLVMXCoreInfo)
set_libraries(lmdb ${LMDB_PREFIX}/lib lmdb)
set_libraries(lpsolve ${LPSOLVE_PREFIX}/lib lpsolve55)
set_libraries(marisa_trie ${MARISA_TRIE_PREFIX}/lib marisa)
set_libraries(mili "")  # Mili is header only.
set_libraries(mobile_commerce_ios_atg_mobile_client
              ${MOBILE_COMMERCE_IOS_PREFIX}/lib ATGMobileClient)
set_libraries(mobile_commerce_ios_atg_gui_elements
              ${MOBILE_COMMERCE_IOS_PREFIX}/lib ATGUIElements)
set_libraries(mobile_commerce_ios_ios_rest_client
              ${MOBILE_COMMERCE_IOS_PREFIX}/lib iOS-rest-client)
set_libraries(mobile_commerce_ios_atg_mobile_common
              ${MOBILE_COMMERCE_IOS_PREFIX}/lib ATGMobileCommon)
set_libraries(mobile_commerce_ios_em_mobile_client
              ${MOBILE_COMMERCE_IOS_PREFIX}/lib EMMobileClient)
set_libraries(mpc ${MPC_PREFIX}/lib mpc)
set_libraries(mpfr ${MPFR_PREFIX}/lib mpfr)
set_libraries(mw_photo_browser ${MW_PHOTO_BROWSER_PREFIX}/lib MWPhotoBrowser)
set_libraries(mysqlcppconn ${MYSQLCPPCONN_PREFIX}/lib mysqlcppconn)
set_libraries(njk_web_view_progress ${NJK_WEB_VIEW_PROGRESS_PREFIX}/lib
              njk_web_view_progress)
set_libraries(opencv_bioinspired ${OPENCV_LIB_DIR} opencv_bioinspired)
set_libraries(opencv_calib3d ${OPENCV_LIB_DIR} opencv_calib3d)
set_libraries(opencv_contrib ${OPENCV_LIB_DIR} opencv_contrib)
set_libraries(opencv_core ${OPENCV_LIB_DIR} opencv_core)
set_libraries(opencv_cuda ${OPENCV_LIB_DIR} opencv_cuda)
set_libraries(opencv_cudaarithm ${OPENCV_LIB_DIR} opencv_cudaarithm)
set_libraries(opencv_cudabgsegm ${OPENCV_LIB_DIR} opencv_cudabgsegm)
set_libraries(opencv_cudafeatures2d ${OPENCV_LIB_DIR} opencv_cudafeatures2d)
set_libraries(opencv_cudafilters ${OPENCV_LIB_DIR} opencv_cudafilters)
set_libraries(opencv_cudaimgproc ${OPENCV_LIB_DIR} opencv_cudaimgproc)
set_libraries(opencv_cudaoptflow ${OPENCV_LIB_DIR} opencv_cudaoptflow)
set_libraries(opencv_cudastereo ${OPENCV_LIB_DIR} opencv_cudastereo)
set_libraries(opencv_cudawarping ${OPENCV_LIB_DIR} opencv_cudawarping)
set_libraries(opencv_features2d ${OPENCV_LIB_DIR} opencv_features2d)
set_libraries(opencv_flann ${OPENCV_LIB_DIR} opencv_flann)
set_libraries(opencv_highgui ${OPENCV_LIB_DIR} opencv_highgui)
set_libraries(opencv_imgproc ${OPENCV_LIB_DIR} opencv_imgproc)
set_libraries(opencv_legacy ${OPENCV_LIB_DIR} opencv_legacy)
set_libraries(opencv_ml ${OPENCV_LIB_DIR} opencv_ml)
set_libraries(opencv_nonfree ${OPENCV_LIB_DIR} opencv_nonfree)
set_libraries(opencv_objdetect ${OPENCV_LIB_DIR} opencv_objdetect)
set_libraries(opencv_ocl ${OPENCV_LIB_DIR} opencv_ocl)
set_libraries(opencv_optim ${OPENCV_LIB_DIR} opencv_optim)
set_libraries(opencv_photo ${OPENCV_LIB_DIR} opencv_photo)
set_libraries(opencv_shape ${OPENCV_LIB_DIR} opencv_shape)
set_libraries(opencv_softcascade ${OPENCV_LIB_DIR} opencv_softcascade)
set_libraries(opencv_stitching ${OPENCV_LIB_DIR} opencv_stitching)
set_libraries(opencv_superres ${OPENCV_LIB_DIR} opencv_superres)
set_libraries(opencv_ts ${OPENCV_LIB_DIR} opencv_ts)
set_libraries(opencv_video ${OPENCV_LIB_DIR} opencv_video)
set_libraries(opencv_videostab ${OPENCV_LIB_DIR} opencv_videostab)
set_libraries(openmp ${OPENMP_PREFIX}/lib iomp5)
set_libraries(openssl ${OPENSSL_PREFIX}/lib crypto ssl)
set_libraries(pretty_kit ${PRETTY_KIT_PREFIX}/lib pretty_kit)
set_libraries(protobuf ${PROTOBUF_PREFIX}/lib protobuf)
set_libraries(readline ${READLINE_PREFIX}/lib readline history)
set_libraries(shark ${SHARK_PREFIX}/lib shark)
set_libraries(sqlite3 ${SQLITE3_PREFIX}/lib sqlite3)
set_libraries(sstoolkit ${SSTOOLKIT_PREFIX}/lib SSToolkit)
set_libraries(sw_reveal_view_controller ${SW_REVEAL_VIEW_CONTROLLER_PREFIX}/lib
              sw_reveal_view_controller)
set_libraries(tbb ${TBB_PREFIX}/lib tbb)
set_libraries(uialertview_blocks ${UIALERTVIEW_BLOCKS_PREFIX}/lib
              uialertview_blocks)
set_libraries(uiimage_animated_gif ${UIIMAGE_ANIMATED_GIF_PREFIX}/lib
              uiimage_animated_gif)
set_libraries(zlib ${ZLIB_PREFIX}/lib z)


if (IS_IOS)
  set(BZ2_LIB bz2)
else ()
  set(BZ2_LIB third_party.bzip2)
endif ()

# Dependencies. We must be careful to define a DAG.
add_framework_dependencies(
    afnetworking CoreGraphics MobileCoreServices Security SystemConfiguration
    UIKit)
add_framework_dependencies(sw_reveal_view_controller CoreGraphics)

add_library_dependencies(boost_filesystem third_party.boost_system)
add_library_dependencies(boost_log third_party.boost_filesystem)
add_library_dependencies(
    boost_thread third_party.boost_atomic third_party.boost_system)
add_library_dependencies(boost_iostreams ${BZ2_LIB})
add_library_dependencies(cpp-netlib-uri third_party.boost_system)
add_framework_dependencies(formatter_kit AddressBook AddressBookUI CoreLocation)
add_library_dependencies(gtest pthread)
add_library_dependencies(intel_pcm pthread)
add_framework_dependencies(ios_ntp CFNetwork CoreGraphics UIKit)
add_framework_dependencies(mw_photo_browser AssetsLibrary MapKit MessageUI)
add_library_dependencies(openssl third_party.gmp)
add_library_dependencies(libcurl third_party.zlib)
if (NOT APPLE OR IS_IOS)
  add_library_dependencies(libcurl third_party.openssl)
endif ()
add_library_dependencies(curl-asio third_party.boost_system third_party.libcurl)
add_library_dependencies(readline ncurses)
add_library_dependencies(shark third_party.boost_serialization)
add_library_dependencies(protobuf third_party.zlib)
if (IS_IOS)
  add_library_dependencies(libxml xml2)
endif ()
add_library_dependencies(
    arabica third_party.boost_thread third_party.boost_system
    third_party.libxml)
add_library_dependencies(
    imagemagick third_party.libpng third_party.libxml ${BZ2_LIB}
    third_party.freetype third_party.zlib)

add_library_dependencies(mobile_commerce_ios_atg_mobile_common
                         third_party.mobile_commerce_ios_ios_rest_client)
add_framework_dependencies(
    mobile_commerce_ios_atg_mobile_common CoreData SystemConfiguration)
add_framework_dependencies(uialertview_blocks UIKit)
add_framework_dependencies(uiimage_animated_gif ImageIO)

# Aliases.
add_library_dependencies(boost_asio third_party.boost_system)

# Corrects library targets for modular libraries.
set_target_for_libraries(
    ${BOOST_TARGET} boost_asio boost_atomic boost_chrono boost_context
    boost_coroutine boost_date_time boost_exception boost_filesystem boost_graph
    boost_graph_parallel boost_headers boost_iostreams boost_locale boost_log
    boost_math boost_mpi boost_program_options boost_python boost_random
    boost_regex boost_serialization boost_signals boost_system boost_test
    boost_thread boost_timer boost_wave)
set_target_for_libraries(
    ${CLANG_TARGET} clang clang_analysis clang_arc_migrate clang_ast
    clang_ast_matchers clang_basic clang_code_gen clang_driver
    clang_dynamic_ast_matchers clang_edit clang_format clang_frontend
    clang_frontend_tool clang_index clang_lex clang_parse clang_rewrite_core
    clang_rewrite_frontend clang_sema clang_serialization
    clang_static_analyzer_checkers clang_static_analyzer_core
    clang_static_analyzer_frontend clang_tooling)
set_target_for_libraries(${ICU_TARGET} icu_data icu_i18n icu_io icu_le icu_lx
                         icu_test icu_tu icu_uc)
set_target_for_libraries(
    ${CLANG_TARGET} llvm_aarch64_asm_parser llvm_aarch64_asm_printer
    llvm_aarch64_code_gen llvm_aarch64_desc llvm_aarch64_disassembler
    llvm_aarch64_info llvm_aarch64_utils llvm_analysis llvm_arm_asm_parser
    llvm_arm_asm_printer llvm_arm_code_gen llvm_arm_desc llvm_arm_disassembler
    llvm_arm_info llvm_asm_parser llvm_asm_printer llvm_bit_reader
    llvm_bit_writer llvm_code_gen llvm_core llvm_cpp_backend_code_gen
    llvm_cpp_backend_info llvm_debug_info llvm_execution_engine
    llvm_hexagon_asm_printer llvm_hexagon_code_gen llvm_hexagon_desc
    llvm_hexagon_info llvm_inst_combine llvm_instrumentation llvm_interpreter
    llvm_ipa llvm_ipo llvm_ir_reader llvm_jit llvm_linker llvm_lto llvm_mc
    llvm_mc_disassembler llvm_mc_jit llvm_mc_parser llvm_mips_asm_parser
    llvm_mips_asm_printer llvm_mips_code_gen llvm_mips_desc
    llvm_mips_disassembler llvm_mips_info llvm_msp430_asm_printer
    llvm_msp430_code_gen llvm_msp430_desc llvm_msp430_info
    llvm_nvptx_asm_printer llvm_nvptx_code_gen llvm_nvptx_desc llvm_nvptx_info
    llvm_obj_carcopts llvm_object llvm_option llvm_power_pcasm_parser
    llvm_power_pcasm_printer llvm_power_pccode_gen llvm_power_pcdesc
    llvm_power_pcdisassembler llvm_power_pcinfo llvm_r600_asm_printer
    llvm_r600_code_gen llvm_r600_desc llvm_r600_info llvm_runtime_dyld
    llvm_scalar_opts llvm_selection_dag llvm_sparc_asm_parser
    llvm_sparc_asm_printer llvm_sparc_code_gen llvm_sparc_desc
    llvm_sparc_disassembler llvm_sparc_info llvm_support llvm_system_zasm_parser
    llvm_system_zasm_printer llvm_system_zcode_gen llvm_system_zdesc
    llvm_system_zdisassembler llvm_system_zinfo llvm_table_gen llvm_target
    llvm_transform_utils llvm_vectorize llvm_x86_asm_parser llvm_x86_asm_printer
    llvm_x86_code_gen llvm_x86_desc llvm_x86_disassembler llvm_x86_info
    llvm_x86_utils llvm_xcore_asm_printer llvm_xcore_code_gen llvm_xcore_desc
    llvm_xcore_disassembler llvm_xcore_info)
set_target_for_libraries(
    ${MOBILE_COMMERCE_IOS_TARGET}
    mobile_commerce_ios_atg_mobile_client
    mobile_commerce_ios_atg_gui_elements
    mobile_commerce_ios_ios_rest_client
    mobile_commerce_ios_atg_mobile_common
    mobile_commerce_ios_em_mobile_client)
set_target_for_libraries(
    ${OPENCV_TARGET} opencv_bioinspired opencv_calib3d opencv_contrib
    opencv_core opencv_cuda opencv_cudaarithm opencv_cudabgsegm
    opencv_cudafeatures2d opencv_cudafilters opencv_cudaimgproc
    opencv_cudaoptflow opencv_cudastereo opencv_cudawarping opencv_features2d
    opencv_flann opencv_highgui opencv_imgproc opencv_legacy opencv_ml
    opencv_nonfree opencv_objdetect opencv_ocl opencv_optim opencv_photo
    opencv_shape opencv_softcascade opencv_stitching opencv_superres
    opencv_ts opencv_video opencv_videostab)


set(EIGEN_INCLUDE_PATH ${EIGEN_PREFIX}/include/eigen3)


# Include directories.
set_include_directories(afnetworking ${AFNETWORKING_PREFIX}/include
                        ${AFNETWORKING_PREFIX}/include/AFNetworking)
set_include_directories(
    arabica ${ARABICA_PREFIX}/include ${ARABICA_PREFIX}/include/arabica)
set_include_directories(boost ${BOOST_PREFIX}/include)
set_include_directories(bzip2 ${BZIP2_PREFIX}/include)
set_include_directories(clang ${CLANG_PREFIX}/include)
set_include_directories(cluster ${CLUSTER_PREFIX}/include)
set_include_directories(cpp-netlib-uri ${CPP_NETLIB_URI_PREFIX}/include)
set_include_directories(curl-asio ${CURL_ASIO_PREFIX}/include)
set_include_directories(diff_match_patch ${DIFF_MATCH_PATCH_PREFIX}/include)
set_include_directories(dlib ${DLIB_PREFIX}/include)
set_include_directories(eigen ${EIGEN_INCLUDE_PATH})
set_include_directories(fast_image_cache ${FAST_IMAGE_CACHE_PREFIX}/include)
set_include_directories(fb_gallery ${FB_GALLERY_PREFIX}/include)
set_include_directories(flex ${FLEX_PREFIX}/include)
set_include_directories(formatter_kit ${FORMATTER_KIT_PREFIX}/include)
set_include_directories(freetype ${FREETYPE_PREFIX}/include)
set_include_directories(g2log ${G2LOG_PREFIX}/include)
set_include_directories(gflags ${GFLAGS_PREFIX}/include)
set_include_directories(glib ${GLIB_PREFIX}/include)
set_include_directories(gmock ${GMOCK_PREFIX}/include)
set_include_directories(gmp ${GMP_PREFIX}/include)
set_include_directories(gtest ${GTEST_PREFIX}/include)
set_include_directories(httpxx ${HTTPXX_PREFIX}/include)
set_include_directories(hwloc ${HWLOC_PREFIX}/include)
set_include_directories(icu ${ICU_PREFIX}/include)
set_include_directories(imagemagick ${IMAGEMAGICK_PREFIX}/include/ImageMagick-6)
set_include_directories(intel_pcm ${INTEL_PCM_PREFIX}/include)
set_include_directories(
    ios_ntp ${IOS_NTP_PREFIX}/include ${IOS_NTP_PREFIX}/include/ios-ntp)
set_include_directories(jsoncpp ${JSONCPP_PREFIX}/include)
set_include_directories(jsonpath ${JSONPATH_PREFIX}/include)
set_include_directories(leveldb ${LEVELDB_PREFIX}/include)
set_include_directories(libcurl ${LIBCURL_PREFIX}/include)
set_include_directories(libcxx ${LIBCXX_PREFIX}/include/c++/v1)
set_include_directories(libffi ${LIBFFI_PREFIX}/include)
set_include_directories(libpng ${LIBPNG_PREFIX}/include)
set_include_directories(libusb ${LIBUSB_PREFIX}/include)
if (IS_IOS)
  set_include_directories(
      libxml ${CMAKE_IOS_SDK_ROOT}/usr/include
      ${CMAKE_IOS_SDK_ROOT}/usr/include/libxml2)
else ()
  set_include_directories(
      libxml ${LIBXML_PREFIX}/include ${LIBXML_PREFIX}/include/libxml2)
endif ()
set_include_directories(lmdb ${LMDB_PREFIX}/include)
set_include_directories(lpsolve ${LPSOLVE_PREFIX}/include)
set_include_directories(marisa_trie ${MARISA_TRIE_PREFIX}/include)
set_include_directories(mili ${MILI_PREFIX}/include)
set_include_directories(
    mobile_commerce_ios ${MOBILE_COMMERCE_IOS_PREFIX}/include)
set_include_directories(mpc ${MPC_PREFIX}/include)
set_include_directories(mpfr ${MPFR_PREFIX}/include)
set_include_directories(mw_photo_browser ${MW_PHOTO_BROWSER_PREFIX}/include)
set_include_directories(mysql ${MYSQL_PREFIX}/include)
set_include_directories(mysqlcppconn ${MYSQLCPPCONN_PREFIX}/include)
set_include_directories(
    njk_web_view_progress ${NJK_WEB_VIEW_PROGRESS_PREFIX}/include)
set_include_directories(opencv ${OPENCV_PREFIX}/include)
set_include_directories(openmp ${OPENMP_PREFIX}/include)
set_include_directories(openssl ${OPENSSL_PREFIX}/include)
set_include_directories(
    pretty_kit ${PRETTY_KIT_PREFIX}/include ${PRETTY_KIT_PREFIX}/include/PrettyKit
    ${PRETTY_KIT_PREFIX}/include/PrettyKit/Cells)
set_include_directories(protobuf ${PROTOBUF_PREFIX}/include)
set_include_directories(readline ${READLINE_PREFIX}/include)
set_include_directories(shark ${SHARK_PREFIX}/include)
set_include_directories(sqlite3 ${SQLITE3_PREFIX}/include)
set_include_directories(sstoolkit ${SSTOOLKIT_PREFIX}/include)
set_include_directories(
    sw_reveal_view_controller ${SW_REVEAL_VIEW_CONTROLLER_PREFIX}/include)
set_include_directories(tbb ${TBB_PREFIX}/include)
set_include_directories(uialertview_blocks ${UIALERTVIEW_BLOCKS_PREFIX}/include)
set_include_directories(
    uiimage_animated_gif ${UIIMAGE_ANIMATED_GIF_PREFIX}/include)

# Fixing implicit header dependencies. Again we must be careful to define a DAG.
add_include_dependencies(arabica third_party.boost_headers third_party.libxml)
add_include_dependencies(cpp-netlib-uri third_party.boost_headers)
add_include_dependencies(curl-asio third_party.libcurl)

# 3rd-party executables.
set(CLANG_OMP_C_COMPILER ${CLANG_OMP_PREFIX}/bin/clang)
set(CLANG_OMP_CXX_COMPILER ${CLANG_OMP_PREFIX}/bin/clang++)
set(GCC_C_COMPILER ${GCC_PREFIX}/bin/gcc)
set(GCC_CXX_COMPILER ${GCC_PREFIX}/bin/g++)
set(GNUGREP ${GNUGREP_PREFIX}/bin/grep)
set(GNUTAR ${GNUTAR_PREFIX}/bin/tar)
set(MVN ${MAVEN_PREFIX}/bin/mvn)
set(PCREGREP ${PCRE_PREFIX}/bin/pcregrep)
set(XZ ${XZ_PREFIX}/bin/xz)

# Bypassing default C++ library.
set(CMAKE_CXX_FLAGS
    "${CMAKE_CXX_FLAGS} -I${LIBCXX_PREFIX}/include/c++/v1")
set(LINKER_FLAGS
    "-L${LIBCXX_PREFIX}/lib -lc++ -L${LIBCXXABI_PREFIX}/lib -lc++abi")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${LINKER_FLAGS}")
# set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} ${LINKER_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${LINKER_FLAGS}")


# Escaping architectures.
string(REPLACE ";" "$<SEMICOLON>" ARCHS "${CMAKE_OSX_ARCHITECTURES}")
string(REPLACE ";" " " SPACE_SEP_ARCHS "${CMAKE_OSX_ARCHITECTURES}")
string(REPLACE ";" " -arch " ARCHS_AS_FLAGS "${CMAKE_OSX_ARCHITECTURES}")
if (NOT "${ARCHS_AS_FLAGS}" STREQUAL "")
  set(ARCHS_AS_FLAGS "-arch ${ARCHS_AS_FLAGS}")
endif ()
set(CMAKE_C_FLAGS_WITH_ARCHS "${ARCHS_AS_FLAGS} ${CMAKE_C_FLAGS}")
set(CMAKE_CXX_FLAGS_WITH_ARCHS "${ARCHS_AS_FLAGS} ${CMAKE_CXX_FLAGS}")
set(LDFLAGS_WITH_ARCHS "${ARCHS_AS_FLAGS} ${CMAKE_SHARED_LINKER_FLAGS}")
if (IS_IOS)
  string(REGEX REPLACE "^\\-" "" XCODE_SDK ${CMAKE_XCODE_EFFECTIVE_PLATFORMS})
endif ()

# Sets the --host flag to the appropriate value if necessary.
if (IOS_BUILD)
  set(HOST "--host=arm-apple-darwin")
endif ()

# Sysroot.
if (CMAKE_OSX_SYSROOT)
  set(SYSROOT --with-sysroot=${CMAKE_OSX_SYSROOT})
endif ()

# Generic configure flags to select static or shared library compilation.
if (${BUILD_SHARED_LIBS})
  set(LIBRARY_SUFFIX ${CMAKE_SHARED_LIBRARY_SUFFIX})
  set(CONFIGURE_LIB_TYPE --enable-shared --disable-static)
  set(CONFIGURE_LIB_TYPE_STR "--enable-shared --disable-static")
else ()
  set(LIBRARY_SUFFIX ${CMAKE_STATIC_LIBRARY_SUFFIX})
  set(CONFIGURE_LIB_TYPE --disable-shared --enable-static)
  set(CONFIGURE_LIB_TYPE_STR "--disable-shared --enable-static")
endif ()

# The build systems used by some libraries do not allow the use of linker flags.
# In this case, we pass the linker flags directly to the compiler, with the
# "-Wl," prefix.
set(LINKER_AS_COMPILER_FLAGS)
set(FIRST TRUE)
foreach (FLAG ${CMAKE_SHARED_LINKER_FLAGS})
  if (FIRST)
    set(LINKER_AS_COMPILER_FLAGS "-Wl,${FLAG}")
  else ()
    set(LINKER_AS_COMPILER_FLAGS "${LINKER_AS_COMPILER_FLAGS} -Wl,${FLAG}")
  endif ()
endforeach ()

################################################################################
# External project inclusions.
################################################################################

################################################################################
# libcxx must be the first declared target as it is used by objc_library rules
# used below.
################################################################################
# libcxx.
add_external_project(
  ${LIBCXX_TARGET}_headers
  PREFIX ${LIBCXX_PREFIX}
  DOWNLOAD_COMMAND
      ${SVN} export --force http://llvm.org/svn/llvm-project/libcxx/trunk
          ${LIBCXX_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND ${NOP})
set(LIBCXX_LINKER_FLAGS "-L${LIBCXXABI_PREFIX}/lib ${CMAKE_SHARED_LINKER_FLAGS}")
add_external_project(
  ${LIBCXX_TARGET}
  PREFIX ${LIBCXX_PREFIX}
  DOWNLOAD_COMMAND ${NOP}
  PATCH_COMMAND
    patch -p0 < ${THIRD_PARTY_SOURCE_DIR}/libcxx.patch
  CMAKE_ARGS
      -DLIBCXX_ENABLE_SHARED=${BUILD_SHARED_LIBS}

      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      -DCMAKE_SHARED_LINKER_FLAGS=${LIBCXX_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${LIBCXX_PREFIX}
      -DLIBCXX_CXX_ABI=libcxxabi
      -DLIBCXX_LIBCXXABI_INCLUDE_PATHS=${LIBCXXABI_PREFIX}/include)
add_install_name_step(LIBCXX)
add_target_dependencies(LIBCXX ${LIBCXX_TARGET}_headers)
add_target_dependencies(LIBCXX ${LIBCXXABI_TARGET})

################################################################################
# AFNetworking.
get_download_target(AFNETWORKING DOWNLOAD_TARGET)
add_external_project(
  ${DOWNLOAD_TARGET}
  PREFIX ${AFNETWORKING_PREFIX}
  SOURCE_DIR ${AFNETWORKING_PREFIX}/src/${AFNETWORKING_TARGET}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/AFNetworking/AFNetworking.git ${AFNETWORKING_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND
      cd <SOURCE_DIR> &&
      find AFNetworking UIKit+AFNetworking -name "*.h" |
          cpio -dp <INSTALL_DIR>/include)
get_download_source_dir(AFNETWORKING SOURCE_DIR)
set(AFNETWORKING_SRCS
    ${SOURCE_DIR}/AFNetworking/AFHTTPRequestOperation.m
    ${SOURCE_DIR}/AFNetworking/AFHTTPRequestOperationManager.m
    ${SOURCE_DIR}/AFNetworking/AFHTTPSessionManager.m
    ${SOURCE_DIR}/AFNetworking/AFNetworkReachabilityManager.m
    ${SOURCE_DIR}/AFNetworking/AFSecurityPolicy.m
    ${SOURCE_DIR}/AFNetworking/AFURLConnectionOperation.m
    ${SOURCE_DIR}/AFNetworking/AFURLRequestSerialization.m
    ${SOURCE_DIR}/AFNetworking/AFURLResponseSerialization.m
    ${SOURCE_DIR}/AFNetworking/AFURLSessionManager.m
    ${SOURCE_DIR}/UIKit+AFNetworking/AFNetworkActivityIndicatorManager.m
    ${SOURCE_DIR}/UIKit+AFNetworking/UIActivityIndicatorView+AFNetworking.m
    ${SOURCE_DIR}/UIKit+AFNetworking/UIAlertView+AFNetworking.m
    ${SOURCE_DIR}/UIKit+AFNetworking/UIButton+AFNetworking.m
    ${SOURCE_DIR}/UIKit+AFNetworking/UIImageView+AFNetworking.m
    ${SOURCE_DIR}/UIKit+AFNetworking/UIProgressView+AFNetworking.m
    ${SOURCE_DIR}/UIKit+AFNetworking/UIRefreshControl+AFNetworking.m
    ${SOURCE_DIR}/UIKit+AFNetworking/UIWebView+AFNetworking.m)
set_source_files_properties(${AFNETWORKING_SRCS} PROPERTIES GENERATED TRUE)
objc_library(${AFNETWORKING_TARGET} ${AFNETWORKING_SRCS})
link_framework(
    ${AFNETWORKING_TARGET} CoreGraphics MobileCoreServices Security
    SystemConfiguration UIKit)
target_include_directories(
    ${AFNETWORKING_TARGET} PUBLIC ${AFNETWORKING_PREFIX}/include/AFNetworking)
set_target_properties(
    ${AFNETWORKING_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${AFNETWORKING_PREFIX}/lib
    LIBRARY_OUTPUT_DIRECTORY ${AFNETWORKING_PREFIX}/lib
    OUTPUT_NAME afnetworking)
add_target_dependencies(AFNETWORKING ${DOWNLOAD_TARGET})

################################################################################
# APR.
add_external_project(
  ${APR_TARGET}
  PREFIX ${APR_PREFIX}
  DOWNLOAD_DIR ${APR_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O apr-1.5.0.tar.bz2 https://archive.apache.org/dist/apr/apr-1.5.0.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/apr-1.5.0.tar.bz2.asc
          apr-1.5.0.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${APR_PREFIX}/download/apr-1.5.0.tar.bz2
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --prefix=${APR_PREFIX} ${HOST} ${SYSROOT}
      --enable-threads
  BUILD_IN_SOURCE 1)

################################################################################
# APR-util.
add_external_project(
  ${APR_UTIL_TARGET}
  PREFIX ${APR_UTIL_PREFIX}
  DOWNLOAD_DIR ${APR_UTIL_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O apr-util-1.5.3.tar.bz2 https://archive.apache.org/dist/apr/apr-util-1.5.3.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/apr-util-1.5.3.tar.bz2.asc
          apr-util-1.5.3.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${APR_UTIL_PREFIX}/download/apr-util-1.5.3.tar.bz2
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --prefix=${APR_PREFIX} ${HOST} ${SYSROOT}
      --with-apr=${APR_PREFIX}
      --with-berkeley-db=${BERKELEY_DB_PREFIX}
  BUILD_IN_SOURCE 1)
add_target_dependencies(APR_UTIL ${APR_TARGET})
add_target_dependencies(APR_UTIL ${BERKELEY_DB_TARGET})

################################################################################
# Arabica, an XML and HTML processing toolkit, providing SAX2, DOM, XPath, and
# XSLT implementations, written in Standard C++.
# See https://github.com/jezhiggins/arabica.
set(ADDITIONAL_CMAKE_ARGS)
if (NOT IS_IOS)
  set(ADDITIONAL_CMAKE_ARGS
      -DCMAKE_INCLUDE_PATH=${LIBXML_PREFIX}/include
      -DCMAKE_LIBRARY_PATH=${LIBXML_PREFIX}/lib)
endif ()
add_external_project(
  ${ARABICA_TARGET}
  PREFIX ${ARABICA_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/QuentinFiard/arabica.git
          ${ARABICA_TARGET}
  CMAKE_ARGS
      -DBOOST_ROOT=${BOOST_PREFIX}
      ${ADDITIONAL_CMAKE_ARGS}

      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${ARABICA_PREFIX}
      -DBUILD_ARABICA_EXAMPLES=OFF)
add_install_name_step(ARABICA)
add_target_dependencies(ARABICA ${BOOST_TARGET})
if (NOT IS_IOS)
  add_target_dependencies(ARABICA ${LIBXML_TARGET})
endif ()
add_definitions(-DBOOST_SPIRIT_THREADSAFE)

################################################################################
# BerkeleyDB.
add_external_project(
  ${BERKELEY_DB_TARGET}
  PREFIX ${BERKELEY_DB_PREFIX}
  DOWNLOAD_DIR ${BERKELEY_DB_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O db-6.0.20.tar.gz http://download.oracle.com/berkeley-db/db-6.0.20.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/db-6.0.20.tar.gz.sig
          db-6.0.20.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${BERKELEY_DB_PREFIX}/download/db-6.0.20.tar.gz
  CONFIGURE_COMMAND
      <SOURCE_DIR>/dist/configure --prefix=${BERKELEY_DB_PREFIX} ${HOST}
      ${SYSROOT}
      --enable-compat185
      --enable-cxx
      --enable-dbm
      ${CONFIGURE_LIB_TYPE})

################################################################################
# Bison.
add_external_project(
  ${BISON_TARGET}
  PREFIX ${BISON_PREFIX}
  DOWNLOAD_DIR ${BISON_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O bison-3.0.tar.gz http://ftp.gnu.org/gnu/bison/bison-3.0.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/bison-3.0.tar.gz.sig
          bison-3.0.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${BISON_PREFIX}/download/bison-3.0.tar.gz
  CONFIGURE_COMMAND ./configure --prefix=${BISON_PREFIX} ${HOST} ${SYSROOT}
  BUILD_IN_SOURCE 1)
set(BISON_EXECUTABLE ${BISON_PREFIX}/bin/bison)

################################################################################
# Boost.
if ("${BOOST_ROOT}" STREQUAL "")
  set(BOOST_CXX_FLAGS "${CMAKE_CXX_FLAGS} -ftemplate-depth-1024")
  if (IOS_BUILD)
    set(BOOST_CXX_FLAGS "${ARCHS_AS_FLAGS} ${BOOST_CXX_FLAGS}")
    set(BUILD_COMMAND
        b2 release toolset=clang-darwin
            architecture=arm
            target-os=iphone
            cxxflags=${BOOST_CXX_FLAGS}
            linkflags=${CMAKE_SHARED_LINKER_FLAGS}
            define=BOOST_NO_CXX11_NUMERIC_LIMITS
            define=BOOST_SYSTEM_NO_DEPRECATED
            --without-context
            --without-coroutine
            link=static install)
  elseif (IOS_SIMULATOR_BUILD)
    set(BOOST_CXX_FLAGS "${ARCHS_AS_FLAGS} ${BOOST_CXX_FLAGS}")
    set(BUILD_COMMAND
        b2 release toolset=clang-darwin
            architecture=x86
            target-os=iphone
            cxxflags=${BOOST_CXX_FLAGS}
            linkflags=${CMAKE_SHARED_LINKER_FLAGS}
            define=BOOST_NO_CXX11_NUMERIC_LIMITS
            define=BOOST_SYSTEM_NO_DEPRECATED
            --without-context
            --without-coroutine
            link=static install)
  else ()
    set(BUILD_COMMAND
        b2 release toolset=clang-darwin cxxflags=${BOOST_CXX_FLAGS}
            linkflags=${CMAKE_SHARED_LINKER_FLAGS}
            define=BOOST_NO_CXX11_NUMERIC_LIMITS
            define=BOOST_SYSTEM_NO_DEPRECATED install)
  endif ()
  add_external_project(
    ${BOOST_TARGET}
    PREFIX ${BOOST_PREFIX}
    DOWNLOAD_DIR ${BOOST_PREFIX}/download
    DOWNLOAD_COMMAND
        wget -O boost_1_54_0.tar.bz2 http://downloads.sourceforge.net/project/boost/boost/1.54.0/boost_1_54_0.tar.bz2?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fboost%2Ffiles%2Fboost%2F1.54.0%2F&ts=1383838140&use_mirror=optimate &&
        gpg --verify ${THIRD_PARTY_SOURCE_DIR}/boost_1_54_0.tar.bz2.sig
            boost_1_54_0.tar.bz2 &&
        cd <SOURCE_DIR> &&
        tar --strip-components 1 -xvf
            ${BOOST_PREFIX}/download/boost_1_54_0.tar.bz2
    CONFIGURE_COMMAND ./bootstrap.sh --prefix=${BOOST_PREFIX}
    BUILD_COMMAND ${BUILD_COMMAND}
    PATCH_COMMAND
        patch -Np0 < ${THIRD_PARTY_SOURCE_DIR}/boost.patch
    BUILD_IN_SOURCE 1)
  set(BOOST_TIME_ZONE_CSV
      "${BOOST_PREFIX}/src/${BOOST_TARGET}/libs/date_time/data/date_time_zonespec.csv")
else ()
  if (NOT EXISTS ${BOOST_TIME_ZONE_CSV})
    message(FATAL_ERROR
            "You must specify an existing path to BOOST_TIME_ZONE_CSV when "
            " using external Boost libraries.")
  endif ()
  set(BOOST_PREFIX ${BOOST_ROOT})
  add_custom_target(${BOOST_TARGET})
endif ()

################################################################################
# bsdiff.
add_external_project(
  ${BSDIFF_TARGET}
  PREFIX ${BSDIFF_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/QuentinFiard/bsdiff.git
  CMAKE_ARGS
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
  INSTALL_COMMAND
      ${CMAKE_COMMAND} -E make_directory ${BSDIFF_PREFIX}/bin &&
      cp -f bsdiff bspatch ${BSDIFF_PREFIX}/bin)

################################################################################
# bzip2.
get_download_target(BZIP2 DOWNLOAD_TARGET)
add_external_project(
  ${DOWNLOAD_TARGET}
  PREFIX ${BZIP2_PREFIX}
  DOWNLOAD_DIR ${BZIP2_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O bzip2-1.0.6.tar.gz http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/bzip2-1.0.6.tar.gz.sig
          bzip2-1.0.6.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${BZIP2_PREFIX}/download/bzip2-1.0.6.tar.gz
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND ${NOP})
get_download_source_dir(BZIP2 SOURCE_DIR)
set(BZIP2_SRCS
    ${SOURCE_DIR}/blocksort.c
    ${SOURCE_DIR}/huffman.c
    ${SOURCE_DIR}/crctable.c
    ${SOURCE_DIR}/randtable.c
    ${SOURCE_DIR}/compress.c
    ${SOURCE_DIR}/decompress.c
    ${SOURCE_DIR}/bzlib.c)
set_source_files_properties(${BZIP2_SRCS} PROPERTIES GENERATED TRUE)
cc_library(${BZIP2_TARGET} ${BZIP2_SRCS})
set_target_properties(
    ${BZIP2_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${BZIP2_PREFIX}/lib
    LIBRARY_OUTPUT_DIRECTORY ${BZIP2_PREFIX}/lib
    OUTPUT_NAME bz2)
add_target_dependencies(BZIP2 ${DOWNLOAD_TARGET})

################################################################################
# cairo.
add_external_project(
  ${CAIRO_TARGET}
  PREFIX ${CAIRO_PREFIX}
  DOWNLOAD_DIR ${CAIRO_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O cairo-1.12.16.tar.xz http://www.cairographics.org/releases/cairo-1.12.16.tar.xz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/cairo-1.12.16.tar.xz.sig
          cairo-1.12.16.tar.xz &&
      cd <SOURCE_DIR> &&
      ${GNUTAR} --strip-components 1 -xvJf
          ${CAIRO_PREFIX}/download/cairo-1.12.16.tar.xz
  CONFIGURE_COMMAND echo "\
      <SOURCE_DIR>/configure --prefix=${CAIRO_PREFIX} ${HOST} ${SYSROOT}\
      CC=${CMAKE_C_COMPILER}\
      CXX=${CMAKE_CXX_COMPILER} CFLAGS=\"${CMAKE_C_FLAGS_WITH_ARCHS}\"\
      CXXFLAGS=\"${CMAKE_CXX_FLAGS_WITH_ARCHS}\"\
      LDFLAGS=\"${CMAKE_SHARED_LINKER_FLAGS}\"\
      ${CONFIGURE_LIB_TYPE_STR}\
      --enable-xlib=no\
      PKG_CONFIG_PATH=\"${PIXMAN_PREFIX}/lib/pkgconfig:${FREETYPE_PREFIX}/lib/pkgconfig:${LIBPNG_PREFIX}/lib/pkgconfig:${ZLIB_PREFIX}/lib/pkgconfig\"" | sh)
add_target_dependencies(CAIRO ${GNUTAR_TARGET})
add_target_dependencies(CAIRO ${FREETYPE_TARGET})
add_target_dependencies(CAIRO ${LIBPNG_TARGET})
add_target_dependencies(CAIRO ${PIXMAN_TARGET})

################################################################################
# Clang compiler.
add_external_project(
  ${CLANG_TARGET}
  PREFIX ${CLANG_PREFIX}
  DOWNLOAD_COMMAND
      # Patch file is specific to revision 199104, a missing header leads to an
      # undefined symbol without it. Might be unnecessary in the near future.
      ${GIT} clone --depth 1 git://github.com/QuentinFiard/llvm ${CLANG_TARGET} &&
      ${SVN} export --force http://llvm.org/svn/llvm-project/compiler-rt/trunk ${CLANG_TARGET}/projects/compiler-rt &&
      ${SVN} export --force http://llvm.org/svn/llvm-project/cfe/trunk ${CLANG_TARGET}/tools/clang
  CMAKE_ARGS
      -DLLVM_REQUIRES_RTTI=ON

      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${CLANG_PREFIX})
add_install_name_step(CLANG)

################################################################################
# Clang/OpenMP - OpenMP compatible clang compiler.
add_external_project(
  ${CLANG_OMP_TARGET}
  PREFIX ${CLANG_OMP_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/clang-omp/llvm ${CLANG_OMP_TARGET} &&
      ${GIT} clone --depth 1 git://github.com/clang-omp/compiler-rt ${CLANG_OMP_TARGET}/projects/compiler-rt &&
      ${GIT} clone --depth 1 -b clang-omp git://github.com/clang-omp/clang ${CLANG_OMP_TARGET}/tools/clang
  CMAKE_ARGS
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${CLANG_OMP_PREFIX})

################################################################################
# Common Locale Data Repository.
set(CLDR_ROOT ${CLDR_PREFIX}/cldr)
add_external_project(
  ${CLDR_TARGET}
  PREFIX ${CLDR_PREFIX}
  DOWNLOAD_DIR ${CLDR_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O json.zip http://unicode.org/Public/cldr/latest/json.zip &&
      ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/cldr &&
      cd <INSTALL_DIR>/cldr &&
      unzip ${CLDR_PREFIX}/download/json.zip
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND ${NOP})

################################################################################
# Closure Compiler.
add_external_project(
  ${CLOSURE_COMPILER_TARGET}
  PREFIX ${CLOSURE_COMPILER_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone https://code.google.com/p/closure-compiler ${CLOSURE_COMPILER_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${ANT} jar
  INSTALL_COMMAND
      ${CMAKE_COMMAND} -E make_directory ${CLOSURE_COMPILER_PREFIX}/bin &&
      cp -f <BINARY_DIR>/build/compiler.jar ${CLOSURE_COMPILER_PREFIX}/bin
  BUILD_IN_SOURCE 1)
set(CLOSURE_COMPILER_JAR ${CLOSURE_COMPILER_PREFIX}/bin/compiler.jar)

################################################################################
# Closure Library.
add_external_project(
  ${CLOSURE_LIBRARY_TARGET}
  PREFIX ${CLOSURE_LIBRARY_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone https://code.google.com/p/closure-library <INSTALL_DIR>/lib/closure-library
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND ${NOP})
set(CLOSURE_LIBRARY ${CLOSURE_LIBRARY_PREFIX}/lib/closure-library)

################################################################################
# cpp-netlib.
add_external_project(
  ${CPP_NETLIB_TARGET}
  PREFIX ${CPP_NETLIB_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --recursive --depth 1
          git://github.com/cpp-netlib/cpp-netlib.git
          ${CPP_NETLIB_TARGET}
  CMAKE_ARGS
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${CPP_NETLIB_PREFIX}

      -DBOOST_ROOT=${BOOST_PREFIX}
      -DCMAKE_INCLUDE_PATH=${ICU_PREFIX}/include
      -DCMAKE_LIBRARY_PATH=${ICU_PREFIX}/lib
      -DOPENSSL_ROOT_DIR=${OPENSSL_PREFIX}
      -DCPP-NETLIB_BUILD_TESTS=NO
      -DCPP-NETLIB_BUILD_SINGLE_LIB=YES)
add_target_dependencies(CPP_NETLIB ${BOOST_TARGET})
add_target_dependencies(CPP_NETLIB ${ICU_TARGET})
add_target_dependencies(CPP_NETLIB ${OPENSSL_TARGET})

################################################################################
# cpp-netlib-uri.
add_external_project(
  ${CPP_NETLIB_URI_TARGET}
  PREFIX ${CPP_NETLIB_URI_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --recursive --depth 1
          git://github.com/QuentinFiard/uri.git
          ${CPP_NETLIB_URI_TARGET}
  CMAKE_ARGS
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${CPP_NETLIB_URI_PREFIX}

      -DBOOST_ROOT=${BOOST_PREFIX}
      -DCPP-NETLIB_BUILD_TESTS=NO)
add_target_dependencies(CPP_NETLIB_URI ${BOOST_TARGET})
add_install_name_step(CPP_NETLIB_URI)

################################################################################
# Country Infos.
add_external_project(
  ${COUNTRY_INFOS_TARGET}
  PREFIX ${COUNTRY_INFOS_PREFIX}
  DOWNLOAD_COMMAND
      mkdir -p <INSTALL_DIR>/data &&
      wget -O <INSTALL_DIR>/data/country_infos.txt http://download.geonames.org/export/dump/countryInfo.txt
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND ${NOP})

################################################################################
# Open Source Clustering Library.
add_external_project(
  ${CLUSTER_TARGET}_download
  PREFIX ${CLUSTER_PREFIX}
  DOWNLOAD_DIR ${CLUSTER_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O cluster-1.52.tar.gz http://bonsai.hgc.jp/~mdehoon/software/cluster/cluster-1.52.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/cluster-1.52.tar.gz.sig
          cluster-1.52.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf ${CLUSTER_PREFIX}/download/cluster-1.52.tar.gz
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND
      mkdir -p <INSTALL_DIR>/include &&
      cp -f <SOURCE_DIR>/src/cluster.h <INSTALL_DIR>/include)
ExternalProject_Get_Property(${CLUSTER_TARGET}_download SOURCE_DIR)
set(SRCS ${SOURCE_DIR}/src/cluster.c)
set_source_files_properties(${SRCS} PROPERTIES GENERATED TRUE)
cc_library(${CLUSTER_TARGET} ${SRCS})
target_include_directories(
    ${CLUSTER_TARGET} PUBLIC ${CLUSTER_PREFIX}/include)
set_target_properties(
    ${CLUSTER_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${CLUSTER_PREFIX}/lib
    LIBRARY_OUTPUT_DIRECTORY ${CLUSTER_PREFIX}/lib
    OUTPUT_NAME cluster)
add_dependencies(${CLUSTER_TARGET} ${CLUSTER_TARGET}_download)

################################################################################
# curl-asio, an asynchronous CURL wrapper based on Boost Asio.
# See https://github.com/mologie/curl-asio.
set(CURL_ASIO_C_FLAGS "-I${LIBCURL_PREFIX}/include ${CMAKE_C_FLAGS_WITH_ARCHS}")
set(CURL_ASIO_CXX_FLAGS "-I${LIBCURL_PREFIX}/include ${CMAKE_CXX_FLAGS_WITH_ARCHS}")
set(CURL_ASIO_LINKER_FLAGS "${LINKER_FLAGS}")
foreach (FLAG ${third_party.libcurl})
  set(CURL_ASIO_LINKER_FLAGS "${CURL_ASIO_LINKER_FLAGS} ${FLAG}")
endforeach ()
add_external_project(
  ${CURL_ASIO_TARGET}
  PREFIX ${CURL_ASIO_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/QuentinFiard/curl-asio.git
          ${CURL_ASIO_TARGET}
  CMAKE_ARGS
      -DBOOST_ROOT=${BOOST_PREFIX}
      -DCURL_INCLUDE_DIR=${LIBCURL_PREFIX}/include
      -DCURL_LIBRARY=${LIBCURL_PREFIX}/lib/libcurl.dylib
      -DBUILD_EXAMPLES=OFF

      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CURL_ASIO_C_FLAGS}
      -DCMAKE_CXX_FLAGS=${CURL_ASIO_CXX_FLAGS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CURL_ASIO_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${CURL_ASIO_PREFIX})
add_install_name_step(CURL_ASIO)
add_target_dependencies(CURL_ASIO ${BOOST_TARGET})
add_target_dependencies(CURL_ASIO ${LIBCURL_TARGET})

################################################################################
# diff_match_patch.
add_external_project(
  ${DIFF_MATCH_PATCH_TARGET}
  PREFIX ${DIFF_MATCH_PATCH_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/QuentinFiard/diff_match_patch ${DIFF_MATCH_PATCH_TARGET}
  CMAKE_ARGS
      -DBUILD_EXAMPLES=OFF
      -DBUILD_TESTS=OFF

      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      -DCMAKE_EXE_LINKER_FLAGS=${CMAKE_EXE_LINKER_FLAGS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES}
      -DCMAKE_INSTALL_PREFIX=${DIFF_MATCH_PATCH_PREFIX}
      -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT})
add_install_name_step(DIFF_MATCH_PATCH)

################################################################################
# dlib.
add_external_project(
  ${DLIB_TARGET}
  PREFIX ${DLIB_PREFIX}
  DOWNLOAD_DIR ${DLIB_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O dlib-18.5.tar.bz2 http://downloads.sourceforge.net/project/dclib/dlib/v18.5/dlib-18.5.tar.bz2?r=http%3A%2F%2Fdlib.net%2Fcompile.html&ts=1383664047 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/dlib-18.5.tar.bz2.sig
          dlib-18.5.tar.bz2 &&
      tar --strip-components 1 -xvf
          ${DLIB_PREFIX}/download/dlib-18.5.tar.bz2 dlib-18.5/dlib &&
      rm -rf <SOURCE_DIR> &&
      mv ${DLIB_PREFIX}/download/dlib/ <SOURCE_DIR>
  CMAKE_ARGS
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${DLIB_PREFIX}
  INSTALL_COMMAND
      ${CMAKE_COMMAND} -E make_directory ${DLIB_PREFIX}/lib &&
      cp -f libdlib.a ${DLIB_PREFIX}/lib &&
      ${CMAKE_COMMAND} -E make_directory ${DLIB_PREFIX}/include/dlib &&
      cd <SOURCE_DIR> &&
      find . -name "*.h" |
      cpio -dp <INSTALL_DIR>/include/dlib)

################################################################################
# Eigen.
add_external_project(
  ${EIGEN_TARGET}
  PREFIX ${EIGEN_PREFIX}
  DOWNLOAD_COMMAND
      ${HG} clone https://bitbucket.org/eigen/eigen ${EIGEN_TARGET}
  CMAKE_ARGS
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${EIGEN_PREFIX}
      # Do not add register for pkg-config as it would require root permissions.
      -DEIGEN_BUILD_PKGCONFIG=OFF
      -DGMP_INCLUDES=${GMP_PREFIX}/include
      -DGMP_LIBRARIES=${GMP_PREFIX}/lib
      -DMPFR_INCLUDES=${MPFR_PREFIX}/include
      -DMPFR_LIBRARIES=${MPFR_PREFIX}/lib)
add_target_dependencies(EIGEN ${GMP_TARGET})
add_target_dependencies(EIGEN ${MPFR_TARGET})

################################################################################
# Extrae.
add_external_project(
  ${EXTRAE_TARGET}
  PREFIX ${EXTRAE_PREFIX}
  DOWNLOAD_DIR ${EXTRAE_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O extrae-2.5.0.tar.bz2 https://docs.google.com/uc?id=0BySPYa0lPpaYUjQwcWcxV1JVZEk&export=download &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/extrae-2.5.0.tar.bz2.sig
          extrae-2.5.0.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${EXTRAE_PREFIX}/download/extrae-2.5.0.tar.bz2
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${EXTRAE_PREFIX}
      CC=${CMAKE_C_COMPILER}
      CXX=${CMAKE_CXX_COMPILER}
      CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      LDFLAGS=${LDFLAGS_WITH_ARCHS}
      ${CONFIGURE_LIB_TYPE}
      --with-boost=${BOOST_PREFIX}
      --with-libz=${ZLIB_PREFIX}
      --with-papi=${PAPI_PREFIX})
add_target_dependencies(EXTRAE ${BOOST_TARGET})
add_target_dependencies(EXTRAE ${PAPI_TARGET})
add_target_dependencies(EXTRAE ${ZLIB_PREFIX})

################################################################################
# FastImageCache.
get_download_target(FAST_IMAGE_CACHE DOWNLOAD_TARGET)
add_external_project(
  ${DOWNLOAD_TARGET}
  PREFIX ${FAST_IMAGE_CACHE_PREFIX}
  SOURCE_DIR ${FAST_IMAGE_CACHE_PREFIX}/src/${FAST_IMAGE_CACHE_TARGET}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/path/FastImageCache.git ${FAST_IMAGE_CACHE_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND
      cd <SOURCE_DIR> &&
      find FastImageCache -name "*.h" | cpio -dp <INSTALL_DIR>/include)
get_download_source_dir(FAST_IMAGE_CACHE SOURCE_DIR)
set(SOURCE_DIR ${SOURCE_DIR}/FastImageCache)
set(FAST_IMAGE_CACHE_SRCS
    ${SOURCE_DIR}/FICImageCache.m
    ${SOURCE_DIR}/FICImageFormat.m
    ${SOURCE_DIR}/FICImageTable.m
    ${SOURCE_DIR}/FICImageTableChunk.m
    ${SOURCE_DIR}/FICImageTableEntry.m
    ${SOURCE_DIR}/FICUtilities.m)
set_source_files_properties(${FAST_IMAGE_CACHE_SRCS} PROPERTIES GENERATED TRUE)
objc_library(${FAST_IMAGE_CACHE_TARGET} ${FAST_IMAGE_CACHE_SRCS})
link_framework(${FAST_IMAGE_CACHE_TARGET} CoreGraphics UIKit)
set_target_properties(
    ${FAST_IMAGE_CACHE_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${FAST_IMAGE_CACHE_PREFIX}/lib
    LIBRARY_OUTPUT_DIRECTORY ${FAST_IMAGE_CACHE_PREFIX}/lib
    OUTPUT_NAME fast_image_cache)
add_target_dependencies(FAST_IMAGE_CACHE ${DOWNLOAD_TARGET})

################################################################################
# FBGallery.
get_download_target(FB_GALLERY DOWNLOAD_TARGET)
add_external_project(
  ${DOWNLOAD_TARGET}
  PREFIX ${FB_GALLERY_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/Seitk/FB-Gallery.git
          ${DOWNLOAD_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND
    cd "<SOURCE_DIR>/FB Gallery" &&
    find . -maxdepth 1 -name "*.h" |
        cpio -dp ${FB_GALLERY_PREFIX}/include/FBGallery)
get_download_source_dir(FB_GALLERY SOURCE_DIR)
set(SOURCE_DIR "${SOURCE_DIR}/FB Gallery")
set(SRCS
    "${SOURCE_DIR}/FBGTimelineCell.m"
    "${SOURCE_DIR}/FBGTimelinePhotoView.m"
    "${SOURCE_DIR}/UIView+viewController.m")
set_source_files_properties(${SRCS} PROPERTIES GENERATED TRUE)
objc_library(${FB_GALLERY_TARGET} ${SRCS})
set_target_properties(
    ${FB_GALLERY_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${FB_GALLERY_PREFIX}/lib
    LIBRARY_OUTPUT_DIRECTORY ${FB_GALLERY_PREFIX}/lib
    OUTPUT_NAME fb_gallery)
target_include_directories(
    ${FB_GALLERY_TARGET} PUBLIC ${MW_PHOTO_BROWSER_PREFIX}/include)
add_target_dependencies(FB_GALLERY ${DOWNLOAD_TARGET})
add_target_dependencies(FB_GALLERY ${MW_PHOTO_BROWSER_TARGET})

################################################################################
# FFTW.
add_external_project(
  ${FFTW_TARGET}
  PREFIX ${FFTW_PREFIX}
  DOWNLOAD_DIR ${FFTW_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O fftw-2.1.5.tar.gz http://www.fftw.org/fftw-2.1.5.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/fftw-2.1.5.tar.gz.sig
          fftw-2.1.5.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf ${FFTW_PREFIX}/download/fftw-2.1.5.tar.gz
  PATCH_COMMAND
      patch -p1 < ${THIRD_PARTY_SOURCE_DIR}/fftw.patch
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${FFTW_PREFIX}
      CC=${CMAKE_C_COMPILER}
      CXX=${CMAKE_CXX_COMPILER}
      CFLAGS=${CMAKE_C_FLAGS}
      CXXFLAGS=${CMAKE_CXX_FLAGS}
      LDFLAGS=${CMAKE_SHARED_LIBRARY_FLAGS}
      ${CONFIGURE_LIB_TYPE})

################################################################################
# Flex.
add_external_project(
  ${FLEX_TARGET}
  PREFIX ${FLEX_PREFIX}
  DOWNLOAD_DIR ${FLEX_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O flex-2.5.37.tar.bz2 http://downloads.sourceforge.net/project/flex/flex-2.5.37.tar.bz2?r=http%3A%2F%2Fflex.sourceforge.net%2F&ts=1382395008&use_mirror=kent &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/flex-2.5.37.tar.bz2.sig
          flex-2.5.37.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${FLEX_PREFIX}/download/flex-2.5.37.tar.bz2
  CONFIGURE_COMMAND ./configure --prefix=${FLEX_PREFIX} ${HOST} ${SYSROOT}
  BUILD_IN_SOURCE 1)
set(FLEX_EXECUTABLE ${FLEX_PREFIX}/bin/flex++)

################################################################################
# FormatterKit.
get_download_target(FORMATTER_KIT DOWNLOAD_TARGET)
add_external_project(
  ${DOWNLOAD_TARGET}
  PREFIX ${FORMATTER_KIT_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/QuentinFiard/FormatterKit.git
          ${DOWNLOAD_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND
      cd <SOURCE_DIR> &&
      find FormatterKit -name "*.h" | cpio -dp <INSTALL_DIR>/include)
get_download_source_dir(FORMATTER_KIT SOURCE_DIR)
set(SOURCE_DIR2 ${SOURCE_DIR}/FormatterKit)
set(SRCS
    ${SOURCE_DIR2}/TTTAddressFormatter.m
    ${SOURCE_DIR2}/TTTArrayFormatter.m
    ${SOURCE_DIR2}/TTTColorFormatter.m
    ${SOURCE_DIR2}/TTTLocationFormatter.m
    ${SOURCE_DIR2}/TTTOrdinalNumberFormatter.m
    ${SOURCE_DIR2}/TTTTimeIntervalFormatter.m
    ${SOURCE_DIR2}/TTTUnitOfInformationFormatter.m
    ${SOURCE_DIR2}/TTTURLRequestFormatter.m)
set_source_files_properties(${SRCS} PROPERTIES GENERATED TRUE)
objc_library(${FORMATTER_KIT_TARGET} ${SRCS})
link_framework(${FORMATTER_KIT_TARGET} AddressBook AddressBookUI CoreLocation)
set_target_properties(
    ${FORMATTER_KIT_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${FORMATTER_KIT_PREFIX}/lib
    LIBRARY_OUTPUT_DIRECTORY ${FORMATTER_KIT_PREFIX}/lib
    OUTPUT_NAME formatter_kit)
add_target_dependencies(FORMATTER_KIT ${DOWNLOAD_TARGET})
set(FORMATTER_KIT_LOCALIZATIONS ${SOURCE_DIR}/Localizations)

################################################################################
# Freetype.
add_external_project(
  ${FREETYPE_TARGET}
  PREFIX ${FREETYPE_PREFIX}
  DOWNLOAD_DIR ${FREETYPE_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O freetype-2.5.3.tar.bz2 https://docs.google.com/uc?id=0BySPYa0lPpaYNldReHU4dUMwWk0&export=download &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/freetype-2.5.3.tar.bz2.sig
          freetype-2.5.3.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${FREETYPE_PREFIX}/download/freetype-2.5.3.tar.bz2
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --prefix=${FREETYPE_PREFIX} ${HOST} ${SYSROOT}
          CC=${CMAKE_C_COMPILER}
          CC_BUILD=${CMAKE_C_COMPILER}
          CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
          CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
          LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
          ${CONFIGURE_LIB_TYPE}

          BZIP2_CFLAGS=-I${BZIP2_PREFIX}/include
          BZIP2_LIBS="-L${BZIP2_PREFIX}/lib -lbz2"
          LIBPNG_CFLAGS=-I${LIBPNG_PREFIX}/include
          LIBPNG_LIBS="-L${LIBPNG_PREFIX}/lib -lpng"
          ZLIB_CFLAGS=-I${ZLIB_PREFIX}/include
          ZLIB_LIBS="-L${ZLIB_PREFIX}/lib -lz"
  INSTALL_COMMAND
      make install &&
      ln -s ${FREETYPE_PREFIX}/include/freetype2
          ${FREETYPE_PREFIX}/include/freetype2/freetype)
add_target_dependencies(FREETYPE ${BZIP2_TARGET})
add_target_dependencies(FREETYPE ${LIBPNG_TARGET})
add_target_dependencies(FREETYPE ${ZLIB_TARGET})

################################################################################
# g2log.
add_external_project(
  ${G2LOG_TARGET}
  PREFIX ${G2LOG_PREFIX}
  DOWNLOAD_DIR ${G2LOG_PREFIX}/download
  DOWNLOAD_COMMAND
      rm -rf g2log &&
      ${HG} clone -r 56 https://bitbucket.org/KjellKod/g2log &&
      rm -rf <SOURCE_DIR> &&
      cp -r g2log/g2log <SOURCE_DIR>
  PATCH_COMMAND patch -Np0 < ${THIRD_PARTY_SOURCE_DIR}/g2log.patch
  CMAKE_ARGS
      -DUSE_SIMPLE_EXAMPLE=OFF

      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      -DCMAKE_EXE_LINKER_FLAGS=${CMAKE_EXE_LINKER_FLAGS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}

      -DLIBRARY_OUTPUT_PATH=<INSTALL_DIR>/lib
  INSTALL_COMMAND
      ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/include/g2log &&
      cd <SOURCE_DIR>/src &&
      find . -name "*.h" |
      cpio -dp <INSTALL_DIR>/include/g2log)

################################################################################
# GNU GCC compiler.
if (NOT SKIP_PORTABILITY_WARNINGS AND "$ENV{BUILD_3RD_PARTY_LIBRARIES}")
  message(
      WARNING
      "If you indend to build GCC please replace GCC_SYSROOT with the correct value"
      " for your system. You can otherwise safely ignore this warning.")
endif ()
set(GCC_SYSROOT /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk)
add_external_project(
  ${GCC_TARGET}
  PREFIX ${GCC_PREFIX}
  DOWNLOAD_DIR ${GCC_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O gcc-4.8.2.tar.bz2 ftp://ftp.gnu.org/gnu/gcc/gcc-4.8.2/gcc-4.8.2.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/gcc-4.8.2.tar.bz2.sig
          gcc-4.8.2.tar.bz2 &&
      cd <SOURCE_DIR> &&
      ${GNUTAR} --strip-components 1 -xvf
          ${GCC_PREFIX}/download/gcc-4.8.2.tar.bz2
  CONFIGURE_COMMAND
      ./configure --prefix=${GCC_PREFIX} ${HOST} --with-gmp=${GMP_PREFIX}
          --with-mpfr=${MPFR_PREFIX} --with-mpc=${MPC_PREFIX}
          --with-sysroot=${GCC_SYSROOT} --with-build-sysroot=${GCC_SYSROOT}
          CFLAGS=-O4 CXXFLAGS=-O4
          CPPFLAGS=-O4
  BUILD_IN_SOURCE 1)
add_target_dependencies(GCC ${GMP_TARGET})
add_target_dependencies(GCC ${GNUTAR_TARGET})
add_target_dependencies(GCC ${MPFR_TARGET})
add_target_dependencies(GCC ${MPC_TARGET})

################################################################################
# gdk-pixbuf.
add_external_project(
  ${GDK_PIXBUF_TARGET}
  PREFIX ${GDK_PIXBUF_PREFIX}
  DOWNLOAD_DIR ${GDK_PIXBUF_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O gdk-pixbuf-2.30.7.tar.xz http://ftp.gnome.org/pub/GNOME/sources/gdk-pixbuf/2.30/gdk-pixbuf-2.30.7.tar.xz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/gdk-pixbuf-2.30.7.tar.xz.sig
          gdk-pixbuf-2.30.7.tar.xz &&
      cd <SOURCE_DIR> &&
      ${GNUTAR} --strip-components 1 -xvJf
          ${GDK_PIXBUF_PREFIX}/download/gdk-pixbuf-2.30.7.tar.xz
  CONFIGURE_COMMAND echo "\
      <SOURCE_DIR>/configure --prefix=${GDK_PIXBUF_PREFIX} ${HOST} ${SYSROOT}\
      CC=${CMAKE_C_COMPILER}\
      CXX=${CMAKE_CXX_COMPILER} CFLAGS=\"${CMAKE_C_FLAGS_WITH_ARCHS}\"\
      CXXFLAGS=\"${CMAKE_CXX_FLAGS_WITH_ARCHS}\"\
      LDFLAGS=\"${CMAKE_SHARED_LINKER_FLAGS}\"\
      ${CONFIGURE_LIB_TYPE_STR}\
      PKG_CONFIG_PATH=\"${GLIB_PREFIX}/lib/pkgconfig:${LIBPNG_PREFIX}/lib/pkgconfig\"" | sh)
add_target_dependencies(GDK_PIXBUF ${GNUTAR_TARGET})
add_target_dependencies(GDK_PIXBUF ${GLIB_TARGET})
add_target_dependencies(GDK_PIXBUF ${LIBPNG_TARGET})

################################################################################
# gettext.
add_external_project(
  ${GETTEXT_TARGET}
  PREFIX ${GETTEXT_PREFIX}
  DOWNLOAD_DIR ${GETTEXT_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O gettext-0.18.3.2.tar.gz http://ftp.gnu.org/pub/gnu/gettext/gettext-0.18.3.2.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/gettext-0.18.3.2.tar.gz.sig
          gettext-0.18.3.2.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${GETTEXT_PREFIX}/download/gettext-0.18.3.2.tar.gz
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --prefix=${LIBPNG_PREFIX} ${HOST} ${SYSROOT}
          CC=${CMAKE_C_COMPILER}
          CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
          CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
          LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
          ${CONFIGURE_LIB_TYPE})

################################################################################
# gflags.
add_external_project(
  ${GFLAGS_TARGET}
  PREFIX ${GFLAGS_PREFIX}
  DOWNLOAD_COMMAND
      ${SVN} export --force http://gflags.googlecode.com/svn/trunk/ ${GFLAGS_TARGET}
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --prefix=${GFLAGS_PREFIX} ${HOST} ${SYSROOT}
          CC=${CMAKE_C_COMPILER}
          CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
          CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
          LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
          ${CONFIGURE_LIB_TYPE})

################################################################################
# glib.
add_external_project(
  ${GLIB_TARGET}
  PREFIX ${GLIB_PREFIX}
  DOWNLOAD_COMMAND
      git clone --depth 1 https://github.com/QuentinFiard/glib.git ${GLIB_TARGET}
  CONFIGURE_COMMAND
      echo "<SOURCE_DIR>/autogen.sh --prefix=${GLIB_PREFIX} ${HOST} ${SYSROOT}\
      CC=${CMAKE_C_COMPILER}\
      CXX=${CMAKE_CXX_COMPILER} CFLAGS=\"${CMAKE_C_FLAGS_WITH_ARCHS} -I${LIBFFI_PREFIX}/include -I${PROXY_LIBINTL_PREFIX}/include\"\
      CXXFLAGS=\"${CMAKE_CXX_FLAGS_WITH_ARCHS} -I${PROXY_LIBINTL_PREFIX}/include\"\
      LDFLAGS=\"${CMAKE_SHARED_LINKER_FLAGS} -L${PROXY_LIBINTL_PREFIX}/lib\"\
      ${CONFIGURE_LIB_TYPE_STR}\
      --disable-carbon\
      --disable-cocoa\
      --disable-dtrace\
      --disable-compile-warnings\
      PKG_CONFIG_PATH=\"${LIBFFI_PREFIX}/lib/pkgconfig:${ZLIB_PREFIX}/lib/pkgconfig\"\
      LIBFFI_LIBS=\"${third_party.libffi}\"" | sh)
add_target_dependencies(GLIB ${GNUTAR_TARGET})
add_target_dependencies(GLIB ${LIBFFI_TARGET})
add_target_dependencies(GLIB ${PROXY_LIBINTL_TARGET})
add_target_dependencies(GLIB ${ZLIB_TARGET})

################################################################################
# gmock.
add_external_project(
  ${GMOCK_TARGET}
  PREFIX ${GMOCK_PREFIX}
  DOWNLOAD_COMMAND
      ${SVN} export --force http://googlemock.googlecode.com/svn/trunk/ ${GMOCK_TARGET}
  CMAKE_ARGS
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
  INSTALL_COMMAND
      ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/include &&
      ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/lib &&
      cd <BINARY_DIR> &&
      find . -name "*${CMAKE_SHARED_LIBRARY_SUFFIX}" | cpio -dp <INSTALL_DIR>/lib &&
      find . -name "*${CMAKE_STATIC_LIBRARY_SUFFIX}" | cpio -dp <INSTALL_DIR>/lib &&
      cd <SOURCE_DIR>/include &&
      find . -name "*.h" | cpio -dp <INSTALL_DIR>/include)

################################################################################
# GMP.
set(GMP_C_FLAGS "${CMAKE_C_FLAGS_WITH_ARCHS} -Wl,${CMAKE_SHARED_LINKER_FLAGS}")
set(GMP_CXX_FLAGS "${CMAKE_CXX_FLAGS_WITH_ARCHS} -Wl,${CMAKE_SHARED_LINKER_FLAGS}")
set(CONFIGURE_COMMAND ./configure --prefix=${GMP_PREFIX} ${HOST} ${SYSROOT}
        --enable-cxx
        CC=${CMAKE_C_COMPILER}
        CXX=${CMAKE_CXX_COMPILER} CFLAGS=${GMP_C_FLAGS}
        CXXFLAGS=${GMP_CXX_FLAGS}
        ${CONFIGURE_LIB_TYPE})
if (IOS_BUILD OR IOS_SIMULATOR_BUILD)
  set(CONFIGURE_COMMAND ${CONFIGURE_COMMAND} --disable-assembly)
endif ()
add_external_project(
  ${GMP_TARGET}
  PREFIX ${GMP_PREFIX}
  DOWNLOAD_DIR ${GMP_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O gmp-5.1.3.tar.bz2 https://gmplib.org/download/gmp/gmp-5.1.3.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/gmp-5.1.3.tar.bz2.sig
          gmp-5.1.3.tar.bz2 &&
      cd <SOURCE_DIR> &&
      ${GNUTAR} --strip-components 1 -xvf
          ${GMP_PREFIX}/download/gmp-5.1.3.tar.bz2
  CONFIGURE_COMMAND ${CONFIGURE_COMMAND}
  BUILD_IN_SOURCE 1)
add_target_dependencies(GMP ${GNUTAR_TARGET})

################################################################################
# gnome-common.
add_external_project(
  ${GNOME_COMMON_TARGET}
  PREFIX ${GNOME_COMMON_PREFIX}
  DOWNLOAD_DIR ${GNOME_COMMON_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O gnome-common-3.12.0.tar.xz http://ftp.gnome.org/pub/GNOME/sources/gnome-common/3.12/gnome-common-3.12.0.tar.xz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/gnome-common-3.12.0.tar.xz.sig
          gnome-common-3.12.0.tar.xz &&
      cd <SOURCE_DIR> &&
      ${GNUTAR} --strip-components 1 -xvJf
          ${GNOME_COMMON_PREFIX}/download/gnome-common-3.12.0.tar.xz
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${GNOME_COMMON_PREFIX})
add_target_dependencies(GNOME_COMMON ${GNUTAR_TARGET})

################################################################################
# GNU automake.
add_external_project(
  ${GNUAUTOMAKE_TARGET}
  PREFIX ${GNUAUTOMAKE_PREFIX}
  DOWNLOAD_DIR ${GNUAUTOMAKE_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O automake-1.14.1.tar.gz http://ftp.gnu.org/pub/gnu/automake/automake-1.14.1.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/automake-1.14.1.tar.gz.sig
          automake-1.14.1.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${GNUAUTOMAKE_PREFIX}/download/automake-1.14.1.tar.gz
  CONFIGURE_COMMAND <SOURCE_DIR>/configure
  INSTALL_COMMAND
      echo "This will install automake in /usr/local." &&
      sudo make install)

################################################################################
# GNU bash.
add_external_project(
  ${GNUBASH_TARGET}
  PREFIX ${GNUBASH_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://git.savannah.gnu.org/bash.git ${GNUBASH_TARGET}
  CONFIGURE_COMMAND <SOURCE_DIR>/configure
      --with-libiconv-prefix=${LIBICONV_PREFIX}
  BUILD_COMMAND make
  INSTALL_COMMAND
      echo "This will install bash in /usr/local." &&
      sudo make install)
add_target_dependencies(GNUBASH ${LIBICONV_TARGET})

################################################################################
# GNU grep.
set(GNUGREP_LD_FLAGS "-L${PCRE_PREFIX}/lib -lpcre")
add_external_project(
  ${GNUGREP_TARGET}
  PREFIX ${GNUGREP_PREFIX}
  DOWNLOAD_DIR ${GNUGREP_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O grep-2.15.tar.xz http://ftp.gnu.org/pub/gnu/grep/grep-2.15.tar.xz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/grep-2.15.tar.xz.sig
          grep-2.15.tar.xz &&
      cd <SOURCE_DIR> &&
      ${GNUTAR} --strip-components 1 -xvJf
          ${GNUGREP_PREFIX}/download/grep-2.15.tar.xz
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${GNUGREP_PREFIX} ${HOST}
      ${SYSROOT}
      --with-libiconv-prefix=${LIBICONV_PREFIX}
      LDFLAGS=${GNUGREP_LD_FLAGS})
add_target_dependencies(GNUGREP ${GNUTAR_TARGET})
add_target_dependencies(GNUGREP ${LIBICONV_TARGET})
add_target_dependencies(GNUGREP ${PCRE_TARGET})

################################################################################
# GNU tar.
add_external_project(
  ${GNUTAR_TARGET}
  PREFIX ${GNUTAR_PREFIX}
  DOWNLOAD_DIR ${GNUTAR_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O tar-1.27.1.tar.bz2 http://ftp.gnu.org/pub/gnu/tar/tar-1.27.1.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/tar-1.27.1.tar.bz2.sig
          tar-1.27.1.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${GNUTAR_PREFIX}/download/tar-1.27.1.tar.bz2
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${GNUTAR_PREFIX} ${HOST}
      ${SYSROOT}
      --with-xz=${XZ})
add_target_dependencies(GNUTAR ${XZ_TARGET})

################################################################################
# gtest.
add_external_project(
  ${GTEST_TARGET}
  PREFIX ${GTEST_PREFIX}
  DOWNLOAD_COMMAND
      ${SVN} export --force http://googletest.googlecode.com/svn/trunk/ ${GTEST_TARGET}
  CMAKE_ARGS
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
  INSTALL_COMMAND
    cd <BINARY_DIR> &&
    find . -name "*${LIBRARY_SUFFIX}" | cpio -dp <INSTALL_DIR>/lib &&
    cd <SOURCE_DIR>/include &&
    find . -name "*.h" | cpio -dp <INSTALL_DIR>/include)

################################################################################
# HAProxy. TODO(qfiard): Make portable.
set(HAPROXY_LINKER_FLAGS "-L${PCRE_PREFIX}")
add_external_project(
  ${HAPROXY_TARGET}
  PREFIX ${HAPROXY_PREFIX}
  DOWNLOAD_DIR ${HAPROXY_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O haproxy-1.5-dev22.tar.gz http://haproxy.1wt.eu/download/1.5/src/devel/haproxy-1.5-dev22.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/haproxy-1.5-dev22.tar.gz.sig
          haproxy-1.5-dev22.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${HAPROXY_PREFIX}/download/haproxy-1.5-dev22.tar.gz
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND
      make TARGET=osx CPU_CFLAGS=${CMAKE_C_FLAGS}
      CC=${CMAKE_C_COMPILER} CXX=${CMAKE_CXX_COMPILER}
      USE_PCRE=1 USE_PCRE_JIT=1 USE_OPENSSL=1 USE_LIBCRYPT= USE_ZLIB=1
      SSL_INC=${OPENSSL_PREFIX}/include SSL_LIB=${OPENSSL_PREFIX}/lib
      PCRE_INC=${PCRE_PREFIX}/include PCRE_LIB=${PCRE_PREFIX}/lib
  INSTALL_COMMAND
      echo "This will install haproxy in /usr/local/haproxy." &&
      make install DESTDIR=${HAPROXY_PREFIX} &&
      sudo ${CMAKE_COMMAND} -E make_directory /usr/local/haproxy &&
      sudo ditto ${HAPROXY_PREFIX}/usr/local/doc /usr/local/haproxy/doc &&
      sudo ditto ${HAPROXY_PREFIX}/usr/local/sbin /usr/local/haproxy/sbin &&
      sudo ditto ${HAPROXY_PREFIX}/usr/local/share /usr/local/haproxy/share &&
      sudo rm -rf ${HAPROXY_PREFIX}/usr &&
      sudo ${CMAKE_COMMAND} -E make_directory /usr/local/haproxy/logs
  BUILD_IN_SOURCE 1)
add_target_dependencies(HAPROXY ${OPENSSL_TARGET})
add_target_dependencies(HAPROXY ${PCRE_TARGET})

################################################################################
# httpd.
add_external_project(
  ${HTTPD_TARGET}
  PREFIX ${HTTPD_PREFIX}
  DOWNLOAD_DIR ${HTTPD_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O httpd-2.4.7.tar.bz2 http://archive.apache.org/dist/httpd/httpd-2.4.7.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/httpd-2.4.7.tar.bz2.asc
          httpd-2.4.7.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${HAPROXY_PREFIX}/download/httpd-2.4.7.tar.bz2
  CONFIGURE_COMMAND <SOURCE_DIR>/configure
      --with-apr=${APR_PREFIX}
      --with-apr-util=${APR_UTIL_PREFIX}
      --with-libxml2=${LIBXML_PREFIX}
      --with-ssl=${OPENSSL_PREFIX}
      --with-pcre=${PCRE_PREFIX}
      --with-z=${ZLIB_PREFIX}
  INSTALL_COMMAND
      echo "This will install httpd in /usr/local/apache." &&
      sudo make install)
add_target_dependencies(HTTPD ${APR_TARGET})
add_target_dependencies(HTTPD ${APR_UTIL_TARGET})
add_target_dependencies(HTTPD ${LIBXML_TARGET})
add_target_dependencies(HTTPD ${OPENSSL_TARGET})
add_target_dependencies(HTTPD ${PCRE_TARGET})
add_target_dependencies(HTTPD ${ZLIB_TARGET})

################################################################################
# httpxx.
add_external_project(
  ${HTTPXX_TARGET}
  PREFIX ${HTTPXX_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --recursive --depth 1 git://github.com/QuentinFiard/httpxx.git
          ${HTTPXX_TARGET}
  CMAKE_ARGS
      -DBUILD_EXAMPLES=OFF

      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${HTTPXX_PREFIX})
add_install_name_step(HTTPXX)

################################################################################
# HWLOC.
add_external_project(
  ${HWLOC_TARGET}
  PREFIX ${HWLOC_PREFIX}
  DOWNLOAD_DIR ${HWLOC_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O hwloc-1.9.tar.bz2 http://www.open-mpi.org/software/hwloc/v1.9/downloads/hwloc-1.9.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/hwloc-1.9.tar.bz2.sig
          hwloc-1.9.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf ${HWLOC_PREFIX}/download/hwloc-1.9.tar.bz2
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${HWLOC_PREFIX}
      CC=${CMAKE_C_COMPILER}
      CXX=${CMAKE_CXX_COMPILER}
      CFLAGS=${CMAKE_C_FLAGS}
      CXXFLAGS=${CMAKE_CXX_FLAGS}
      LDFLAGS=${CMAKE_SHARED_LIBRARY_FLAGS}
      ${CONFIGURE_LIB_TYPE})

################################################################################
# ICU. TODO(qfiard): Make portable.
set(ICU_BUILD_COMMAND "\
  CC=\"${CMAKE_C_COMPILER}\"\
  CXX=\"${CMAKE_CXX_COMPILER}\"\
  CFLAGS=\"${CMAKE_C_FLAGS_WITH_ARCHS}\"\
  CXXFLAGS=\"${CMAKE_CXX_FLAGS_WITH_ARCHS}\"\
  LDFLAGS=\"${CMAKE_SHARED_LINKER_FLAGS}\"\
  <SOURCE_DIR>/source/configure --prefix=${ICU_PREFIX}\
  ${CONFIGURE_LIB_TYPE} ${HOST} ${SYSROOT}")
if (IS_IOS)
  set(ICU_BUILD_COMMAND
      "${ICU_BUILD_COMMAND} --with-cross-build=${ICU_CROSS_BUILD}\
       --with-data-packaging=archive")
  set(ICU_DATA_ARCHIVE ${ICU_PREFIX}/share/icu/52.1/icudt52l.dat)
endif ()
add_external_project(
  ${ICU_TARGET}
  PREFIX ${ICU_PREFIX}
  DOWNLOAD_DIR ${ICU_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O icu4c-52_1-src.tgz http://download.icu-project.org/files/icu4c/52.1/icu4c-52_1-src.tgz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/icu4c-52_1-src.tgz.sig
          icu4c-52_1-src.tgz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${ICU_PREFIX}/download/icu4c-52_1-src.tgz
  CONFIGURE_COMMAND echo "${ICU_BUILD_COMMAND}" | sh)
add_install_name_step(ICU)

################################################################################
# ImageMagick. TODO(qfiard): Make portable.
if (APPLE AND NOT "${CMAKE_OSX_SYSROOT}" STREQUAL "" AND
    NOT EXISTS ${CMAKE_OSX_SYSROOT}/usr/include/crt_externs.h)
  message(WARNING "crt_externs.h is missing from ${CMAKE_OSX_SYSROOT}/usr/include, please copy it from somewhere to compile ImageMagick")
endif ()
set(IMAGEMAGICK_CONFIGURE_COMMAND "\
    cd <SOURCE_DIR> &&\
    autoreconf &&\
    cd <BINARY_DIR> &&\
    <SOURCE_DIR>/configure --prefix=${IMAGEMAGICK_PREFIX} ${HOST}\
        CC=${CMAKE_C_COMPILER}\
        CXX=${CMAKE_CXX_COMPILER} CFLAGS=\"${CMAKE_C_FLAGS_WITH_ARCHS}\"\
        CXXFLAGS=\"${CMAKE_CXX_FLAGS_WITH_ARCHS}\"\
        LDFLAGS=\"${CMAKE_SHARED_LINKER_FLAGS} -L${LIBPNG_PREFIX}/lib -L${FREETYPE_PREFIX}/lib\"\
        CPPFLAGS=\"-I${LIBPNG_PREFIX}/include\"\
        ${CONFIGURE_LIB_TYPE_STR}\
        --without-x")
if (BUILD_SHARED_LIBS)
  set(IMAGEMAGICK_CONFIGURE_COMMAND
      "${IMAGEMAGICK_CONFIGURE_COMMAND}\
        --with-rsvg\
        --with-pango\
        PKG_CONFIG_PATH=\"${FREETYPE_PREFIX}/lib/pkgconfig:${LIBRSVG_PREFIX}/lib/pkgconfig:${LIBPNG_PREFIX}/lib/pkgconfig:${PANGO_PREFIX}/lib/pkgconfig:${CAIRO_PREFIX}/lib/pkgconfig:${GDK_PIXBUF_PREFIX}/lib/pkgconfig:${GLIB_PREFIX}/lib/pkgconfig:${CAIRO_PREFIX}/lib/pkgconfig:${LIBCROCO_PREFIX}/lib/pkgconfig:${PIXMAN_PREFIX}/lib/pkgconfig\"")
else ()
  set(IMAGEMAGICK_CONFIGURE_COMMAND
      "${IMAGEMAGICK_CONFIGURE_COMMAND}\
        PKG_CONFIG_PATH=\"${FREETYPE_PREFIX}/lib/pkgconfig\"")
endif ()
add_external_project(
  ${IMAGEMAGICK_TARGET}
  PREFIX ${IMAGEMAGICK_PREFIX}
  DOWNLOAD_DIR ${IMAGEMAGICK_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O ImageMagick-6.8.9-0.tar.bz2 http://www.imagemagick.org/download/ImageMagick-6.8.9-0.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/ImageMagick-6.8.9-0.tar.bz2.sig
          ImageMagick-6.8.9-0.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${IMAGEMAGICK_PREFIX}/download/ImageMagick-6.8.9-0.tar.bz2
  CONFIGURE_COMMAND echo ${IMAGEMAGICK_CONFIGURE_COMMAND} | sh
  INSTALL_COMMAND
      make install &&
      cd <INSTALL_DIR>/lib &&
      echo "\
      for f in *${LIBRARY_SUFFIX}$<SEMICOLON> do\
        echo $f| sed 's/\\(\\(^.*\\)-.*\\.\\(.*$\\)\\)/ln -sf \\1 \\2.\\3/'|grep ln|sh$<SEMICOLON>\
      done" | sh)
add_target_dependencies(IMAGEMAGICK ${FREETYPE_TARGET})
add_target_dependencies(IMAGEMAGICK ${LIBPNG_TARGET})
add_target_dependencies(IMAGEMAGICK ${LIBXML_TARGET})
if (BUILD_SHARED_LIBS)
  add_target_dependencies(IMAGEMAGICK ${LIBRSVG_TARGET})
  add_target_dependencies(IMAGEMAGICK ${PANGO_TARGET})
endif ()

################################################################################
# Intel PCM library.
set(INTEL_PCM_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
set(INTEL_PCM_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
add_external_project(
  ${INTEL_PCM_TARGET}
  PREFIX ${INTEL_PCM_PREFIX}
  DOWNLOAD_COMMAND
      git clone --depth 1 git://github.com/QuentinFiard/intel_pcm ${INTEL_PCM_TARGET}
  CMAKE_ARGS
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${INTEL_PCM_C_FLAGS}
      -DCMAKE_CXX_FLAGS=${INTEL_PCM_CXX_FLAGS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${INTEL_PCM_PREFIX})

################################################################################
# ios-ntp.
get_download_target(IOS_NTP DOWNLOAD_TARGET)
add_external_project(
  ${DOWNLOAD_TARGET}
  PREFIX ${IOS_NTP_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/jbenet/ios-ntp.git
          ${DOWNLOAD_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND
      cd <SOURCE_DIR>/src &&
      find . -name "*.h" | cpio -dp <INSTALL_DIR>/include/ios-ntp &&
      cd <SOURCE_DIR>/lib &&
      find . -name "*.h" | cpio -dp <INSTALL_DIR>/include/ios-ntp)
get_download_source_dir(IOS_NTP SOURCE_DIR)
set(SRCS
    ${SOURCE_DIR}/lib/GCDAsyncUdpSocket.m
    ${SOURCE_DIR}/src/NSDate+NetworkClock.m
    ${SOURCE_DIR}/src/NetAssociation.m
    ${SOURCE_DIR}/src/NetworkClock.m)
set_source_files_properties(${SRCS} PROPERTIES GENERATED TRUE)
objc_library(${IOS_NTP_TARGET} ${SRCS})
link_framework(${IOS_NTP_TARGET} CFNetwork CoreGraphics UIKit)
target_include_directories(${IOS_NTP_TARGET} PUBLIC ${SOURCE_DIR}/lib)
set_target_properties(
    ${IOS_NTP_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${IOS_NTP_PREFIX}/lib
    LIBRARY_OUTPUT_DIRECTORY ${IOS_NTP_PREFIX}/lib
    COMPILE_FLAGS
        "-fno-objc-arc -include ${SOURCE_DIR}/resources/ios-ntp-Prefix.pch"
    OUTPUT_NAME ios_ntp)
add_target_dependencies(IOS_NTP ${DOWNLOAD_TARGET})
set(IOS_NTP_HOSTS ${SOURCE_DIR}/resources/ntp.hosts)

################################################################################
# IMAP-2007f. TODO(qfiard): Make portable.
add_external_project(
  ${IMAP_2007F_TARGET}
  PREFIX ${IMAP_2007F_PREFIX}
  DOWNLOAD_DIR ${IMAP_2007F_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O imap-2007f.tar.gz ftp://ftp.cac.washington.edu/imap/imap-2007f.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/imap-2007f.tar.gz.sig
          imap-2007f.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${IMAP_2007F_PREFIX}/download/imap-2007f.tar.gz
  PATCH_COMMAND
      patch -Np0 < ${THIRD_PARTY_SOURCE_DIR}/imap-2007f.patch
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND
      make osx SSLTYPE=unix.nopwd SSLDIR=${OPENSSL_PREFIX} EXTRACFLAGS=-fPIC
  INSTALL_COMMAND
      cd <SOURCE_DIR> &&
      ${CMAKE_COMMAND} -E make_directory ${IMAP_2007F_PREFIX}/lib &&
      ${CMAKE_COMMAND} -E make_directory ${IMAP_2007F_PREFIX}/include &&
      cp c-client/c-client.a ${IMAP_2007F_PREFIX}/lib &&
      cd c-client &&
      find . -name "*.h" | cpio -dp ${IMAP_2007F_PREFIX}/include/
  BUILD_IN_SOURCE 1)
add_target_dependencies(IMAP_2007F ${OPENSSL_TARGET})

################################################################################
# iso_3166.
set(ISO_3166_CSV ${ISO_3166_PREFIX}/iso_3166.csv)
add_external_project(
  ${ISO_3166_TARGET}
  PREFIX ${ISO_3166_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/lukes/ISO-3166-Countries-with-Regional-Codes.git ${ISO_3166_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND
      cp -f <SOURCE_DIR>/all/all.csv ${ISO_3166_CSV})

################################################################################
# iso_639.
set(ISO_639_CSV ${ISO_639_PREFIX}/iso_639.csv)
add_external_project(
  ${ISO_639_TARGET}
  PREFIX ${ISO_639_PREFIX}
  DOWNLOAD_COMMAND
      wget -O <INSTALL_DIR>/iso_639.csv http://www.loc.gov/standards/iso639-2/ISO-639-2_utf-8.txt
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND ${NOP})

################################################################################
# iso-country-flags.
add_external_project(
  ${ISO_COUNTRY_FLAGS_TARGET}
  PREFIX ${ISO_COUNTRY_FLAGS_PREFIX}
  DOWNLOAD_DIR ${ISO_COUNTRY_FLAGS_PREFIX}
  DOWNLOAD_COMMAND
      ${SVN} export --force https://github.com/QuentinFiard/iso-country-flags-svg-collection/trunk/svg/country-squared data
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND ${NOP})

################################################################################
# iwyu.
set(IWYU_LINKER_FLAGS "-L${CLANG_PREFIX}/lib")
add_external_project(
  ${IWYU_TARGET}
  PREFIX ${IWYU_PREFIX}
  DOWNLOAD_COMMAND
      ${SVN} export --force http://include-what-you-use.googlecode.com/svn/trunk ${IWYU_TARGET}
  CMAKE_ARGS
      -DLLVM_PATH=${CLANG_PREFIX}
      -DCMAKE_EXE_LINKER_FLAGS=${IWYU_LINKER_FLAGS}
      -DCMAKE_INSTALL_PREFIX=${IWYU_PREFIX})
add_target_dependencies(IWYU ${CLANG_TARGET})

################################################################################
# jsoncpp.
add_external_project(
  ${JSONCPP_TARGET}
  PREFIX ${JSONCPP_PREFIX}
  DOWNLOAD_COMMAND
      ${SVN} export --force
          http://jsoncpp.svn.sourceforge.net/svnroot/jsoncpp/trunk/jsoncpp
          ${JSONCPP_TARGET}
  CMAKE_ARGS
      -DJSONCPP_WITH_TESTS=OFF

      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      -DCMAKE_EXE_LINKER_FLAGS=${CMAKE_EXE_LINKER_FLAGS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${JSONCPP_PREFIX})

################################################################################
# jsonpath.
if (IS_IOS)
  set(SOURCE_DIR ${MOBILE_COMMERCE_IOS_PREFIX}/src/${MOBILE_COMMERCE_IOS_TARGET})
  set(SOURCE_DIR ${SOURCE_DIR}/ATGMobileCommon/ATGMobileCommon/JSONPath)
  set(INSTALL_DIR ${JSONPATH_PREFIX})
  set(SRCS
      ${SOURCE_DIR}/ATGCustomJSONPathManager.m
      ${SOURCE_DIR}/ATGCustomJSONPathParser.m
      ${SOURCE_DIR}/ATGCustomJSONPathRegex.m
      ${SOURCE_DIR}/ATGDefaultJSONPathRegex.m
      ${SOURCE_DIR}/ATGJSONPathManager.m
      ${SOURCE_DIR}/ATGJSONPathParser.m
      ${SOURCE_DIR}/ATGJSONPathTokenizer.m)
  set_source_files_properties(${SRCS} PROPERTIES GENERATED TRUE)
  objc_library(${JSONPATH_TARGET} ${SRCS})
  add_custom_command(
    TARGET ${JSONPATH_TARGET} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${INSTALL_DIR}/include/JSONPath
    COMMAND find . -name "*.h" | cpio -dp ${INSTALL_DIR}/include/JSONPath
    WORKING_DIRECTORY ${SOURCE_DIR}
    VERBATIM)
  set_target_properties(
      ${JSONPATH_TARGET} PROPERTIES
      ARCHIVE_OUTPUT_DIRECTORY ${INSTALL_DIR}/lib
      LIBRARY_OUTPUT_DIRECTORY ${INSTALL_DIR}/lib
      OUTPUT_NAME jsonpath)
  get_download_target(MOBILE_COMMERCE_IOS MOBILE_COMMERCE_IOS_DOWNLOAD_TARGET)
  add_target_dependencies(JSONPATH ${MOBILE_COMMERCE_IOS_DOWNLOAD_TARGET})
endif ()

################################################################################
# LDAP.
set(LDAP_CPPFLAGS "-I${BERKELEY_DB_PREFIX}/include")
set(LDAP_LDFLAGS "-L${BERKELEY_DB_PREFIX}/lib")
add_external_project(
  ${LDAP_TARGET}
  PREFIX ${LDAP_PREFIX}
  DOWNLOAD_DIR ${LDAP_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O openldap-2.4.38.tgz ftp://ftp.openldap.org/pub/OpenLDAP/openldap-release/openldap-2.4.38.tgz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/openldap-2.4.38.tgz.sig
          openldap-2.4.38.tgz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${LDAP_PREFIX}/download/openldap-2.4.38.tgz
  CONFIGURE_COMMAND LDFLAGS=${LDAP_LDFLAGS} CPPFLAGS=${LDAP_CPPFLAGS}
      <SOURCE_DIR>/configure --prefix=${LDAP_PREFIX} ${HOST} ${SYSROOT}
  BUILD_COMMAND make
  INSTALL_COMMAND make install)
add_target_dependencies(LDAP ${BERKELEY_DB_TARGET})

################################################################################
# LDAP SASL. TODO(qfiard): Make portable.
add_external_project(
  ${LDAP_SASL_TARGET}
  PREFIX ${LDAP_SASL_PREFIX}
  DOWNLOAD_DIR ${LDAP_SASL_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O cyrus-sasl-2.1.25.tar.gz http://ftp.andrew.cmu.edu/pub/cyrus-mail/cyrus-sasl-2.1.25.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/cyrus-sasl-2.1.25.tar.gz.sig
          cyrus-sasl-2.1.25.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${LDAP_SASL_PREFIX}/download/cyrus-sasl-2.1.25.tar.gz
  PATCH_COMMAND
      patch -Np0 < ${THIRD_PARTY_SOURCE_DIR}/ldap_sasl.patch
  CONFIGURE_COMMAND
      LDFLAGS=${LDAP_LDFLAGS} CPPFLAGS=${LDAP_CPPFLAGS}
      <SOURCE_DIR>/configure --prefix=${LDAP_SASL_PREFIX} ${HOST} ${SYSROOT}
      --with-dblib=berkeley
      --with-bdb-incdir=${BERKELEY_DB_PREFIX}/include
      --with-bdb-libdir=${BERKELEY_DB_PREFIX}/lib
      --with-openssl=${OPENSSL_PREFIX}
      --with-ldap=${LDAP_PREFIX}
      --disable-macos-framework
  BUILD_COMMAND make
  INSTALL_COMMAND make install)
add_target_dependencies(LDAP_SASL ${BERKELEY_DB_TARGET})
add_target_dependencies(LDAP_SASL ${LDAP_TARGET})
add_target_dependencies(LDAP_SASL ${OPENSSL_TARGET})

################################################################################
# Leveldb.
add_external_project(
  ${LEVELDB_TARGET}
  PREFIX ${LEVELDB_PREFIX}
  DOWNLOAD_COMMAND
      git clone https://code.google.com/p/leveldb ${LEVELDB_TARGET}
  CONFIGURE_COMMAND ${NOP}
  INSTALL_COMMAND
      find . -name "*${LIBRARY_SUFFIX}*" | cpio -dp <INSTALL_DIR>/lib &&
      cp -rf include <INSTALL_DIR>/include
  BUILD_IN_SOURCE 1)

################################################################################
# libcroco.
add_external_project(
  ${LIBCROCO_TARGET}
  PREFIX ${LIBCROCO_PREFIX}
  DOWNLOAD_DIR ${LIBCROCO_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O libcroco-0.6.8.tar.xz http://ftp.gnome.org/pub/GNOME/sources/libcroco/0.6/libcroco-0.6.8.tar.xz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/libcroco-0.6.8.tar.xz.sig
          libcroco-0.6.8.tar.xz &&
      cd <SOURCE_DIR> &&
      ${GNUTAR} --strip-components 1 -xvJf
          ${LIBCROCO_PREFIX}/download/libcroco-0.6.8.tar.xz
  CONFIGURE_COMMAND echo "\
      <SOURCE_DIR>/configure --prefix=${LIBCROCO_PREFIX} ${HOST} ${SYSROOT}\
      CC=${CMAKE_C_COMPILER}\
      CXX=${CMAKE_CXX_COMPILER} CFLAGS=\"${CMAKE_C_FLAGS_WITH_ARCHS}\"\
      CXXFLAGS=\"${CMAKE_CXX_FLAGS_WITH_ARCHS}\"\
      LDFLAGS=\"${CMAKE_SHARED_LINKER_FLAGS}\"\
      ${CONFIGURE_LIB_TYPE_STR}\
      --disable-Bsymbolic\
      PKG_CONFIG_PATH=\"${GLIB_PREFIX}/lib/pkgconfig\"" | sh)
add_target_dependencies(LIBCROCO ${GLIB_TARGET})
add_target_dependencies(LIBCROCO ${GNUTAR_TARGET})

################################################################################
# libcurl. TODO(qfiard): Make portable.
set(LIBCURL_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -L${ZLIB_PREFIX}/lib")
set(CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${LIBCURL_PREFIX} ${HOST}
        ${SYSROOT} --with-zlib=${ZLIB_PREFIX})
if (APPLE AND NOT IS_IOS)
  set(CONFIGURE_COMMAND ${CONFIGURE_COMMAND} --with-darwinssl)
else ()
  set(CONFIGURE_COMMAND ${CONFIGURE_COMMAND} --with-ssl=${OPENSSL_PREFIX})
endif ()
set(CONFIGURE_COMMAND ${CONFIGURE_COMMAND} CC=${CMAKE_C_COMPILER}
        CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
        CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
        LDFLAGS=${LIBCURL_LINKER_FLAGS}
        ${CONFIGURE_LIB_TYPE})
add_external_project(
  ${LIBCURL_TARGET}
  PREFIX ${LIBCURL_PREFIX}
  DOWNLOAD_DIR ${LIBCURL_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O curl-7.33.0.tar.bz2 http://curl.haxx.se/download/curl-7.33.0.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/curl-7.33.0.tar.bz2.asc
          curl-7.33.0.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${LIBCURL_PREFIX}/download/curl-7.33.0.tar.bz2
  CONFIGURE_COMMAND ${CONFIGURE_COMMAND})
if (NOT APPLE OR IS_IOS)
  add_target_dependencies(LIBCURL ${OPENSSL_TARGET})
endif ()
add_target_dependencies(LIBCURL ${ZLIB_TARGET})

################################################################################
# libcxxabi.
get_source_dir(LIBCXX SOURCE_DIR)
set(LIBCXXABI_OPTIONS "-I${SOURCE_DIR}/include ${ARCHS_AS_FLAGS}")
if (APPLE AND NOT "${CMAKE_OSX_SYSROOT}" STREQUAL "")
  set(LIBCXXABI_OPTIONS "${LIBCXXABI_OPTIONS} --sysroot ${CMAKE_OSX_SYSROOT}")
endif ()
set(LIBCXXABI_BUILD_COMMAND
    "cd <INSTALL_DIR>/lib &&\
     CC=${CMAKE_C_COMPILER} CXX=${CMAKE_CXX_COMPILER}\
     OPTIONS=\"${LIBCXXABI_OPTIONS}\"")
set(LIBCXXABI_BUILD_COMMAND_END "./buildit")
if (BUILD_SHARED_LIBS)
  set(LIBCXXABI_BUILD_COMMAND_END
      "${LIBCXXABI_BUILD_COMMAND_END} && ln -sf libcxxabi.1.0.dylib libcxxabi.dylib")
else ()
  set(LIBCXXABI_BUILD_COMMAND "${LIBCXXABI_BUILD_COMMAND} BUILD_STATIC=1")
endif ()
set(LIBCXXABI_BUILD_COMMAND "${LIBCXXABI_BUILD_COMMAND} ${LIBCXXABI_BUILD_COMMAND_END}")
add_external_project(
  ${LIBCXXABI_TARGET}
  PREFIX ${LIBCXXABI_PREFIX}
  DOWNLOAD_COMMAND
      ${SVN} export --force http://llvm.org/svn/llvm-project/libcxxabi/trunk <INSTALL_DIR>
  PATCH_COMMAND
    cd <INSTALL_DIR>/lib && patch -p0 < ${THIRD_PARTY_SOURCE_DIR}/libcxxabi.patch
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND echo ${LIBCXXABI_BUILD_COMMAND} | sh
  INSTALL_COMMAND ${NOP})
add_install_name_step(LIBCXXABI)
add_target_dependencies(LIBCXXABI ${LIBCXX_TARGET}_headers)

################################################################################
# libffi.
add_external_project(
  ${LIBFFI_TARGET}
  PREFIX ${LIBFFI_PREFIX}
  DOWNLOAD_DIR ${LIBFFI_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O libffi-3.0.13.tar.gz ftp://sourceware.org/pub/libffi/libffi-3.0.13.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/libffi-3.0.13.tar.gz.sig
          libffi-3.0.13.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${LIBFFI_PREFIX}/download/libffi-3.0.13.tar.gz
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --prefix=${LIBFFI_PREFIX} ${HOST} ${SYSROOT}
      CC=${CMAKE_C_COMPILER}
      CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      ${CONFIGURE_LIB_TYPE}
  INSTALL_COMMAND
      make install &&
      cd <INSTALL_DIR> &&
      mv lib/libffi-3.0.13/include . &&
      rm -rf lib/libffi-3.0.13)

################################################################################
# libicon.
add_external_project(
  ${LIBICONV_TARGET}
  PREFIX ${LIBICONV_PREFIX}
  DOWNLOAD_DIR ${LIBICONV_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O libiconv-1.14.tar.gz http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/libiconv-1.14.tar.gz.sig
          libiconv-1.14.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${LIBICONV_PREFIX}/download/libiconv-1.14.tar.gz
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${LIBICONV_PREFIX} ${HOST}
      ${SYSROOT})

################################################################################
# LibJPG.
add_external_project(
  ${LIBJPG_TARGET}
  PREFIX ${LIBJPG_PREFIX}
  DOWNLOAD_DIR ${LIBJPG_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O jpegsrc.v9.tar.gz http://www.ijg.org/files/jpegsrc.v9.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/jpegsrc.v9.tar.gz.sig
          jpegsrc.v9.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${LIBJPG_PREFIX}/download/jpegsrc.v9.tar.gz
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${LIBJPG_PREFIX} ${HOST}
      ${SYSROOT})

################################################################################
# libmcrypt.
add_external_project(
  ${LIBMCRYPT_TARGET}
  PREFIX ${LIBMCRYPT_PREFIX}
  DOWNLOAD_DIR ${LIBMCRYPT_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O libmcrypt-2.5.8.tar.bz2 http://downloads.sourceforge.net/project/mcrypt/Libmcrypt/2.5.8/libmcrypt-2.5.8.tar.bz2?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fmcrypt%2Ffiles%2FLibmcrypt%2F2.5.8%2F&ts=1386067766&use_mirror=kent &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/libmcrypt-2.5.8.tar.bz2.sig
          libmcrypt-2.5.8.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${LIBMCRYPT_PREFIX}/download/libmcrypt-2.5.8.tar.bz2
  CONFIGURE_COMMAND
      rm libltdl/configure &&
      cd libltdl &&
      autoconf &&
      cd <SOURCE_DIR> &&
      <SOURCE_DIR>/configure --prefix=${LIBMCRYPT_PREFIX} ${HOST} ${SYSROOT}
          --disable-posix-threads --enable-dynamic-loading
  BUILD_IN_SOURCE 1)

################################################################################
# libmhash.
add_external_project(
  ${LIBMHASH_TARGET}
  PREFIX ${LIBMHASH_PREFIX}
  DOWNLOAD_DIR ${LIBMHASH_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O mhash-0.9.9.9.tar.bz2 http://downloads.sourceforge.net/project/mhash/mhash/0.9.9.9/mhash-0.9.9.9.tar.bz2?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fmhash%2Ffiles%2Fmhash%2F0.9.9.9%2F&ts=1386068273&use_mirror=kent &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/mhash-0.9.9.9.tar.bz2.sig
          mhash-0.9.9.9.tar.bz2 &&
      cd <SOURCE_DIR> &&
      unzip --strip-components 1 -xvf
          ${LIBMHASH_PREFIX}/download/mhash-0.9.9.9.tar.bz2
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${LIBMHASH_PREFIX} ${HOST}
      ${SYSROOT}
  BUILD_IN_SOURCE 1)

################################################################################
# LibPNG.
add_external_project(
  ${LIBPNG_TARGET}
  PREFIX ${LIBPNG_PREFIX}
  DOWNLOAD_COMMAND
    ${GIT} clone git://git.code.sf.net/p/libpng/code ${LIBPNG_TARGET} &&
    cd ${LIBPNG_TARGET} &&
    ${GIT} checkout v1.6.9 &&
    rm -rf .git
  CONFIGURE_COMMAND
      cd <SOURCE_DIR> &&
      ./autogen.sh &&
      cd <BINARY_DIR> &&
      <SOURCE_DIR>/configure --prefix=${LIBPNG_PREFIX} ${HOST} ${SYSROOT}
          CC=${CMAKE_C_COMPILER}
          CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
          CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
          LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
          ${CONFIGURE_LIB_TYPE})
add_install_name_step(LIBPNG)
add_target_dependencies(LIBPNG ${GNUAUTOMAKE_TARGET})

################################################################################
# librsvg.
add_external_project(
  ${LIBRSVG_TARGET}
  PREFIX ${LIBRSVG_PREFIX}
  DOWNLOAD_DIR ${LIBRSVG_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O librsvg-2.40.2.tar.xz http://ftp.gnome.org/pub/gnome/sources/librsvg/2.40/librsvg-2.40.2.tar.xz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/librsvg-2.40.2.tar.xz.sig
          librsvg-2.40.2.tar.xz &&
      cd <SOURCE_DIR> &&
      ${GNUTAR} --strip-components 1 -xvJf
          ${LIBRSVG_PREFIX}/download/librsvg-2.40.2.tar.xz
  CONFIGURE_COMMAND echo "\
      <SOURCE_DIR>/configure --prefix=${LIBRSVG_PREFIX} ${HOST} ${SYSROOT}\
      CC=${CMAKE_C_COMPILER}\
      CXX=${CMAKE_CXX_COMPILER} CFLAGS=\"${CMAKE_C_FLAGS_WITH_ARCHS}\"\
      CXXFLAGS=\"${CMAKE_CXX_FLAGS_WITH_ARCHS}\"\
      LDFLAGS=\"${CMAKE_SHARED_LINKER_FLAGS}\"\
      ${CONFIGURE_LIB_TYPE_STR}\
      --disable-Bsymbolic\
      --enable-introspection=no\
      PKG_CONFIG_PATH=\"${GDK_PIXBUF_PREFIX}/lib/pkgconfig:${GLIB_PREFIX}/lib/pkgconfig:${CAIRO_PREFIX}/lib/pkgconfig:${LIBCROCO_PREFIX}/lib/pkgconfig:${LIBPNG_PREFIX}/lib/pkgconfig:${PIXMAN_PREFIX}/lib/pkgconfig:${PANGO_PREFIX}/lib/pkgconfig\"" | sh)
add_target_dependencies(LIBRSVG ${CAIRO_TARGET})
add_target_dependencies(LIBRSVG ${GNUTAR_TARGET})
add_target_dependencies(LIBRSVG ${GDK_PIXBUF_TARGET})
add_target_dependencies(LIBRSVG ${GLIB_TARGET})
add_target_dependencies(LIBRSVG ${LIBCROCO_TARGET})
add_target_dependencies(LIBRSVG ${LIBPNG_TARGET})
add_target_dependencies(LIBRSVG ${PANGO_TARGET})
add_target_dependencies(LIBRSVG ${PIXMAN_TARGET})

################################################################################
# libusb.
add_external_project(
  ${LIBUSB_TARGET}
  PREFIX ${LIBUSB_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://git.libusb.org/libusb.git ${LIBUSB_TARGET}
  CONFIGURE_COMMAND
      <SOURCE_DIR>/autogen.sh --prefix=${LIBUSB_PREFIX} ${HOST} ${SYSROOT}
          CC=${CMAKE_C_COMPILER}
          CXX=${CMAKE_CXX_COMPILER}
          CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
          CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
          LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
          ${CONFIGURE_LIB_TYPE}
  INSTALL_COMMAND
      make install &&
      mv -f <INSTALL_DIR>/include/libusb-1.0 <INSTALL_DIR>/include/libusb
  BUILD_IN_SOURCE 1)

################################################################################
# libxml.
if (IOS_BUILD OR IOS_SIMULATOR_BUILD)
  add_custom_target(${LIBXML_TARGET})
else ()
  add_external_project(
    ${LIBXML_TARGET}
    PREFIX ${LIBXML_PREFIX}
    DOWNLOAD_COMMAND
        ${GIT} clone --depth 1 git://git.gnome.org/libxml2 ${LIBXML_TARGET}
    CONFIGURE_COMMAND
        <SOURCE_DIR>/autogen.sh --prefix=${LIBXML_PREFIX} ${HOST} ${SYSROOT}
            --with-icu=${ICU_PREFIX}
            --with-lzma=${XZ_PREFIX}
            --with-zlib=${ZLIB_PREFIX}
            CC=${CMAKE_C_COMPILER}
            CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
            CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
            LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
            ${WITH_PYTHON}
            ${CONFIGURE_LIB_TYPE})
  add_target_dependencies(LIBXML ${ICU_TARGET})
  add_target_dependencies(LIBXML ${XZ_TARGET})
  add_target_dependencies(LIBXML ${ZLIB_TARGET})
endif ()

################################################################################
# LMDB.
add_external_project(
  ${LMDB_TARGET}
  PREFIX ${LMDB_PREFIX}
  DOWNLOAD_DIR ${LMDB_PREFIX}/download
  DOWNLOAD_COMMAND
    git clone --depth 1 -b mdb.master git://github.com/QuentinFiard/lmdb.git &&
    rm -rf <SOURCE_DIR> &&
    mv -f lmdb/libraries/liblmdb <SOURCE_DIR>
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND
    make CC=${CMAKE_C_COMPILER}
  INSTALL_COMMAND
    mkdir -p <INSTALL_DIR>/include/lmdb &&
    cp -f lmdb.h <INSTALL_DIR>/include/lmdb &&
    mkdir -p <INSTALL_DIR>/lib &&
    cp -f liblmdb.so <INSTALL_DIR>/lib/liblmdb${CMAKE_SHARED_LIBRARY_SUFFIX} &&
    cp -f liblmdb.a <INSTALL_DIR>/lib/liblmdb${CMAKE_STATIC_LIBRARY_SUFFIX}
  BUILD_IN_SOURCE 1)
add_install_name_step(LMDB)

################################################################################
# lpsolve.
set(BUILD_COMMAND cd lpsolve55 && sh)
if (APPLE)
  set(BUILD_COMMAND ${BUILD_COMMAND} ccc.osx)
else ()
  set(BUILD_COMMAND ${BUILD_COMMAND} ccc)
endif ()
add_external_project(
  ${LPSOLVE_TARGET}
  PREFIX ${LPSOLVE_PREFIX}
  DOWNLOAD_DIR ${LPSOLVE_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O lp_solve_5.5.0.15_source.tar.gz http://downloads.sourceforge.net/project/lpsolve/lpsolve/5.5.0.15/lp_solve_5.5.0.15_source.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/lp_solve_5.5.0.15_source.tar.gz.sig
          lp_solve_5.5.0.15_source.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${LPSOLVE_PREFIX}/download/lp_solve_5.5.0.15_source.tar.gz
  PATCH_COMMAND
      patch -p1 < ${THIRD_PARTY_SOURCE_DIR}/lpsolve.patch
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${BUILD_COMMAND}
  INSTALL_COMMAND
      mkdir -p <INSTALL_DIR>/lib &&
      find . -name "*${LIBRARY_SUFFIX}" | xargs -Ifile cp -f file <INSTALL_DIR>/lib &&
      find . -name "*.h" | cpio -dp <INSTALL_DIR>/include
  BUILD_IN_SOURCE 1)
add_install_name_step(LPSOLVE)

################################################################################
# MarisaTrie.
add_external_project(
  ${MARISA_TRIE_TARGET}
  PREFIX ${MARISA_TRIE_PREFIX}
  DOWNLOAD_DIR ${MARISA_TRIE_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O marisa-0.2.4.tar.gz https://marisa-trie.googlecode.com/files/marisa-0.2.4.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/marisa-0.2.4.tar.gz.sig
          marisa-0.2.4.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${MARISA_TRIE_PREFIX}/download/marisa-0.2.4.tar.gz
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --prefix=${MARISA_TRIE_PREFIX} ${HOST} ${SYSROOT}
          CC=${CMAKE_C_COMPILER}
          CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
          CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
          LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
          ${CONFIGURE_LIB_TYPE})

################################################################################
# Maven.
add_external_project(
  ${MAVEN_TARGET}
  PREFIX ${MAVEN_PREFIX}
  DOWNLOAD_DIR ${MAVEN_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O apache-maven-3.1.1-src.tar.gz http://archive.apache.org/dist/maven/maven-3/3.1.1/source/apache-maven-3.1.1-src.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/apache-maven-3.1.1-src.tar.gz.asc
          apache-maven-3.1.1-src.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${MAVEN_PREFIX}/download/apache-maven-3.1.1-src.tar.gz
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND
      M2_HOME=${MAVEN_PREFIX}/build ${ANT}
  INSTALL_COMMAND
      cd <INSTALL_DIR>/build &&
      find . | cpio -dp <INSTALL_DIR> &&
      cd <INSTALL_DIR> &&
      rm -rf <INSTALL_DIR>/build
  BUILD_IN_SOURCE 1)

################################################################################
# Maven libraries.
set(MAVEN_LAST_DOWNLOAD "${THIRD_PARTY_BINARY_DIR}/java/last_download")
set(MAVEN_CLASSPATH_UPDATE "${THIRD_PARTY_BINARY_DIR}/java/classpath_update")
add_custom_command(
  OUTPUT ${MAVEN_LAST_DOWNLOAD}
  COMMAND ${MVN} -f ${THIRD_PARTY_SOURCE_DIR}/pom.xml
      -DprojectBinaryDir=${PROJECT_BINARY_DIR}
      -q dependency:copy-dependencies
  COMMAND date > ${MAVEN_LAST_DOWNLOAD}
  MAIN_DEPENDENCY ${THIRD_PARTY_SOURCE_DIR}/pom.xml)
set(GENERATE_CLASSPATH_FOR_MAVEN_LIBS
    ${SUPPORT_DIR}/generate_classpath_for_maven_libs.py)
add_custom_command(
  OUTPUT ${MAVEN_CLASSPATH_UPDATE}
  COMMAND ${GENERATE_CLASSPATH_FOR_MAVEN_LIBS} "${MVN}"
      "${THIRD_PARTY_SOURCE_DIR}/pom.xml" "${THIRD_PARTY_BINARY_DIR}/java"
  COMMAND date > ${MAVEN_CLASSPATH_UPDATE}
  MAIN_DEPENDENCY ${MAVEN_LAST_DOWNLOAD}
  DEPENDS ${GENERATE_CLASSPATH_FOR_MAVEN_LIBS})
add_custom_target(${MAVEN_LIBS_TARGET}
                  SOURCES ${MAVEN_LAST_DOWNLOAD} ${MAVEN_CLASSPATH_UPDATE})
add_target_dependencies(MAVEN_LIBS ${MAVEN_TARGET})

################################################################################
# Mcrypt.
set(MCRYPT_CPPFLAGS "-I${LIBMHASH_PREFIX}/include -I/usr/include/sys\
    -DSTDOUT_FILENO=1 -DSTDIN_FILENO=0")
set(MCRYPT_LDFLAGS "-L${LIBMHASH_PREFIX}/lib")
add_external_project(
  ${MCRYPT_TARGET}
  PREFIX ${MCRYPT_PREFIX}
  DOWNLOAD_DIR ${MCRYPT_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O mcrypt-2.6.8.tar.gz http://downloads.sourceforge.net/project/mcrypt/MCrypt/2.6.8/mcrypt-2.6.8.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fmcrypt%2Ffiles%2FMCrypt%2F2.6.8%2F&ts=1386067598&use_mirror=kent &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/mcrypt-2.6.8.tar.gz.sig
          mcrypt-2.6.8.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${MCRYPT_PREFIX}/download/mcrypt-2.6.8.tar.gz
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${MCRYPT_PREFIX} ${HOST}
      ${SYSROOT}
      --with-libiconv-prefix=${LIBICONV_PREFIX}
      --with-libmcrypt-prefix=${LIBMCRYPT_PREFIX}
      --with-libmhash-prefix=${LIBMHASH_PREFIX}
      CPPFLAGS=${MCRYPT_CPPFLAGS}
      LDFLAGS=${MCRYPT_LDFLAGS}
  BUILD_IN_SOURCE 1)
add_target_dependencies(MCRYPT ${LIBICONV_TARGET})
add_target_dependencies(MCRYPT ${LIBMCRYPT_TARGET})
add_target_dependencies(MCRYPT ${LIBMHASH_TARGET})

################################################################################
# Mili.
add_external_project(
  ${MILI_TARGET}
  PREFIX ${MILI_PREFIX}
  DOWNLOAD_COMMAND
      ${HG} clone https://code.google.com/p/mili ${MILI_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND find mili | cpio -dp <INSTALL_DIR>/include
  BUILD_IN_SOURCE 1)

################################################################################
# MobileCommerceiOS.
if (IS_IOS)
  get_download_target(MOBILE_COMMERCE_IOS DOWNLOAD_TARGET)
  add_external_project(
    ${DOWNLOAD_TARGET}
    PREFIX ${MOBILE_COMMERCE_IOS_PREFIX}
    DOWNLOAD_COMMAND
        ${GIT} clone --depth 1 git://github.com/QuentinFiard/MobileCommerceiOS
            ${MOBILE_COMMERCE_IOS_TARGET}
    CONFIGURE_COMMAND ${NOP}
    BUILD_COMMAND ${NOP}
    INSTALL_COMMAND ${NOP})
  add_external_project(
    ${MOBILE_COMMERCE_IOS_TARGET}
    PREFIX ${MOBILE_COMMERCE_IOS_PREFIX}
    DOWNLOAD_COMMAND ${NOP}
    CONFIGURE_COMMAND ${NOP}
    BUILD_COMMAND
        find <SOURCE_DIR> -path <SOURCE_DIR>/ATGMobileStore -prune -o
            -name "*.xcodeproj" -print |
        xargs -I{} xcodebuild -project {} -configuration Release
            -sdk ${XCODE_SDK} clean build DSTROOT=<INSTALL_DIR>
            INSTALL_PATH=/lib
    INSTALL_COMMAND
        cd <SOURCE_DIR>/build/Release-${SDK} &&
        find . -name "*.h" | cpio -dp <INSTALL_DIR>/include &&
        find . -name "*.a" | cpio -dp <INSTALL_DIR>/lib)
  add_dependencies(${MOBILE_COMMERCE_IOS_TARGET} ${DOWNLOAD_TARGET})
endif ()

################################################################################
# MPC.
add_external_project(
  ${MPC_TARGET}
  PREFIX ${MPC_PREFIX}
  DOWNLOAD_DIR ${MPC_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O mpc-1.0.1.tar.gz http://www.multiprecision.org/mpc/download/mpc-1.0.1.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/mpc-1.0.1.tar.gz.sig
          mpc-1.0.1.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${MPC_PREFIX}/download/mpc-1.0.1.tar.gz
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --prefix=${MPC_PREFIX} ${HOST} ${SYSROOT}
          --with-gmp=${GMP_PREFIX}
          --with-mpfr=${MPFR_PREFIX}
          CC=${CMAKE_C_COMPILER}
          CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
          CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
          LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
          ${CONFIGURE_LIB_TYPE})
add_target_dependencies(MPC ${GMP_TARGET})
add_target_dependencies(MPC ${MPFR_TARGET})

################################################################################
# mod_jk.
get_source_dir(HTTPD SOURCE_DIR)
set(HTTPD_SOURCE_DIR ${SOURCE_DIR})
add_external_project(
  ${MOD_JK_TARGET}
  PREFIX ${MOD_JK_PREFIX}
  DOWNLOAD_DIR ${MOD_JK_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O tomcat-connectors-1.2.37-src.tar.gz http://archive.apache.org/dist/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.37-src.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/tomcat-connectors-1.2.37-src.tar.gz.sig
          tomcat-connectors-1.2.37-src.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${MOD_JK_PREFIX}/download/tomcat-connectors-1.2.37-src.tar.gz
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --with-apache=${HTTPD_SOURCE_DIR})

################################################################################
# mod_wsgi.
add_external_project(
  ${MOD_WSGI_TARGET}
  PREFIX ${MOD_WSGI_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/GrahamDumpleton/mod_wsgi.git
          ${MOD_WSGI_TARGET}
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure
          --with-apxs=/usr/local/apache/httpd/bin/apxs
          --with-python=${VIRTUALENV_PREFIX}/env/bin/python
  INSTALL_COMMAND
      echo "This will install mod_wsgi in /usr/local/apache/httpd/modules" &&
      sudo make install
  BUILD_IN_SOURCE 1)
add_target_dependencies(MOD_WSGI ${VIRTUALENV_TARGET})

################################################################################
# MPFR.
add_external_project(
  ${MPFR_TARGET}
  PREFIX ${MPFR_PREFIX}
  DOWNLOAD_DIR ${MPFR_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O mpfr-3.1.2.tar.bz2 http://www.mpfr.org/mpfr-current/mpfr-3.1.2.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/mpfr-3.1.2.tar.bz2.asc
          mpfr-3.1.2.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${MPFR_PREFIX}/download/mpfr-3.1.2.tar.bz2
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --prefix=${MPFR_PREFIX} ${HOST} ${SYSROOT}
          --with-gmp=${GMP_PREFIX}
          CC=${CMAKE_C_COMPILER}
          CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
          CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
          LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
          ${CONFIGURE_LIB_TYPE})
add_target_dependencies(MPFR ${GMP_TARGET})

################################################################################
# MPICH.
add_external_project(
  ${MPICH_TARGET}
  PREFIX ${MPICH_PREFIX}
  DOWNLOAD_DIR ${MPICH_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O mpich-3.1.1.tar.gz http://www.mpich.org/static/downloads/3.1.1/mpich-3.1.1.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/mpich-3.1.1.tar.gz.sig
          mpich-3.1.1.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${MPICH_PREFIX}/download/mpich-3.1.1.tar.gz
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --prefix=${MPICH_PREFIX} ${HOST} ${SYSROOT}
          --enable-threads=multiple
          CC=${CMAKE_C_COMPILER}
          CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
          CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
          LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
          ${CONFIGURE_LIB_TYPE})

################################################################################
# MWPhotoBrowser.
if (IS_IOS)
  add_external_project(
    ${MW_PHOTO_BROWSER_TARGET}
    PREFIX ${MW_PHOTO_BROWSER_PREFIX}
    DOWNLOAD_COMMAND
        ${GIT} clone --depth 1 git://github.com/mwaterfall/MWPhotoBrowser.git
            ${MW_PHOTO_BROWSER_TARGET}
    CONFIGURE_COMMAND ${NOP}
    BUILD_COMMAND
        xcodebuild -project <SOURCE_DIR>/MWPhotoBrowser/MWPhotoBrowser.xcodeproj
            -sdk ${XCODE_SDK} ARCHS=${SPACE_SEP_ARCHS}
    INSTALL_COMMAND
        ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/lib &&
        cd <SOURCE_DIR>/MWPhotoBrowser &&
        cp -f build/Release-${XCODE_SDK}/libMWPhotoBrowser.a <INSTALL_DIR>/lib &&
        cd Classes &&
        find . -name "*.h" | cpio -dp <INSTALL_DIR>/include/MWPhotoBrowser
    BUILD_IN_SOURCE 1)
endif ()

################################################################################
# MySQL.
add_external_project(
  ${MYSQL_TARGET}
  PREFIX ${MYSQL_PREFIX}
  DOWNLOAD_DIR ${MYSQL_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O mysql-5.6.17.tar.gz http://dev.mysql.com/get/Downloads/MySQL-5.6/mysql-5.6.17.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/mysql-5.6.17.tar.gz.sig
          mysql-5.6.17.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${MYSQL_PREFIX}/download/mysql-5.6.17.tar.gz
  PATCH_COMMAND
      patch -p0 < ${THIRD_PARTY_SOURCE_DIR}/mysql.patch
  CMAKE_ARGS
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
      -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS}
      -DCMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      # Do not use, leads to undefined symbols errors.
      # -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${MYSQL_PREFIX}
      -DWITH_ZLIB=test
      -DZLIB_ROOT=${ZLIB_PREFIX}
      -DWITH_SSL_PATH=${OPENSSL_PREFIX})
add_install_name_step(MYSQL)
add_target_dependencies(MYSQL ${OPENSSL_TARGET})
add_target_dependencies(MYSQL ${ZLIB_TARGET})

################################################################################
# Mysql C++/Connector.
set(MYSQLCPPCONN_C_FLAGS "-I${MYSQL_PREFIX}/include ${CMAKE_C_FLAGS}")
set(MYSQLCPPCONN_CXX_FLAGS "-I${MYSQL_PREFIX}/include ${CMAKE_CXX_FLAGS}")
set(MYSQLCPPCONN_LINKER_FLAGS
    "-L${MYSQL_PREFIX}/lib ${CMAKE_SHARED_LINKER_FLAGS}")
add_external_project(
  ${MYSQLCPPCONN_TARGET}
  PREFIX ${MYSQLCPPCONN_PREFIX}
  DOWNLOAD_DIR ${MYSQLCPPCONN_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O mysqlcppconn.tar.gz http://dev.mysql.com/get/Downloads/Connector-C++/mysql-connector-c++-1.1.3.tar.gz/from/http://cdn.mysql.com/ &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf ${MYSQLCPPCONN_PREFIX}/download/mysqlcppconn.tar.gz
  CMAKE_ARGS
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
      -DCMAKE_C_FLAGS=${MYSQLCPPCONN_C_FLAGS}
      -DCMAKE_CXX_FLAGS=${MYSQLCPPCONN_CXX_FLAGS}
      -DCMAKE_SHARED_LINKER_FLAGS=${MYSQLCPPCONN_LINKER_FLAGS}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
      -DCMAKE_INSTALL_PREFIX=${MYSQLCPPCONN_PREFIX}
  BUILD_IN_SOURCE 1  # Needed for config header file.
  )
add_install_name_step(MYSQLCPPCONN)
add_target_dependencies(MYSQLCPPCONN ${MYSQL_TARGET})

################################################################################
# Nginx.
set(NGINX_C_FLAGS "-D FD_SETSIZE=2048 ${CMAKE_C_FLAGS}")
add_external_project(
  ${NGINX_TARGET}
  PREFIX ${NGINX_PREFIX}
  DOWNLOAD_DIR ${NGINX_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O nginx-1.4.3.tar.gz http://nginx.org/download/nginx-1.4.3.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/nginx-1.4.3.tar.gz.sig
          nginx-1.4.3.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${NGINX_PREFIX}/download/nginx-1.4.3.tar.gz
  CONFIGURE_COMMAND
      ./configure --with-http_ssl_module
          --with-cc-opt=${NGINX_C_FLAGS}
  BUILD_COMMAND make -j
  INSTALL_COMMAND
      echo "This will install nginx in /usr/local/nginx." &&
      sudo make install &&
      sudo ${CMAKE_COMMAND} -E make_directory /usr/local/nginx/logs
  BUILD_IN_SOURCE 1)

################################################################################
# NJKWebViewProgress.
if (IS_IOS)
  get_download_target(NJK_WEB_VIEW_PROGRESS DOWNLOAD_TARGET)
  add_external_project(
    ${DOWNLOAD_TARGET}
    PREFIX ${NJK_WEB_VIEW_PROGRESS_PREFIX}
    DOWNLOAD_COMMAND
        ${GIT} clone --depth 1 git://github.com/QuentinFiard/NJKWebViewProgress
            ${DOWNLOAD_TARGET}
    CONFIGURE_COMMAND ${NOP}
    BUILD_COMMAND ${NOP}
    INSTALL_COMMAND
      cd <SOURCE_DIR> &&
      ${CMAKE_COMMAND} -E make_directory ${NJK_WEB_VIEW_PROGRESS_PREFIX}/include &&
      find NJKWebViewProgress -name "*.h" |
      cpio -dp ${NJK_WEB_VIEW_PROGRESS_PREFIX}/include)
  set(INSTALL_DIR ${NJK_WEB_VIEW_PROGRESS_PREFIX})
  get_download_source_dir(NJK_WEB_VIEW_PROGRESS SOURCE_DIR)
  set(SOURCE_DIR ${SOURCE_DIR}/NJKWebViewProgress)
  set(SRCS
      ${SOURCE_DIR}/NJKWebViewProgress.h
      ${SOURCE_DIR}/NJKWebViewProgress.m
      ${SOURCE_DIR}/NJKWebViewProgressView.h
      ${SOURCE_DIR}/NJKWebViewProgressView.m)
  set_source_files_properties(${SRCS} PROPERTIES GENERATED TRUE)
  add_custom_command(OUTPUT ${SRCS} COMMAND echo "")
  objc_library(${NJK_WEB_VIEW_PROGRESS_TARGET} ${SRCS})
  link_framework(${NJK_WEB_VIEW_PROGRESS_TARGET} UIKit)
  set_target_properties(
      ${NJK_WEB_VIEW_PROGRESS_TARGET} PROPERTIES
      ARCHIVE_OUTPUT_DIRECTORY ${INSTALL_DIR}/lib
      LIBRARY_OUTPUT_DIRECTORY ${INSTALL_DIR}/lib
      OUTPUT_NAME njk_web_view_progress)
  add_target_dependencies(NJK_WEB_VIEW_PROGRESS ${DOWNLOAD_TARGET})
endif ()

################################################################################
# NTP.
add_external_project(
  ${NTP_TARGET}
  PREFIX ${NTP_PREFIX}
  DOWNLOAD_DIR ${NTP_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O ntp-4.2.6p5.tar.gz http://www.eecis.udel.edu/~ntp/ntp_spool/ntp4/ntp-4.2/ntp-4.2.6p5.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/ntp-4.2.6p5.tar.gz.sig
          ntp-4.2.6p5.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${NTP_PREFIX}/download/ntp-4.2.6p5.tar.gz
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=/usr/local/ntp
  BUILD_COMMAND make
  INSTALL_COMMAND
      echo "This will install NTP in /usr/local/ntp on you server." &&
      sudo make install &&
      sudo ${CMAKE_COMMAND} -E make_directory /usr/local/ntp/logs)

################################################################################
# OpenCV.
set(OPENCV_SHARED_LINKER_FLAGS
    "-L${OPENCV_PREFIX}/src/${OPENCV_TARGET}-build/lib\
     ${CMAKE_SHARED_LINKER_FLAGS}")
set(OPENCV_EXE_LINKER_FLAGS
    "-L${OPENCV_PREFIX}/src/${OPENCV_TARGET}-build/lib\
     ${CMAKE_EXE_LINKER_FLAGS}")
set(OPENCV_CXX_FLAGS "${CMAKE_CXX_FLAGS_WITH_ARCHS} -Wno-c++11-narrowing")
set(OPENCV_CMAKE_ARGS
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}
    -DCMAKE_BUILD_TYPE=RELEASE
    -DENABLE_OMIT_FRAME_POINTER=ON
    -DENABLE_FAST_MATH=ON
    -DWITH_CUDA=OFF
    -DWITH_EIGEN=ON
    -DEIGEN_ROOT=${EIGEN_PREFIX}
    -DCMAKE_PREFIX_PATH=${TBB_PREFIX}
    -DEIGEN_INCLUDE_PATH=${EIGEN_INCLUDE_PATH}
    -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
    -DCMAKE_CXX_FLAGS=${OPENCV_CXX_FLAGS}
    -DCMAKE_SHARED_LINKER_FLAGS=${OPENCV_SHARED_LINKER_FLAGS}
    -DCMAKE_EXE_LINKER_FLAGS=${OPENCV_EXE_LINKER_FLAGS}
    -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
    -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
    -DCMAKE_INSTALL_PREFIX=${OPENCV_PREFIX})
if (NOT IOS_BUILD)
  set(OPENCV_CMAKE_ARGS ${OPENCV_CMAKE_ARGS}
      -DENABLE_SSE=ON
      -DENABLE_SSE2=ON
      -DENABLE_SSE3=ON
      -DENABLE_SSSE3=ON
      -DENABLE_SSE41=ON
      -DENABLE_SSE42=ON
      -DENABLE_AVX=OFF
      -DENABLE_NEON=ON
      -DWITH_TBB=ON
      -DTBB_INCLUDE_DIRS=${TBB_PREFIX}/include)
  set(OPENCV_CXX_FLAGS
      "-D TBB_IMPLEMENT_CPP0X=0 -I${TBB_PREFIX}/include ${OPENCV_CXX_FLAGS}")
else ()
  set(OPENCV_CMAKE_ARGS ${OPENCV_CMAKE_ARGS}
      -DWITH_OPENCL=OFF
      -DWITH_TBB=OFF)
endif ()
add_external_project(
  ${OPENCV_TARGET}
  PREFIX ${OPENCV_PREFIX}
  DOWNLOAD_COMMAND
    ${GIT} clone --depth 1 git://github.com/Itseez/opencv.git ${OPENCV_TARGET}
  CMAKE_ARGS ${OPENCV_CMAKE_ARGS})
add_install_name_step(OPENCV)
add_target_dependencies(OPENCV ${EIGEN_TARGET})
# add_target_dependencies(OPENCV ${GCC_TARGET})
add_target_dependencies(OPENCV ${TBB_PREFIX})

################################################################################
# OpenMP.
add_external_project(
  ${OPENMP_TARGET}
  PREFIX ${OPENMP_PREFIX}
  DOWNLOAD_DIR ${OPENMP_PREFIX}/download
  DOWNLOAD_COMMAND
      ${SVN} export --force http://llvm.org/svn/llvm-project/openmp/trunk openmp &&
      rm -rf <SOURCE_DIR> &&
      mv openmp/runtime <SOURCE_DIR>
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND
      PATH=${GCC_PREFIX}/bin:$ENV{PATH}
          LIB_GCC=${GCC_PREFIX}/lib/libgcc_s.1${CMAKE_SHARED_LIBRARY_SUFFIX}
          make compiler=gcc
  INSTALL_COMMAND
      ${CMAKE_COMMAND} -E make_directory ${OPENMP_PREFIX}/lib &&
      cp -rf exports/common/include ${OPENMP_PREFIX} &&
      find exports -name "*${CMAKE_SHARED_LIBRARY_SUFFIX}" |
      xargs -I{} cp "{}" ${OPENMP_PREFIX}/lib
  PATCH_COMMAND
      patch -Np0 < ${THIRD_PARTY_SOURCE_DIR}/openmp.patch
  BUILD_IN_SOURCE 1)
add_install_name_step(OPENMP)
set(OPENMP_COMPILE_FLAG "-fopenmp")
add_target_dependencies(OPENMP ${GCC_TARGET})

################################################################################
# OpenMPI.
set(OPENMPI_C_FLAGS "${CMAKE_C_FLAGS_WITH_ARCHS} ${LINKER_AS_COMPILER_FLAGS}")
set(OPENMPI_CXX_FLAGS "${CMAKE_CXX_FLAGS_WITH_ARCHS} ${LINKER_AS_COMPILER_FLAGS}")
add_external_project(
  ${OPENMPI_TARGET}
  PREFIX ${OPENMPI_PREFIX}
  DOWNLOAD_DIR ${OPENMPI_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O openmpi-1.8.1.tar.bz2 http://www.open-mpi.org/software/ompi/v1.8/downloads/openmpi-1.8.1.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/openmpi-1.8.1.tar.bz2.sig
          openmpi-1.8.1.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${OPENMPI_PREFIX}/download/openmpi-1.8.1.tar.bz2
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${OPENMPI_PREFIX}
      CC=${CMAKE_C_COMPILER}
      CXX=${CMAKE_CXX_COMPILER}
      CFLAGS=${OPENMPI_C_FLAGS}
      CXXFLAGS=${OPENMPI_CXX_FLAGS}
      ${CONFIGURE_LIB_TYPE}
      --enable-mpi-thread-multiple)

################################################################################
# OpenSSL.
set(OPENSSL_FLAGS enable-gmp -DOPENSSL_USE_GMP -I${GMP_PREFIX}/include)
foreach (FLAG ${third_party.gmp})
  set(OPENSSL_FLAGS "${OPENSSL_FLAGS} -Wl,${FLAG}")
endforeach ()
if (IOS_BUILD)
  set(DEFAULT_CONFIGURE_COMMAND
          <SOURCE_DIR>/Configure iphoneos-cross
          ${CMAKE_C_FLAGS} ${LINKER_AS_COMPILER_FLAGS} ${OPENSSL_FLAGS})

  list(GET CMAKE_OSX_ARCHITECTURES 0 FIRST_ARCH)
  # No build command in target, see below for build steps by architecture.
  add_external_project(
    ${OPENSSL_TARGET}
    PREFIX ${OPENSSL_PREFIX}
    DOWNLOAD_DIR ${OPENSSL_PREFIX}/download
    DOWNLOAD_COMMAND
        wget -O openssl-1.0.1g.tar.gz https://www.openssl.org/source/openssl-1.0.1g.tar.gz &&
        gpg --verify ${THIRD_PARTY_SOURCE_DIR}/openssl-1.0.1g.tar.gz.asc
            openssl-1.0.1g.tar.gz &&
        cd <SOURCE_DIR> &&
        tar --strip-components 1 -xvf
            ${OPENSSL_PREFIX}/download/openssl-1.0.1g.tar.gz
    CONFIGURE_COMMAND ${NOP}
    BUILD_COMMAND ${NOP}
    INSTALL_COMMAND
        ln -sf ${OPENSSL_PREFIX}/${FIRST_ARCH}/include
            ${OPENSSL_PREFIX}/${FIRST_ARCH}/ssl ${OPENSSL_PREFIX})

  set(LAST_STEP configure)
  foreach(ARCH ${CMAKE_OSX_ARCHITECTURES})
    set(STEP "${ARCH}_create_dirs")
    set(SOURCE_DIR ${OPENSSL_PREFIX}/${ARCH}/src)
    add_external_project_step(${OPENSSL_TARGET} ${STEP}
      COMMAND ${CMAKE_COMMAND} -E make_directory ${OPENSSL_PREFIX}/${ARCH} &&
          cp -rf <SOURCE_DIR> ${SOURCE_DIR}
      DEPENDEES ${LAST_STEP})
    set(LAST_STEP ${STEP})
    set(CONFIGURE_COMMAND ${DEFAULT_CONFIGURE_COMMAND}
            --prefix=${OPENSSL_PREFIX}/${ARCH} "-arch ${ARCH}")
    set(STEP "${ARCH}_configure")
    add_external_project_step(${OPENSSL_TARGET} ${STEP}
      COMMAND ${CONFIGURE_COMMAND}
      DEPENDEES ${LAST_STEP}
      WORKING_DIRECTORY ${SOURCE_DIR})
    set(LAST_STEP ${STEP})
    set(STEP "${ARCH}_build")
    add_external_project_step(${OPENSSL_TARGET} ${STEP}
      COMMAND make
      DEPENDEES ${LAST_STEP}
      WORKING_DIRECTORY ${SOURCE_DIR})
    set(LAST_STEP ${STEP})
    set(STEP "${ARCH}_install")
    add_external_project_step(${OPENSSL_TARGET} ${STEP}
      COMMAND make install
      DEPENDEES ${LAST_STEP}
      DEPENDERS install
      WORKING_DIRECTORY ${SOURCE_DIR})
    set(LAST_STEP ${STEP})
  endforeach ()
  set(MERGE_COMMAND ${CREATE_FAT_LIBS} ${CMAKE_SHARED_LIBRARY_SUFFIX}
          ${CMAKE_STATIC_LIBRARY_SUFFIX} ${OPENSSL_PREFIX}/lib)
  foreach(ARCH ${CMAKE_OSX_ARCHITECTURES})
    set(MERGE_COMMAND ${MERGE_COMMAND} ${OPENSSL_PREFIX}/${ARCH}/lib)
  endforeach ()
  set(STEP "create_fat_libs")
  add_external_project_step(${OPENSSL_TARGET} ${STEP}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${OPENSSL_PREFIX}/lib &&
        ${MERGE_COMMAND}
    DEPENDEES ${LAST_STEP}
    DEPENDS ${CREATE_FAT_LIBS})
else ()
  if (IOS_SIMULATOR_BUILD)
    set(CONFIGURE_COMMAND
            <SOURCE_DIR>/Configure BSD-generic32 --prefix=${OPENSSL_PREFIX}
            ${CMAKE_C_FLAGS_WITH_ARCHS} "-Wl,${CMAKE_SHARED_LINKER_FLAGS}"
            ${OPENSSL_FLAGS})
  else ()
    set(CONFIGURE_COMMAND <SOURCE_DIR>/Configure darwin64-x86_64-cc
            ${CMAKE_C_FLAGS} --prefix=${OPENSSL_PREFIX} zlib-dynamic
            ${OPENSSL_FLAGS})
  endif ()
  if (BUILD_SHARED_LIBS)
    set(CONFIGURE_COMMAND ${CONFIGURE_COMMAND} shared)
  endif ()
  add_external_project(
    ${OPENSSL_TARGET}
    PREFIX ${OPENSSL_PREFIX}
    DOWNLOAD_DIR ${OPENSSL_PREFIX}/download
    DOWNLOAD_COMMAND
        wget -O openssl-1.0.1g.tar.gz http://www.openssl.org/source/openssl-1.0.1g.tar.gz &&
        gpg --verify ${THIRD_PARTY_SOURCE_DIR}/openssl-1.0.1g.tar.gz.asc
            openssl-1.0.1g.tar.gz &&
        cd <SOURCE_DIR> &&
        tar --strip-components 1 -xvf
            ${OPENSSL_PREFIX}/download/openssl-1.0.1g.tar.gz
    CONFIGURE_COMMAND ${CONFIGURE_COMMAND}
    BUILD_IN_SOURCE 1)
endif ()
add_target_dependencies(OPENSSL ${GMP_TARGET})

################################################################################
# pango.
add_external_project(
  ${PANGO_TARGET}
  PREFIX ${PANGO_PREFIX}
  DOWNLOAD_DIR ${PANGO_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O pango-1.36.3.tar.xz http://ftp.gnome.org/pub/gnome/sources/pango/1.36/pango-1.36.3.tar.xz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/pango-1.36.3.tar.xz.sig
          pango-1.36.3.tar.xz &&
      cd <SOURCE_DIR> &&
      ${GNUTAR} --strip-components 1 -xvJf
          ${PANGO_PREFIX}/download/pango-1.36.3.tar.xz
  CONFIGURE_COMMAND echo "\
      <SOURCE_DIR>/configure --prefix=${PANGO_PREFIX} ${HOST} ${SYSROOT}\
      CC=${CMAKE_C_COMPILER}\
      CXX=${CMAKE_CXX_COMPILER} CFLAGS=\"${CMAKE_C_FLAGS_WITH_ARCHS}\"\
      CXXFLAGS=\"${CMAKE_CXX_FLAGS_WITH_ARCHS}\"\
      LDFLAGS=\"${CMAKE_SHARED_LINKER_FLAGS}\"\
      ${CONFIGURE_LIB_TYPE_STR}\
      --disable-Bsymbolic\
      PKG_CONFIG_PATH=\"${CAIRO_PREFIX}/lib/pkgconfig:${GLIB_PREFIX}/lib/pkgconfig:${PIXMAN_PREFIX}/lib/pkgconfig:${LIBPNG_PREFIX}/lib/pkgconfig\"" | sh)
add_target_dependencies(PANGO ${CAIRO_TARGET})
add_target_dependencies(PANGO ${GNUTAR_TARGET})
add_target_dependencies(PANGO ${GLIB_TARGET})
add_target_dependencies(PANGO ${LIBPNG_TARGET})
add_target_dependencies(PANGO ${PIXMAN_TARGET})

################################################################################
# papi.
set(PAPI_C_FLAGS "-I${OPENMP_PREFIX}/include")
set(PAPI_LINKER_FLAGS)
foreach (FLAG ${third_party.openmp})
  set(PAPI_LINKER_FLAGS "${PAPI_LINKER_FLAGS} ${FLAG}")
endforeach ()
add_external_project(
  ${PAPI_TARGET}
  PREFIX ${PAPI_PREFIX}
  DOWNLOAD_DIR ${PAPI_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O papi-5.3.0.tar.gz http://icl.cs.utk.edu/projects/papi/downloads/papi-5.3.0.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/papi-5.3.0.tar.gz.sig
          papi-5.3.0.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 2 -xvf
          ${PAPI_PREFIX}/download/papi-5.3.0.tar.gz papi-5.3.0/src
  CONFIGURE_COMMAND CC=${GCC_C_COMPILER}
          CXX=${GCC_CXX_COMPILER} CFLAGS=${PAPI_C_FLAGS}
          LDFLAGS=${PAPI_LINKER_FLAGS}
          <SOURCE_DIR>/configure --prefix=${PAPI_PREFIX} ${HOST} ${SYSROOT}
          ${CONFIGURE_LIB_TYPE}
  BUILD_IN_SOURCE 1)
add_target_dependencies(PAPI ${GCC_TARGET})
add_target_dependencies(PAPI ${OPENMP_TARGET})

################################################################################
# pcre.
add_external_project(
  ${PCRE_TARGET}
  PREFIX ${PCRE_PREFIX}
  DOWNLOAD_DIR ${PCRE_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O pcre-8.33.tar.bz2 ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.33.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/pcre-8.33.tar.bz2.sig
          pcre-8.33.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${PCRE_PREFIX}/download/pcre-8.33.tar.bz2
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${PCRE_PREFIX} --enable-jit)
add_install_name_step(PCRE)

################################################################################
# PHP.
set(PHP_CPPFLAGS "-I${APR_PREFIX}/include -I${APR_PREFIX}/include/apr-1")
add_external_project(
  ${PHP_TARGET}
  PREFIX ${PHP_PREFIX}
  DOWNLOAD_DIR ${PHP_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O php-5.5.6.tar.bz2 http://www.php.net/get/php-5.5.6.tar.bz2/from/this/mirror &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/php-5.5.6.tar.bz2.sig
          php-5.5.6.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${PHP_PREFIX}/download/php-5.5.6.tar.bz2
  PATCH_COMMAND
      patch -Np0 < ${THIRD_PARTY_SOURCE_DIR}/php.patch
  CONFIGURE_COMMAND <SOURCE_DIR>/configure
      --prefix=/usr/local/php/
      --enable-bcmath
      --enable-calendar
      --enable-cli
      --enable-dba
      --enable-exif
      --enable-ftp
      --enable-gd-native-ttf
      --enable-intl
      --enable-mbregex
      --enable-mbstring
      --enable-shmop
      --enable-soap
      --enable-sockets
      --enable-sysvmsg
      --enable-sysvsem
      --enable-sysvshm
      --enable-wddx
      --enable-zip
      --with-apxs2=/usr/local/apache/httpd/bin/apxs
      --with-bz2=${BZIP2_PREFIX}
      --with-config-file-path=/usr/local/php/etc/
      --with-curl=${LIBCURL_PREFIX}
      --with-freetype-dir=${FREETYPE_PREFIX}
      --with-gd
      --with-iconv=${LIBICONV_PREFIX}
      --with-iconv-dir=${LIBICONV_PREFIX}
      --with-icu-dir=${ICU_PREFIX}
      --with-imap-ssl
      --with-imap=${IMAP_2007F_PREFIX}
      --with-jpeg-dir=${LIBJPG_PREFIX}
      --with-kerberos
      --with-kerberos=/usr
      --with-ldap-sasl=${LDAP_SASL_PREFIX}
      --with-ldap=${LDAP_PREFIX}
      --with-libxml-dir=/usr
      --with-mcrypt=${LIBMCRYPT_PREFIX}
      --with-mysql-sock=/usr/local/mysql/data/mysql.sock
      --with-mysql=mysqlnd
      --with-mysqli=mysqlnd
      --with-openssl=${OPENSSL_PREFIX}
      --with-pcre-regex
      --with-pdo-mysql=mysqlnd
      --with-png-dir=${LIBPNG_PREFIX}
      --with-readline=${READLINE_PREFIX}
      --with-snmp=/usr
      # --with-tidy
      --with-xmlrpc
      --with-xsl=/usr
      --with-zlib=${ZLIB_PREFIX}
      --without-pear
      CPPFLAGS=${PHP_CPPFLAGS}
  BUILD_COMMAND make
  INSTALL_COMMAND
      echo "This will install PHP in /usr/local/php." &&
      sudo make install)
add_target_dependencies(PHP ${APR_TARGET})
add_target_dependencies(PHP ${APR_UTIL_TARGET})
add_target_dependencies(PHP ${BZIP2_TARGET})
add_target_dependencies(PHP ${FREETYPE_TARGET})
add_target_dependencies(PHP ${ICU_TARGET})
add_target_dependencies(PHP ${IMAP_2007F_TARGET})
add_target_dependencies(PHP ${LDAP_TARGET})
add_target_dependencies(PHP ${LDAP_SASL_TARGET})
add_target_dependencies(PHP ${LIBCURL_TARGET})
add_target_dependencies(PHP ${LIBICONV_TARGET})
add_target_dependencies(PHP ${LIBJPG_TARGET})
add_target_dependencies(PHP ${LIBMCRYPT_TARGET})
add_target_dependencies(PHP ${LIBPNG_TARGET})
add_target_dependencies(PHP ${OPENSSL_TARGET})
add_target_dependencies(PHP ${READLINE_TARGET})
add_target_dependencies(PHP ${ZLIB_TARGET})

################################################################################
# pixman.
add_external_project(
  ${PIXMAN_TARGET}
  PREFIX ${PIXMAN_PREFIX}
  DOWNLOAD_DIR ${PIXMAN_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O pixman-0.32.4.tar.gz http://cairographics.org/releases/pixman-0.32.4.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/pixman-0.32.4.tar.gz.sig
          pixman-0.32.4.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${PIXMAN_PREFIX}/download/pixman-0.32.4.tar.gz
  PATCH_COMMAND
      patch -p0 < ${THIRD_PARTY_SOURCE_DIR}/pixman.patch
  CONFIGURE_COMMAND echo "\
      cd <SOURCE_DIR> &&\
      aclocal &&\
      automake --add-missing$<SEMICOLON>\
      cd <BINARY_DIR> &&\
      <SOURCE_DIR>/configure --prefix=${PIXMAN_PREFIX} ${HOST}\
      ${SYSROOT}\
      CC=${CMAKE_C_COMPILER}\
      CXX=${CMAKE_CXX_COMPILER} CFLAGS=\"${CMAKE_C_FLAGS_WITH_ARCHS}\"\
      CXXFLAGS=\"${CMAKE_CXX_FLAGS_WITH_ARCHS}\"\
      LDFLAGS=\"${CMAKE_SHARED_LINKER_FLAGS}\"\
      ${CONFIGURE_LIB_TYPE_STR}\
      PKG_CONFIG_PATH=${LIBPNG_PREFIX}/lib/pkgconfig" | sh)
add_target_dependencies(PIXMAN ${LIBPNG_TARGET})

################################################################################
# pkg-config.
add_external_project(
  ${PKG_CONFIG_TARGET}
  PREFIX ${PKG_CONFIG_PREFIX}
  DOWNLOAD_DIR ${PKG_CONFIG_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O pkg-config-0.28.tar.gz http://pkgconfig.freedesktop.org/releases/pkg-config-0.28.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/pkg-config-0.28.tar.gz.sig
          pkg-config-0.28.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${PKG_CONFIG_PREFIX}/download/pkg-config-0.28.tar.gz
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${PKG_CONFIG_PREFIX})

################################################################################
# PrettyKit.
get_download_target(PRETTY_KIT DOWNLOAD_TARGET)
add_external_project(
  ${DOWNLOAD_TARGET}
  PREFIX ${PRETTY_KIT_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/QuentinFiard/PrettyKit.git
          ${DOWNLOAD_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND
    cd <SOURCE_DIR> &&
    ${CMAKE_COMMAND} -E make_directory ${PRETTY_KIT_PREFIX}/include &&
    find PrettyKit -name "*.h" |
    cpio -dp ${PRETTY_KIT_PREFIX}/include)
set(INSTALL_DIR ${PRETTY_KIT_PREFIX})
get_download_source_dir(PRETTY_KIT SOURCE_DIR)
set(SOURCE_DIR ${SOURCE_DIR}/PrettyKit)
set(SRCS
    ${SOURCE_DIR}/Cells/PrettyCustomViewTableViewCell.m
    ${SOURCE_DIR}/Cells/PrettyGridTableViewCell.m
    ${SOURCE_DIR}/Cells/PrettySegmentedControlTableViewCell.m
    ${SOURCE_DIR}/Cells/PrettyTableViewCell.m
    ${SOURCE_DIR}/PrettyDrawing.m
    ${SOURCE_DIR}/PrettyNavigationBar.m
    ${SOURCE_DIR}/PrettyShadowPlainTableview.m
    ${SOURCE_DIR}/PrettyTabBar.m
    ${SOURCE_DIR}/PrettyToolbar.m)
set_source_files_properties(${SRCS} PROPERTIES GENERATED TRUE)
objc_library(${PRETTY_KIT_TARGET} ${SRCS})
set_target_properties(
    ${PRETTY_KIT_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${INSTALL_DIR}/lib
    LIBRARY_OUTPUT_DIRECTORY ${INSTALL_DIR}/lib
    COMPILE_FLAGS -fno-objc-arc
    OUTPUT_NAME pretty_kit)
target_include_directories(${PRETTY_KIT_TARGET} PUBLIC ${SOURCE_DIR})
add_target_dependencies(PRETTY_KIT ${DOWNLOAD_TARGET})

################################################################################
# protobuf - Google's Protocol Buffers library.
add_external_project(
  ${PROTOBUF_TARGET}
  PREFIX ${PROTOBUF_PREFIX}
  DOWNLOAD_COMMAND
      ${SVN} export --force http://protobuf.googlecode.com/svn/trunk/ ${PROTOBUF_TARGET}
  CONFIGURE_COMMAND
      ./autogen.sh &&
      ./configure --prefix=${PROTOBUF_PREFIX} ${HOST} ${SYSROOT}
          CC=${CMAKE_C_COMPILER}
          CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
          CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
          LDFLAGS=-Wc,${CMAKE_SHARED_LINKER_FLAGS}
          --with-protoc=${PROTOBUF_PROTOC_EXECUTABLE}
          ${CONFIGURE_LIB_TYPE}
  BUILD_IN_SOURCE 1)
  add_target_dependencies(PROTOBUF ${PROTOC_TARGET})
  add_target_dependencies(PROTOBUF ${ZLIB_TARGET})
if (PYTHON_SUPPORTED)
  add_external_project_step(${PROTOBUF_TARGET} build_python_runtime
    COMMAND /usr/bin/env python setup.py build
    DEPENDEES build
    DEPENDERS install
    WORKING_DIRECTORY <SOURCE_DIR>/python)
  add_external_project_step(${PROTOBUF_TARGET} install_python_runtime
    COMMAND /usr/bin/env python setup.py install
    DEPENDEES install
    WORKING_DIRECTORY <SOURCE_DIR>/python)
  add_target_dependencies(PROTOBUF ${VIRTUALENV_TARGET})
endif ()

################################################################################
# protoc - Google's Protocol Buffers compiler.
add_external_project(
  ${PROTOC_TARGET}
  PREFIX ${PROTOC_PREFIX}
  DOWNLOAD_COMMAND
      ${SVN} export --force http://protobuf.googlecode.com/svn/trunk/ ${PROTOC_TARGET}
  CONFIGURE_COMMAND
      ./autogen.sh &&
      ./configure --prefix=${PROTOC_PREFIX}
  BUILD_IN_SOURCE 1)
# This is required for protobuf_generate_* rules.
set(PROTOBUF_PROTOC_EXECUTABLE ${PROTOC_PREFIX}/bin/protoc)

################################################################################
# proxy-libintl - Google's Protocol Buffers compiler.
get_download_target(PROXY_LIBINTL DOWNLOAD_TARGET)
add_external_project(
  ${DOWNLOAD_TARGET}
  PREFIX ${PROXY_LIBINTL_PREFIX}
  SOURCE_DIR ${PROXY_LIBINTL_PREFIX}/src/${PROXY_LIBINTL_TARGET}
  DOWNLOAD_COMMAND
      ${SVN} export --force https://github.com/frida/glib/trunk/proxy-libintl ${PROXY_LIBINTL_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND
      mkdir -p <INSTALL_DIR>/include &&
      cp -f <SOURCE_DIR>/libintl.h <INSTALL_DIR>/include)
get_download_source_dir(PROXY_LIBINTL SOURCE_DIR)
set(PROXY_LIBINTL_SRCS ${PROXY_LIBINTL_PREFIX}/src/${PROXY_LIBINTL_TARGET}/libintl.c)
set_source_files_properties(${PROXY_LIBINTL_SRCS} PROPERTIES GENERATED TRUE)
cc_library(${PROXY_LIBINTL_TARGET} ${PROXY_LIBINTL_SRCS})
set_target_properties(
    ${PROXY_LIBINTL_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${PROXY_LIBINTL_PREFIX}/lib
    LIBRARY_OUTPUT_DIRECTORY ${PROXY_LIBINTL_PREFIX}/lib
    OUTPUT_NAME intl)
target_include_directories(
    ${PROXY_LIBINTL_TARGET} PUBLIC ${PROXY_LIBINTL_PREFIX}/include)
add_target_dependencies(PROXY_LIBINTL ${DOWNLOAD_TARGET})

################################################################################
# Readline.
add_external_project(
  ${READLINE_TARGET}
  PREFIX ${READLINE_PREFIX}
  DOWNLOAD_DIR ${READLINE_PREFIX}/download
  DOWNLOAD_COMMAND
      wget ftp://ftp.cwru.edu/pub/bash/readline-6.2.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/readline-6.2.tar.gz.sig
          readline-6.2.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${READLINE_PREFIX}/download/readline-6.2.tar.gz
  PATCH_COMMAND
      patch -Np0 < ${THIRD_PARTY_SOURCE_DIR}/readline.patch
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${READLINE_PREFIX}
      CC=${CMAKE_C_COMPILER}
      CXX=${CMAKE_CXX_COMPILER}
      CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      LDFLAGS=${LDFLAGS_WITH_ARCHS}
      ${CONFIGURE_LIB_TYPE})

################################################################################
# Shark.
set(SHARK_C_FLAGS "-L${OPENMP_PREFIX}/lib -DSHARK_USE_OPENMP -fopenmp -I${OPENMP_PREFIX}/include ${BOOST_C_FLAGS}")
set(SHARK_CXX_FLAGS "-L${OPENMP_PREFIX}/lib -DSHARK_USE_OPENMP -fopenmp -I${OPENMP_PREFIX}/include ${BOOST_CXX_FLAGS}")
set(SHARK_EXE_LINKER_FLAGS "-L${OPENMP_PREFIX}/lib ${CMAKE_EXE_LINKER_FLAGS}")
set(SHARK_SHARED_LINKER_FLAGS "-L${OPENMP_PREFIX}/lib ${CMAKE_SHARED_LINKER_FLAGS}")
add_external_project(
  ${SHARK_TARGET}
  PREFIX ${SHARK_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/QuentinFiard/shark.git ${SHARK_TARGET}
  CONFIGURE_COMMAND
      BOOST_ROOT=${BOOST_PREFIX} ${CMAKE_COMMAND} <SOURCE_DIR>
          -DOPT_MAKE_TESTS=OFF
          -DOPT_DYNAMIC_LIBRARY=${BUILD_SHARED_LIBS}
          -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
          -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
          -DCMAKE_BUILD_TYPE=RELEASE
          -DCMAKE_C_FLAGS=${SHARK_C_FLAGS}
          -DCMAKE_CXX_FLAGS=${SHARK_CXX_FLAGS}
          -DCMAKE_EXE_LINKER_FLAGS=${SHARK_EXE_LINKER_FLAGS}
          -DCMAKE_SHARED_LINKER_FLAGS=${SHARK_SHARED_LINKER_FLAGS}
          -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
          -DCMAKE_OSX_ARCHITECTURES=${ARCHS}
          -DCMAKE_INSTALL_PREFIX=${SHARK_PREFIX})
add_install_name_step(SHARK)
add_definitions(-DSHARK_USE_OPENMP)

# Adds dependencies.
add_target_dependencies(SHARK ${BOOST_TARGET})
add_target_dependencies(SHARK ${OPENMP_TARGET})

################################################################################
# Sqlite3.
add_external_project(
  ${SQLITE3_TARGET}
  PREFIX ${SQLITE3_PREFIX}
  DOWNLOAD_DIR ${SQLITE3_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O sqlite-autoconf-3080403.tar.gz http://www.sqlite.org/2014/sqlite-autoconf-3080403.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/sqlite-autoconf-3080403.tar.gz.sig
          sqlite-autoconf-3080403.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${SQLITE3_PREFIX}/download/sqlite-autoconf-3080403.tar.gz
  CONFIGURE_COMMAND
      <SOURCE_DIR>/configure --prefix=${SQLITE3_PREFIX} ${HOST} ${SYSROOT}
      CC=${CMAKE_C_COMPILER}
      CXX=${CMAKE_CXX_COMPILER} CFLAGS=${CMAKE_C_FLAGS_WITH_ARCHS}
      CXXFLAGS=${CMAKE_CXX_FLAGS_WITH_ARCHS}
      LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
      ${CONFIGURE_LIB_TYPE})

################################################################################
# SSToolkit.
if (IS_IOS)
  add_external_project(
    ${SSTOOLKIT_TARGET}
    PREFIX ${SSTOOLKIT_PREFIX}
    DOWNLOAD_COMMAND
        ${GIT} clone --depth 1 git://github.com/soffes/sstoolkit.git
            ${SSTOOLKIT_TARGET}
    CONFIGURE_COMMAND ${NOP}
    BUILD_COMMAND
        xcodebuild -project <SOURCE_DIR>/SSToolkit.xcodeproj -sdk ${XCODE_SDK}
    INSTALL_COMMAND
        ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/lib &&
        cp -f build/Release-${XCODE_SDK}/libSSToolkit.a <INSTALL_DIR>/lib &&
        ditto SSToolkit <INSTALL_DIR>/include/SSToolkit
    BUILD_IN_SOURCE 1)
endif ()

################################################################################
# SWRevealViewController.
get_download_target(SW_REVEAL_VIEW_CONTROLLER DOWNLOAD_TARGET)
add_external_project(
  ${DOWNLOAD_TARGET}
  PREFIX ${SW_REVEAL_VIEW_CONTROLLER_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/John-Lluch/SWRevealViewController.git
          ${DOWNLOAD_TARGET}
  CONFIGURE_COMMAND echo ""
  BUILD_COMMAND echo ""
  INSTALL_COMMAND
    cd <SOURCE_DIR> &&
    ${CMAKE_COMMAND} -E make_directory ${SW_REVEAL_VIEW_CONTROLLER_PREFIX}/include &&
    find SWRevealViewController -name "*.h" |
    cpio -dp ${SW_REVEAL_VIEW_CONTROLLER_PREFIX}/include)
set(INSTALL_DIR ${SW_REVEAL_VIEW_CONTROLLER_PREFIX})
get_download_source_dir(SW_REVEAL_VIEW_CONTROLLER SOURCE_DIR)
set(SOURCE_DIR ${SOURCE_DIR}/SWRevealViewController)
set(SRCS ${SOURCE_DIR}/SWRevealViewController.h
    ${SOURCE_DIR}/SWRevealViewController.m)
set_source_files_properties(${SRCS} PROPERTIES GENERATED TRUE)
add_custom_command(OUTPUT ${SRCS} COMMAND echo "")
objc_library(${SW_REVEAL_VIEW_CONTROLLER_TARGET} ${SRCS})
set_target_properties(
    ${SW_REVEAL_VIEW_CONTROLLER_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${INSTALL_DIR}/lib
    LIBRARY_OUTPUT_DIRECTORY ${INSTALL_DIR}/lib
    OUTPUT_NAME sw_reveal_view_controller)
add_target_dependencies(SW_REVEAL_VIEW_CONTROLLER ${DOWNLOAD_TARGET})

################################################################################
# TBB.
add_external_project(
  ${TBB_TARGET}
  PREFIX ${TBB_PREFIX}
  DOWNLOAD_DIR ${TBB_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O tbb42_20131003oss_src.tgz https://www.threadingbuildingblocks.org/sites/default/files/software_releases/source/tbb42_20131003oss_src.tgz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/tbb42_20131003oss_src.tgz.sig
          tbb42_20131003oss_src.tgz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 2 -xvf
          ${TBB_PREFIX}/download/tbb42_20131003oss_src.tgz
  CONFIGURE_COMMAND ""
  BUILD_COMMAND
      make -j${PROCESSOR_COUNT} compiler=clang
          CFLAGS=${CMAKE_C_FLAGS} CXXFLAGS=${CMAKE_CXX_FLAGS}
          LDFLAGS=${CMAKE_SHARED_LINKER_FLAGS}
  INSTALL_COMMAND
      find include -name "*.h" | cpio -dp <INSTALL_DIR>
  PATCH_COMMAND
      patch -Np0 < ${THIRD_PARTY_SOURCE_DIR}/tbb.patch
  BUILD_IN_SOURCE 1)
add_external_project_step(${TBB_TARGET} install_libs
  COMMAND
      ${CMAKE_COMMAND} -E make_directory ${TBB_PREFIX}/lib &&
      find build -name "*${CMAKE_SHARED_LIBRARY_SUFFIX}" |
      xargs -I{} cp "{}" ${TBB_PREFIX}/lib
  DEPENDEES install
  WORKING_DIRECTORY <SOURCE_DIR>)
add_install_name_step(TBB)

################################################################################
# UIImage+animatedGif.
get_download_target(UIIMAGE_ANIMATED_GIF DOWNLOAD_TARGET)
add_external_project(
  ${DOWNLOAD_TARGET}
  PREFIX ${UIIMAGE_ANIMATED_GIF_PREFIX}
  SOURCE_DIR ${UIIMAGE_ANIMATED_GIF_PREFIX}/src/${UIIMAGE_ANIMATED_GIF_TARGET}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/mayoff/uiimage-from-animated-gif.git
          ${UIIMAGE_ANIMATED_GIF_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND
      mkdir -p <INSTALL_DIR>/include/UIImage+animatedGIF &&
      cp <SOURCE_DIR>/uiimage-from-animated-gif/UIImage+animatedGIF.h
          <INSTALL_DIR>/include/UIImage+animatedGIF)
get_download_source_dir(UIIMAGE_ANIMATED_GIF SOURCE_DIR)
set(SOURCE_DIR ${SOURCE_DIR}/uiimage-from-animated-gif)
set(UIIMAGE_ANIMATED_GIF_SRCS ${SOURCE_DIR}/UIImage+animatedGIF.m)
set_source_files_properties(
    ${UIIMAGE_ANIMATED_GIF_SRCS} PROPERTIES GENERATED TRUE)
objc_library(${UIIMAGE_ANIMATED_GIF_TARGET} ${UIIMAGE_ANIMATED_GIF_SRCS})
link_framework(${UIIMAGE_ANIMATED_GIF_TARGET} ImageIO)
set_target_properties(
    ${UIIMAGE_ANIMATED_GIF_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${UIIMAGE_ANIMATED_GIF_PREFIX}/lib
    LIBRARY_OUTPUT_DIRECTORY ${UIIMAGE_ANIMATED_GIF_PREFIX}/lib
    OUTPUT_NAME uiimage_animated_gif)
add_target_dependencies(UIIMAGE_ANIMATED_GIF ${DOWNLOAD_TARGET})

################################################################################
# UIAlertView+Blocks.
get_download_target(UIALERTVIEW_BLOCKS DOWNLOAD_TARGET)
add_external_project(
  ${DOWNLOAD_TARGET}
  PREFIX ${UIALERTVIEW_BLOCKS_PREFIX}
  DOWNLOAD_COMMAND
      ${GIT} clone --depth 1 git://github.com/jivadevoe/UIAlertView-Blocks.git
          ${DOWNLOAD_TARGET}
  CONFIGURE_COMMAND ${NOP}
  BUILD_COMMAND ${NOP}
  INSTALL_COMMAND
      cd <SOURCE_DIR> &&
      find . -name "*.h" | cpio -dp <INSTALL_DIR>/include/UIAlertView+Blocks)
get_download_source_dir(UIALERTVIEW_BLOCKS SOURCE_DIR)
set(UIALERTVIEW_BLOCKS_SRCS
    ${SOURCE_DIR}/RIButtonItem.m
    ${SOURCE_DIR}/UIActionSheet+Blocks.m
    ${SOURCE_DIR}/UIAlertView+Blocks.m)
set_source_files_properties(
    ${UIALERTVIEW_BLOCKS_SRCS} PROPERTIES GENERATED TRUE)
objc_library(${UIALERTVIEW_BLOCKS_TARGET} ${UIALERTVIEW_BLOCKS_SRCS})
link_framework(${UIALERTVIEW_BLOCKS_TARGET} UIKit)
set_target_properties(
    ${UIALERTVIEW_BLOCKS_TARGET} PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${UIALERTVIEW_BLOCKS_PREFIX}/lib
    LIBRARY_OUTPUT_DIRECTORY ${UIALERTVIEW_BLOCKS_PREFIX}/lib
    OUTPUT_NAME uialertview_blocks)
add_target_dependencies(UIALERTVIEW_BLOCKS ${DOWNLOAD_TARGET})

################################################################################
# virtualenv.
if (PYTHON_SUPPORTED)
  add_external_project(
    ${VIRTUALENV_TARGET}
    PREFIX ${VIRTUALENV_PREFIX}
    DOWNLOAD_DIR ${VIRTUALENV_PREFIX}/download
    DOWNLOAD_COMMAND
        wget -O virtualenv-1.9.1.tar.gz https://pypi.python.org/packages/source/v/virtualenv/virtualenv-1.9.1.tar.gz &&
        gpg --verify ${THIRD_PARTY_SOURCE_DIR}/virtualenv-1.9.1.tar.gz.sig
            virtualenv-1.9.1.tar.gz &&
        cd <SOURCE_DIR> &&
        tar --strip-components 1 -xvf
            ${VIRTUALENV_PREFIX}/download/virtualenv-1.9.1.tar.gz
    CONFIGURE_COMMAND
        ${CMAKE_COMMAND} -E make_directory ${VIRTUALENV_PREFIX}/lib/python
    BUILD_COMMAND python setup.py install --home=${VIRTUALENV_PREFIX}
    INSTALL_COMMAND
        cd ${VIRTUALENV_PREFIX} && ./bin/virtualenv env
    BUILD_IN_SOURCE 1)
  set(LINE "source ${CMAKE_CURRENT_LIST_DIR}/.profile")
  if ("$ENV{BUILD_3RD_PARTY_LIBRARIES}")
    add_custom_command(TARGET ${VIRTUALENV_TARGET} POST_BUILD
      COMMAND
          grep -q "${LINE}" $ENV{HOME}/.profile && exit 0 ||
          echo "\\033[31;1m***********************************************************\\nPlease add the following line to your .profile file\\n\\n${LINE}\\n***********************************************************\\n\\033[0m" &&
          exit 1
      VERBATIM)
  endif ()
endif ()

################################################################################
# xz.
add_external_project(
  ${XZ_TARGET}
  PREFIX ${XZ_PREFIX}
  DOWNLOAD_DIR ${XZ_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O xz-5.0.5.tar.bz2 http://tukaani.org/xz/xz-5.0.5.tar.bz2 &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/xz-5.0.5.tar.bz2.sig
          xz-5.0.5.tar.bz2 &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${XZ_PREFIX}/download/xz-5.0.5.tar.bz2
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${XZ_PREFIX}
  BUILD_COMMAND make
  INSTALL_COMMAND make install)

################################################################################
# zlib.
if (NOT BUILD_SHARED_LIBS)
  set(ZLIB_CONFIGURE_LIB_TYPE "--static")
endif ()
set(ZLIB_C_FLAGS "${CMAKE_C_FLAGS_WITH_ARCHS} ${LINKER_AS_COMPILER_FLAGS}")
set(CONFIGURE_COMMAND
        export CFLAGS=${ZLIB_C_FLAGS} &&
        <SOURCE_DIR>/configure
            --prefix=${ZLIB_PREFIX}
            --archs=${ARCHS_AS_FLAGS} ${ZLIB_CONFIGURE_LIB_TYPE})
add_external_project(
  ${ZLIB_TARGET}
  PREFIX ${ZLIB_PREFIX}
  DOWNLOAD_DIR ${ZLIB_PREFIX}/download
  DOWNLOAD_COMMAND
      wget -O zlib-1.2.8.tar.gz http://zlib.net/zlib-1.2.8.tar.gz &&
      gpg --verify ${THIRD_PARTY_SOURCE_DIR}/zlib-1.2.8.tar.gz.sig
          zlib-1.2.8.tar.gz &&
      cd <SOURCE_DIR> &&
      tar --strip-components 1 -xvf
          ${ZLIB_PREFIX}/download/zlib-1.2.8.tar.gz
  CONFIGURE_COMMAND ${CONFIGURE_COMMAND}
  BUILD_IN_SOURCE 1)


################################################################################
# Generative rules.
################################################################################
function(protobuf_generate_cc SRCS HDRS)
  if(NOT ARGN)
    message(SEND_ERROR
            "Error: protobuf_generate_cc called without any proto files")
    return()
  endif(NOT ARGN)

  set(${SRCS})
  set(${HDRS})
  foreach(FIL ${ARGN})
    get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
    get_filename_component(FIL_WE ${FIL} NAME_WE)

    list(APPEND ${SRCS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.pb.cc")
    list(APPEND ${HDRS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.pb.h")

    add_custom_command(
      OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.pb.cc"
             "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.pb.h"
      COMMAND  ${PROTOBUF_PROTOC_EXECUTABLE}
      ARGS --cpp_out ${PROJECT_BINARY_DIR}/src -I${PROTOBUF_PREFIX}/include
          -I${PROJECT_SOURCE_DIR}/src  ${ABS_FIL}
      DEPENDS ${PROTOBUF_TARGET} ${PROTOC_TARGET} ${ABS_FIL}
      COMMENT "Running C++ protocol buffer compiler on ${FIL}"
      VERBATIM)
  endforeach()

  set_source_files_properties(${${SRCS}} ${${HDRS}} PROPERTIES GENERATED TRUE)
  set(${SRCS} ${${SRCS}} PARENT_SCOPE)
  set(${HDRS} ${${HDRS}} PARENT_SCOPE)
endfunction()

function(protobuf_generate_java SRCS)
  if (NOT JAVA_SUPPORTED)
    return()
  endif ()
  if(NOT ARGN)
    message(SEND_ERROR
            "Error: protobuf_generate_java() called without any proto files")
    return()
  endif(NOT ARGN)

  set(${SRCS})
  foreach(FIL ${ARGN})
    get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
    get_filename_component(FIL_WE ${FIL} NAME_WE)
    underscores_to_camel_case(${FIL_WE} FIL_WE)

    set(SRC "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}Protos.java")
    list(APPEND ${SRCS} ${SRC})
    add_custom_command(
      OUTPUT ${SRC}
      COMMAND  ${PROTOBUF_PROTOC_EXECUTABLE}
      ARGS --java_out ${PROJECT_BINARY_DIR}/src -I${PROTOBUF_PREFIX}/include
          -I${PROJECT_SOURCE_DIR}/src  ${ABS_FIL}
      DEPENDS ${PROTOBUF_TARGET} ${PROTOC_TARGET} ${ABS_FIL}
      COMMENT "Running java protocol buffer compiler on ${FIL}"
      VERBATIM)
  endforeach()

  set_source_files_properties(${${SRCS}} PROPERTIES GENERATED TRUE)
  set(${SRCS} ${${SRCS}} PARENT_SCOPE)
endfunction()

function(protobuf_generate_py SRCS)
  if(NOT ARGN)
    message(SEND_ERROR
            "Error: protobuf_generate_py() called without any proto files")
    return()
  endif(NOT ARGN)

  set(${SRCS})
  foreach(FIL ${ARGN})
    get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
    get_filename_component(FIL_WE ${FIL} NAME_WE)

    list(APPEND ${SRCS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}_pb2.py")

    add_custom_command(
      OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}_pb2.py"
      COMMAND  ${PROTOBUF_PROTOC_EXECUTABLE}
      ARGS --python_out ${PROJECT_BINARY_DIR}/src -I${PROTOBUF_PREFIX}/include
          -I${PROJECT_SOURCE_DIR}/src  ${ABS_FIL}
      DEPENDS ${PROTOBUF_TARGET} ${PROTOC_TARGET} ${ABS_FIL}
      COMMENT "Running python protocol buffer compiler on ${FIL}"
      VERBATIM)
  endforeach()

  set_source_files_properties(${${SRCS}} PROPERTIES GENERATED TRUE)
  set(${SRCS} ${${SRCS}} PARENT_SCOPE)
endfunction()

function(flex_generate_scanner LEX SRC_ HDR_)
  get_filename_component(ABS_LEX ${LEX} ABSOLUTE)
  get_filename_component(LEX_WE ${LEX} NAME_WE)
  set(SRC "${CMAKE_CURRENT_BINARY_DIR}/${LEX_WE}.cc")
  set(HDR "${CMAKE_CURRENT_BINARY_DIR}/${LEX_WE}.h")
  add_custom_command(
      OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${LEX_WE}.cc"
             "${CMAKE_CURRENT_BINARY_DIR}/${LEX_WE}.h"
      COMMAND ${FLEX_EXECUTABLE}
      ARGS -v -o ${SRC} --header-file=${HDR} ${ABS_LEX}
      DEPENDS ${FLEX_TARGET} ${ABS_LEX}
      COMMENT "Running Flex++ on ${LEX}"
      VERBATIM)
  set_source_files_properties(${SRC} ${HDR} PROPERTIES GENERATED TRUE)
  set(${SRC_} ${SRC} PARENT_SCOPE)
  set(${HDR_} ${HDR} PARENT_SCOPE)
endfunction()

function(bison_generate_parser YAC SRC_ HDR_)
  get_filename_component(ABS_YAC ${YAC} ABSOLUTE)
  get_filename_component(YAC_WE ${YAC} NAME_WE)
  set(SRC "${CMAKE_CURRENT_BINARY_DIR}/${YAC_WE}.cc")
  set(HDR "${CMAKE_CURRENT_BINARY_DIR}/${YAC_WE}.h")
  add_custom_command(
      OUTPUT ${SRC}
             "${CMAKE_CURRENT_BINARY_DIR}/${YAC_WE}.hh"
      COMMAND  ${BISON_EXECUTABLE}
      ARGS -v -d -o ${SRC} ${ABS_YAC}
      DEPENDS ${BISON_TARGET} ${ABS_YAC}
      COMMENT "Running Bison on ${YAC}"
      VERBATIM)
  add_custom_command(
      OUTPUT ${HDR}
      COMMAND mv
      ARGS "${CMAKE_CURRENT_BINARY_DIR}/${YAC_WE}.hh" ${HDR}
      DEPENDS ${ABS_YAC}
      COMMENT "Moving header"
      VERBATIM)
  set_source_files_properties(${SRC} ${HDR} PROPERTIES GENERATED TRUE)
  set(${SRC_} ${SRC} PARENT_SCOPE)
  set(${HDR_} ${HDR} PARENT_SCOPE)
endfunction()

function (closure_library TARGET)
  set(SRCS)
  get_full_target(${TARGET} FULL_TARGET)
  foreach (SRC ${ARGN})
    set(OUT ${CMAKE_CURRENT_BINARY_DIR}/${SRC})
    set(TMP ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${SRC})
    set(SRC ${CMAKE_CURRENT_SOURCE_DIR}/${SRC})
    add_custom_command(
        OUTPUT ${OUT}
        COMMAND /usr/bin/env python ${CLOSURE_LIBRARY}/closure/bin/build/closurebuilder.py
        ARGS --root=${CLOSURE_LIBRARY} --root=${CMAKE_CURRENT_SOURCE_DIR}
            --namespace=${FULL_TARGET} --output_mode=compiled
            --compiler_jar=${CLOSURE_COMPILER_JAR}
            --compiler_flags=--compilation_level=ADVANCED_OPTIMIZATIONS
            > ${TMP} && mv ${TMP} ${OUT}
        DEPENDS ${CLOSURE_COMPILER_TARGET} ${CLOSURE_LIBRARY_TARGET} ${SRC}
        COMMENT "Compiling ${SRC} with Closure compiler"
        VERBATIM)
    list(APPEND SRCS ${OUT})
  endforeach ()
  add_custom_target(${FULL_TARGET} ALL SOURCES ${SRCS})
  set_target_properties(${FULL_TARGET} PROPERTIES TARGET_FILE ${SRCS})
endfunction ()

################################################################################
# Other functions.
################################################################################
function(use_openmp TARGET)
  add_cxxflags(${TARGET} ${OPENMP_COMPILE_FLAG})
  add_compile_defs(${TARGET} "USE_OPENMP")
endfunction(use_openmp)

################################################################################
# External dependency management.
################################################################################
include(${CMAKE_CURRENT_LIST_DIR}/third_party/maven_libraries.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/third_party/pip_libraries.cmake)
