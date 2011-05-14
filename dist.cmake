# LuaDist CMake utility library.
# Provides variables and utility functions common to LuaDist CMake builds.
# 
# Copyright (C) 2007-2011 LuaDist.
# by David Manura, Peter Drahos
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

## INSTALL DEFAULTS (Relative to CMAKE_INSTALL_PREFIX)
# Primary paths
set ( INSTALL_BIN bin CACHE PATH "Where to install binaries to." )
set ( INSTALL_LIB lib CACHE PATH "Where to install libraries to." )
set ( INSTALL_INC include CACHE PATH "Where to install headers to." )
set ( INSTALL_ETC etc CACHE PATH "Where to store configuration files" )
set ( INSTALL_LMOD ${INSTALL_LIB}/lua CACHE PATH "Directory to install Lua modules." )
set ( INSTALL_CMOD ${INSTALL_LIB}/lua CACHE PATH "Directory to install Lua binary modules." )
set ( INSTALL_SHARE share CACHE PATH "Directory for shared data." )

# Secondary paths
set ( INSTALL_DATA ${INSTALL_SHARE}/${PROJECT_NAME} CACHE PATH "Directory the package can store documentation, tests or other data in.")
set ( INSTALL_DOC ${INSTALL_DATA}/doc CACHE PATH "Recommended directory to install documentation into.")
set ( INSTALL_EXAMPLE ${INSTALL_DATA}/example CACHE PATH "Recommended directory to install examples into.")
set ( INSTALL_TEST ${INSTALL_DATA}/test CACHE PATH "Recommended directory to install tests into.")
set ( INSTALL_FOO ${INSTALL_DATA}/etc CACHE PATH "Where to install additional files")

# Skipable content, headers, binaries and libraries are always required
option ( SKIP_TESTING "Do not add tests." OFF)
option ( SKIP_LUA_WRAPPER "Do not build and install Lua executable wrappers." OFF)
option ( SKIP_INSTALL_DATA "Skip installing all data." OFF )
if ( NOT SKIP_INSTALL_DATA )
  option ( SKIP_INSTALL_DOC "Skip installation of documentation." OFF )  
  option ( SKIP_INSTALL_EXAMPLE "Skip installation of documentation." OFF )
  option ( SKIP_INSTALL_TEST "Skip installation of tests." OFF)
  option ( SKIP_INSTALL_FOO "Skip installation of optional package content." OFF)
endif ()

# TWEAKS
# Setting CMAKE to use loose block and search for find modules in source directory
set ( CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS true )
set ( CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_MODULE_PATH} )

# In MSVC, prevent warnings that can occur when using standard libraries.
if ( MSVC )
	add_definitions ( -D_CRT_SECURE_NO_WARNINGS )
endif ()

## MACROS
# Parser macro
macro ( parse_arguments prefix arg_names option_names)
  set ( DEFAULT_ARGS )
  foreach ( arg_name ${arg_names} )
    set ( ${prefix}_${arg_name} )
  endforeach ()
  foreach ( option ${option_names} )
    set ( ${prefix}_${option} FALSE )
  endforeach ()

  set ( current_arg_name DEFAULT_ARGS )
  set ( current_arg_list )
  foreach ( arg ${ARGN} )            
    set ( larg_names ${arg_names} )    
    list ( FIND larg_names "${arg}" is_arg_name )                   
    if ( is_arg_name GREATER -1 )
      set ( ${prefix}_${current_arg_name} ${current_arg_list} )
      set ( current_arg_name ${arg} )
      set ( current_arg_list )
    else ()
      set ( loption_names ${option_names} )    
      list ( FIND loption_names "${arg}" is_option )            
      if ( is_option GREATER -1 )
	     set ( ${prefix}_${arg} TRUE )
      else ()
	     set ( current_arg_list ${current_arg_list} ${arg} )
      endif ()
    endif ()
  endforeach ()
  set ( ${prefix}_${current_arg_name} ${current_arg_list} )
endmacro ()

# INSTALL_LUA_EXECUTABLE ( target source )
# Automatically generate a binary wrapper for lua application and install it
# The wrapper and the source of the application will be placed into /bin
# If the application source did not have .lua suffix then it will be added
# USE: lua_executable ( sputnik src/sputnik.lua )
macro ( install_lua_executable _name _source )
  get_filename_component ( _source_name ${_source} NAME_WE )
  if ( NOT SKIP_LUA_WRAPPER )
    enable_language ( C )
  
    find_package ( Lua51 REQUIRED )
    include_directories ( ${LUA_INCLUDE_DIR} )

    set ( _wrapper ${CMAKE_CURRENT_BINARY_DIR}/${_name}.c )
    set ( _code 
"// Not so simple executable wrapper for Lua apps
#include <stdio.h>
#include <signal.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

lua_State *L\;

static int getargs (lua_State *L, char **argv, int n) {
int narg\;
int i\;
int argc = 0\;
while (argv[argc]) argc++\;
narg = argc - (n + 1)\;
luaL_checkstack(L, narg + 3, \"too many arguments to script\")\;
for (i=n+1\; i < argc\; i++)
  lua_pushstring(L, argv[i])\;
lua_createtable(L, narg, n + 1)\;
for (i=0\; i < argc\; i++) {
  lua_pushstring(L, argv[i])\;
  lua_rawseti(L, -2, i - n)\;
}
return narg\;
}

static void lstop (lua_State *L, lua_Debug *ar) {
(void)ar\;
lua_sethook(L, NULL, 0, 0)\;
luaL_error(L, \"interrupted!\")\;
}

static void laction (int i) {
signal(i, SIG_DFL)\;
lua_sethook(L, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1)\;
}

static void l_message (const char *pname, const char *msg) {
if (pname) fprintf(stderr, \"%s: \", pname)\;
fprintf(stderr, \"%s\\n\", msg)\;
fflush(stderr)\;
}

static int report (lua_State *L, int status) {
if (status && !lua_isnil(L, -1)) {
  const char *msg = lua_tostring(L, -1)\;
  if (msg == NULL) msg = \"(error object is not a string)\"\;
  l_message(\"${_source_name}\", msg)\;
  lua_pop(L, 1)\;
}
return status\;
}

static int traceback (lua_State *L) {
if (!lua_isstring(L, 1))
  return 1\;
lua_getfield(L, LUA_GLOBALSINDEX, \"debug\")\;
if (!lua_istable(L, -1)) {
  lua_pop(L, 1)\;
  return 1\;
}
lua_getfield(L, -1, \"traceback\")\;
if (!lua_isfunction(L, -1)) {
  lua_pop(L, 2)\;
  return 1\;
}
lua_pushvalue(L, 1)\; 
lua_pushinteger(L, 2)\;
lua_call(L, 2, 1)\;
return 1\;
}

static int docall (lua_State *L, int narg, int clear) {
int status\;
int base = lua_gettop(L) - narg\;
lua_pushcfunction(L, traceback)\;
lua_insert(L, base)\;
signal(SIGINT, laction)\;
status = lua_pcall(L, narg, (clear ? 0 : LUA_MULTRET), base)\;
signal(SIGINT, SIG_DFL)\;
lua_remove(L, base)\;
if (status != 0) lua_gc(L, LUA_GCCOLLECT, 0)\;
return status\;
}

int main (int argc, char **argv) {
L=lua_open()\;
lua_gc(L, LUA_GCSTOP, 0)\;
luaL_openlibs(L)\;
lua_gc(L, LUA_GCRESTART, 0)\;
int narg = getargs(L, argv, 0)\;
lua_setglobal(L, \"arg\")\;

// Script
char script[500] = \"./${_source_name}.lua\"\;
lua_getglobal(L, \"_PROGDIR\")\;
if (lua_isstring(L, -1)) {
  sprintf( script, \"%s/${_source_name}.lua\", lua_tostring(L, -1))\;
} 
lua_pop(L, 1)\;

// Run
int status = luaL_loadfile(L, script)\;
lua_insert(L, -(narg+1))\;
if (status == 0)
  status = docall(L, narg, 0)\;
else
  lua_pop(L, narg)\;

report(L, status)\;
lua_close(L)\;
return status\;
};
")
    file ( WRITE ${_wrapper} ${_code} )
    add_executable ( ${_name} ${_wrapper} )
    target_link_libraries ( ${_name} ${LUA_LIBRARY} )
    install ( TARGETS ${_name} DESTINATION ${INSTALL_BIN} )
  endif()
  install ( PROGRAMS ${_source} DESTINATION ${INSTALL_BIN} RENAME ${_source_name}.lua )
endmacro ()

# INSTALL_LIBRARY
# Installs any libraries generated using "add_library" into apropriate places.
# USE: install_library ( libexpat )
macro ( install_library )
  foreach ( _file ${ARGN} )
    install ( TARGETS ${_file} RUNTIME DESTINATION ${INSTALL_BIN} LIBRARY DESTINATION ${INSTALL_LIB} ARCHIVE DESTINATION ${INSTALL_LIB} )
  endforeach()
endmacro ()

# INSTALL_EXECUTABLE
# Installs any executables generated using "add_executable".
# USE: install_executable ( lua )
macro ( install_executable )
  foreach ( _file ${ARGN} )
    install ( TARGETS ${_file} RUNTIME DESTINATION ${INSTALL_BIN} )
  endforeach()
endmacro ()

# INSTALL_HEADER
# Install a directories or files into header destination.
# USE: install_header ( lua.h luaconf.h ) or install_header ( GL )
# NOTE: If headers need to be installed into subdirectories use the INSTALL command directly
macro ( install_header )
  parse_arguments ( _ARG "INTO" "" ${ARGN} )
  foreach ( _file ${_ARG_DEFAULT_ARGS} )
    if ( IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${_file}" )
      install ( DIRECTORY ${_file} DESTINATION ${INSTALL_INC}/${_ARG_INTO} )
    else ()
      install ( FILES ${_file} DESTINATION ${INSTALL_INC}/${_ARG_INTO} )
    endif ()
  endforeach()
endmacro ()

# INSTALL_DATA ( files/directories )
# This installs additional data files or directories.
# USE: install_data ( extra data.dat )
macro ( install_data )
  if ( NOT SKIP_INSTALL_DATA )
    parse_arguments ( _ARG "INTO" "" ${ARGN} )
    foreach ( _file ${_ARG_DEFAULT_ARGS} )
      if ( IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${_file}" )
        install ( DIRECTORY ${_file} DESTINATION ${INSTALL_DATA}/${_ARG_INTO} )
      else ()
        install ( FILES ${_file} DESTINATION ${INSTALL_DATA}/${_ARG_INTO} )
      endif ()
    endforeach()
  endif()
endmacro ()

# INSTALL_DOC ( files/directories )
# This installs documentation content
# USE: install_doc ( doc/ )
macro ( install_doc )
  if ( NOT SKIP_INSTALL_DATA AND NOT SKIP_INSTALL_DOC )
    parse_arguments ( _ARG "INTO" "" ${ARGN} )
    foreach ( _file ${_ARG_DEFAULT_ARGS} )
      if ( IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${_file}" )
        install ( DIRECTORY ${_file} DESTINATION ${INSTALL_DOC}/${_ARG_INTO} )
      else ()
        install ( FILES ${_file} DESTINATION ${INSTALL_DOC}/${_ARG_INTO} )
      endif ()
    endforeach()
  endif()
endmacro ()

# INSTALL_EXAMPLE ( files/directories )
# This installs additional data
# USE: install_example ( examples/ exampleA.lua )
macro ( install_example )
  if ( NOT SKIP_INSTALL_DATA AND NOT SKIP_INSTALL_EXAMPLE )
    parse_arguments ( _ARG "INTO" "" ${ARGN} )
    foreach ( _file ${_ARG_DEFAULT_ARGS} )
      if ( IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${_file}" )
        install ( DIRECTORY ${_file} DESTINATION ${INSTALL_EXAMPLE}/${_ARG_INTO} )
      else ()
        install ( FILES ${_file} DESTINATION ${INSTALL_EXAMPLE}/${_ARG_INTO} )
      endif ()
    endforeach()
  endif()
endmacro ()

# INSTALL_TEST ( files/directories )
# This installs tests
# USE: install_example ( examples/ exampleA.lua )
macro ( install_test )
  if ( NOT SKIP_INSTALL_DATA AND NOT SKIP_INSTALL_TEST )
    parse_arguments ( _ARG "INTO" "" ${ARGN} )
    foreach ( _file ${_ARG_DEFAULT_ARGS} )
      if ( IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${_file}" )
        install ( DIRECTORY ${_file} DESTINATION ${INSTALL_TEST}/${_ARG_INTO} )
      else ()
        install ( FILES ${_file} DESTINATION ${INSTALL_TEST}/${_ARG_INTO} )
      endif ()
    endforeach()
  endif()
endmacro ()

# INSTALL_FOO ( files/directories )
# This installs optional content
# USE: install_foo ( examples/ exampleA.lua )
macro ( install_foo )
  if ( NOT SKIP_INSTALL_DATA AND NOT SKIP_INSTALL_FOO )
    parse_arguments ( _ARG "INTO" "" ${ARGN} )
    foreach ( _file ${_ARG_DEFAULT_ARGS} )
      if ( IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${_file}" )
        install ( DIRECTORY ${_file} DESTINATION ${INSTALL_FOO}/${_ARG_INTO} )
      else ()
        install ( FILES ${_file} DESTINATION ${INSTALL_FOO}/${_ARG_INTO} )
      endif ()
    endforeach()
  endif()
endmacro ()

# INSTALL_LUA_MODULE
# This macro installs a lua source module into destination given by lua require syntax.
# Binary modules are also supported where this funcion takes sources and libraries to compile separated by LINK keyword
# USE: install_lua_module ( socket.http src/http.lua )
# USE2: install_lua_module ( mime.core src/mime.c )
# USE3: install_lua_module ( socket.core ${SRC_SOCKET} LINK ${LIB_SOCKET} )
macro (install_lua_module _name )
  string ( REPLACE "." "/" _module "${_name}" )
  string ( REPLACE "." "_" _target "${_name}" )
  
  set ( _lua_module "${_module}.lua" )
  set ( _bin_module "${_module}${CMAKE_SHARED_MODULE_SUFFIX}" )
  
  parse_arguments ( _MODULE "LINK" "" ${ARGN} )
  get_filename_component ( _ext ${ARGV1} EXT )
  if ( _ext STREQUAL ".lua" )
      get_filename_component ( _path ${_lua_module} PATH )
      get_filename_component ( _filename ${_lua_module} NAME )
      install ( FILES ${ARGV1} DESTINATION ${INSTALL_LMOD}/${_path} RENAME ${_filename} )
  else ()
     enable_language ( C )
     get_filename_component ( _module_name ${_bin_module} NAME_WE )
     get_filename_component ( _module_path ${_bin_module} PATH )
     
     find_package ( Lua51 REQUIRED )
     include_directories ( ${LUA_INCLUDE_DIR} )
   
     add_library( ${_target} MODULE ${_MODULE_DEFAULT_ARGS})
     target_link_libraries ( ${_target} ${LUA_LIBRARY} ${_MODULE_LINK} )
     set_target_properties ( ${_target} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${_module_path}" PREFIX "" OUTPUT_NAME "${_module_name}" )
     
     install ( TARGETS ${_target} DESTINATION ${INSTALL_CMOD}/${_module_path})
  endif ()
endmacro ()

# ADD_LUA_TEST
# Runs Lua script `_testfile` under CTest tester.
# Optional argument `_testcurrentdir` is current working directory to run test under
# (defaults to ${CMAKE_CURRENT_BINARY_DIR}).
# Both paths, if relative, are relative to ${CMAKE_CURRENT_SOURCE_DIR}.
# Under LuaDist, set test=true in config.lua to enable testing.
# USE: add_lua_test ( test/test1.lua [args...] )
macro ( add_lua_test _testfile )
	if ( NOT SKIP_TESTING )
		include ( CTest )
		find_program ( LUA NAMES lua lua.bat )
		get_filename_component ( TESTFILEABS ${_testfile} ABSOLUTE )
		get_filename_component ( TESTFILENAME ${_testfile} NAME )
		get_filename_component ( TESTFILEBASE ${_testfile} NAME_WE )

		# Write wrapper script.
		set ( TESTWRAPPER ${CMAKE_CURRENT_BINARY_DIR}/${TESTFILENAME} )
		set ( TESTWRAPPERSOURCE
"local configuration = ...
local sodir = '${CMAKE_CURRENT_BINARY_DIR}' .. (configuration == '' and '' or '/' .. configuration)
package.path  = sodir .. '/?.lua\;' .. sodir .. '/?.lua\;' .. package.path
package.cpath = sodir .. '/?.so\;'  .. sodir .. '/?.dll\;' .. package.cpath
arg[0] = '${TESTFILEABS}'
table.remove(arg, 1)
return assert(loadfile '${TESTFILEABS}')(unpack(arg))
"		)
		if ( ${ARGC} GREATER 1 )
			set ( _testcurrentdir ${ARGV1} )
			get_filename_component ( TESTCURRENTDIRABS ${_testcurrentdir} ABSOLUTE )
			# note: CMake 2.6 (unlike 2.8) lacks WORKING_DIRECTORY parameter.
#old:		set ( TESTWRAPPERSOURCE "require 'lfs'; lfs.chdir('${TESTCURRENTDIRABS}' ) ${TESTWRAPPERSOURCE}" )
			set ( _pre ${CMAKE_COMMAND} -E chdir "${TESTCURRENTDIRABS}" )
		endif ()
		file ( WRITE ${TESTWRAPPER} ${TESTWRAPPERSOURCE})
		add_test ( NAME ${TESTFILEBASE} COMMAND ${_pre} ${LUA} ${TESTWRAPPER} $<CONFIGURATION> ${ARGN} )
	endif ()
	# see also http://gdcm.svn.sourceforge.net/viewvc/gdcm/Sandbox/CMakeModules/UsePythonTest.cmake
endmacro ()

# Converts Lua source file `_source` to binary string embedded in C source
# file `_target`.  Optionally compiles Lua source to byte code (not available
# under LuaJIT2, which doesn't have a bytecode loader).  Additionally, Lua
# versions of bin2c [1] and luac [2] may be passed respectively as additional
# arguments.
#
# [1] http://lua-users.org/wiki/BinToCee
# [2] http://lua-users.org/wiki/LuaCompilerInLua
function ( add_lua_bin2c _target _source )
	find_program ( LUA NAMES lua lua.bat )
	execute_process ( COMMAND ${LUA} -e "string.dump(function()end)" RESULT_VARIABLE _LUA_DUMP_RESULT ERROR_QUIET )
	if ( NOT ${_LUA_DUMP_RESULT} )
		SET ( HAVE_LUA_DUMP true )
	endif ()
	message ( "-- string.dump=${HAVE_LUA_DUMP}" )

	if ( ARGV2 )
		get_filename_component ( BIN2C ${ARGV2} ABSOLUTE )
		set ( BIN2C ${LUA} ${BIN2C} )
	else ()
		find_program ( BIN2C NAMES bin2c bin2c.bat )
	endif ()
	if ( HAVE_LUA_DUMP )
		if ( ARGV3 )
			get_filename_component ( LUAC ${ARGV3} ABSOLUTE )
			set ( LUAC ${LUA} ${LUAC} )
		else ()
			find_program ( LUAC NAMES luac luac.bat )
		endif ()
	endif ( HAVE_LUA_DUMP )
	message ( "-- bin2c=${BIN2C}" )
	message ( "-- luac=${LUAC}" )

	get_filename_component ( SOURCEABS ${_source} ABSOLUTE )
	if ( HAVE_LUA_DUMP )
		get_filename_component ( SOURCEBASE ${_source} NAME_WE )
		add_custom_command (
			OUTPUT  ${_target} DEPENDS ${_source}
			COMMAND ${LUAC} -o ${CMAKE_CURRENT_BINARY_DIR}/${SOURCEBASE}.lo ${SOURCEABS}
			COMMAND ${BIN2C} ${CMAKE_CURRENT_BINARY_DIR}/${SOURCEBASE}.lo ">${_target}" )
	else ()
		add_custom_command (
			OUTPUT  ${_target} DEPENDS ${SOURCEABS}
			COMMAND ${BIN2C} ${_source} ">${_target}" )
	endif ()
endfunction()
