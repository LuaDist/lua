# Copyright (C) 2007-2012 LuaDist.
# Created by Peter Drahoš, Peter Kapec
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

project ( lua C )
cmake_minimum_required ( VERSION 2.8 )
include ( cmake/dist.cmake )

## CONFIGURATION
# Default configuration (we assume POSIX by default)
set ( LUA_PATH "LUA_PATH" CACHE STRING "Environment variable to use as package.path." )
set ( LUA_CPATH "LUA_CPATH" CACHE STRING "Environment variable to use as package.cpath." )
set ( LUA_INIT "LUA_INIT" CACHE STRING "Environment variable for initial script." )

option ( LUA_ANSI "Use only ansi features." OFF )
option ( LUA_USE_RELATIVE_LOADLIB "Use modified loadlib.c with support for relative paths on posix systems." ON )
option ( LUA_COMPAT_ALL "Enable backwards compatibility options." ON )
set ( LUA_IDSIZE 60 CACHE NUMBER "gives the maximum size for the description of the source." )

#2DO: LUAI_* and LUAL_* settings, for now defaults are used.
set ( LUA_DIRSEP "/" )
set ( LUA_MODULE_SUFFIX ${CMAKE_SHARED_MODULE_SUFFIX} )
set ( LUA_LDIR ${INSTALL_LMOD} )
set ( LUA_CDIR ${INSTALL_CMOD} )

if ( LUA_USE_RELATIVE_LOADLIB )
  # This will set up relative paths to lib
  string ( REGEX REPLACE "[^!/]+" ".." LUA_DIR "!/${INSTALL_BIN}/" )
else ( )
  # Direct path to installation
  set ( LUA_DIR ${CMAKE_INSTALL_PREFIX} CACHE STRING "Destination from which modules will be resolved. See INSTALL_LMOD and INSTALL_CMOD." )
endif ( )

set ( LUA_PATH_DEFAULT "./?.lua;${LUA_DIR}${LUA_LDIR}/?.lua;${LUA_DIR}${LUA_LDIR}/?/init.lua" )
set ( LUA_CPATH_DEFAULT "./?${LUA_MODULE_SUFFIX};${LUA_DIR}${LUA_CDIR}/?${LUA_MODULE_SUFFIX};${LUA_DIR}${LUA_CDIR}/loadall${LUA_MODULE_SUFFIX}" )

if ( WIN32 AND NOT CYGWIN )
  # Windows systems
  option ( LUA_WIN "Windows specific build." ON )
  option ( LUA_BUILD_AS_DLL "Build Lua library as Dll." ON )
  # Paths (Double escapes needed)
  set ( LUA_DIRSEP "\\\\" ) string ( REPLACE " /" ${LUA_DIRSEP} LUA_DIR "${LUA_DIR}" )
  string ( REPLACE "/" ${LUA_DIRSEP} LUA_LDIR "${LUA_LDIR}" )
  string ( REPLACE "/" ${LUA_DIRSEP} LUA_CDIR "${LUA_CDIR}" )
  string ( REPLACE "/" ${LUA_DIRSEP} LUA_PATH_DEFAULT "${LUA_PATH_DEFAULT}" )
  string ( REPLACE "/" ${LUA_DIRSEP} LUA_CPATH_DEFAULT "${LUA_CPATH_DEFAULT}" )
else ( )
  # Posix systems (incl. Cygwin)
  option ( LUA_USE_POSIX "Use POSIX functionality." ON )
  option ( LUA_USE_DLOPEN "Use dynamic linker to load modules." ON )
  option ( LUA_USE_MKSTEMP "Use mkstep." ON )
  option ( LUA_USE_ISATTY "Use tty." ON )
  option ( LUA_USE_POPEN "Use popen." ON )
  option ( LUA_USE_ULONGJMP "Use ulongjmp" ON )
  option ( LUA_USE_STRTODHEX "assume 'strtod' handles hexa formats" ON )
  option ( LUA_USE_AFORMAT "assume 'printf' handles 'aA' specifiers" ON )
  option ( LUA_USE_LONGLONG "assume support for long long" ON )
endif ( )

## SETUP
# Optional libraries
find_package ( Readline )
if ( READLINE_FOUND )
  option ( LUA_USE_READLINE "Use readline in the Lua CLI." ON )
endif ( )

find_package ( Curses )
if ( CURSES_FOUND )
  option ( LUA_USE_CURSES "Use curses in the Lua CLI." ON )
endif ( )

# Setup needed variables and libraries
if ( LUA_USE_POSIX )
  # On POSIX Lua links to standard math library "m"
  list ( APPEND LIBS m )
endif ( )

if ( LUA_USE_DLOPEN )
  # Link to dynamic linker library "dl"
  list ( APPEND LIBS dl )
endif ( )

if ( LUA_USE_READLINE )
  # Add readline
  include_directories ( ${READLINE_INCLUDE_DIR} )
  list ( APPEND LIBS ${READLINE_LIBRARY} )
endif ( )

if ( LUA_USE_CURSES )
  # Add curses
  include_directories ( ${CURSES_INCLUDE_DIR} )
  list ( APPEND LIBS ${CURSES_LIBRARY} )
endif ( )

## SOURCES
# Generate luaconf.h
configure_file ( src/luaconf.h.in ${CMAKE_CURRENT_BINARY_DIR}/luaconf.h )

# Sources and headers
include_directories ( src ${CMAKE_CURRENT_BINARY_DIR} )
set ( SRC_CORE src/lapi.c src/lcode.c src/lctype.c src/ldebug.c src/ldo.c src/ldump.c 
  src/lfunc.c src/lgc.c src/llex.c src/lmem.c src/lobject.c src/lopcodes.c src/lparser.c 
  src/lstate.c src/lstring.c src/ltable.c src/ltm.c src/lundump.c src/lvm.c src/lzio.c )
set ( SRC_LIB src/lauxlib.c src/lbaselib.c src/lbitlib.c src/lcorolib.c src/ldblib.c 
  src/liolib.c src/lmathlib.c src/loslib.c src/lstrlib.c src/ltablib.c src/linit.c )
set ( SRC_LUA src/lua.c )
set ( SRC_LUAC src/luac.c )

if ( LUA_USE_RELATIVE_LOADLIB )
  # Use modified loadlib
  list ( APPEND SRC_LIB src/loadlib_rel.c )
else ( )
  list ( APPEND SRC_LIB src/loadlib.c )
endif ( )

## BUILD
# Create lua library
add_library ( liblua SHARED ${SRC_CORE} ${SRC_LIB} ${LUA_DLL_RC} ${LUA_DEF} )
target_link_libraries ( liblua ${LIBS} )
set_target_properties ( liblua PROPERTIES OUTPUT_NAME lua CLEAN_DIRECT_OUTPUT 1 )

add_executable ( lua ${SRC_LUA} src/lua.rc )
target_link_libraries ( lua liblua )

add_executable ( luac ${SRC_CORE} ${SRC_LIB} ${SRC_LUAC} src/luac.rc )
target_link_libraries ( luac ${LIBS} )

install_executable ( lua luac )
install_library ( liblua )
install_data ( README.md )
#install_lua_module ( strict etc/strict.lua )
install_header ( src/lua.h src/lualib.h src/lauxlib.h ${CMAKE_CURRENT_BINARY_DIR}/luaconf.h )
install_doc ( doc/ )
install_foo ( etc/ )
#install_test ( test/ )
