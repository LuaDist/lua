# Copyright (C) 2007-2009 LuaDist.
# Created by Peter Drahoš and Peter Kapec
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

PROJECT ( lua C )
CMAKE_MINIMUM_REQUIRED(VERSION 2.8)
INCLUDE(dist.cmake )

# Determine install host
IF ( WIN32 AND NOT CYGWIN)
	ADD_DEFINITIONS ( -DLUA_BUILD_AS_DLL )
	IF(MSVC)
		ADD_DEFINITIONS(-D_CRT_SECURE_NO_DEPRECATE )
		SET(DEF_FILE src/lua.def)
		SET(DLL_RC_FILE src/lua_dll.rc)
		SET(LUA_RC_FILE src/lua.rc)
		SET(LUAC_RC_FILE src/lua_simple.rc)
	ENDIF()
ELSE ( )
	ADD_DEFINITIONS ( -DLUA_USE_POSIX -DLUA_USE_DLOPEN )
	SET ( LIBS m dl )
ENDIF ( )

# Add Readline support when available
FIND_PATH(READLINE_INCLUDE_DIR readline/readline.h)
FIND_LIBRARY(READLINE_LIBRARY NAMES readline)
IF ( READLINE_LIBRARY )
	INCLUDE_DIRECTORIES ( ${READLINE_INCLUDE_DIR} )
	ADD_DEFINITIONS ( -DLUA_USE_READLINE )
	SET ( LIBS ${LIBS} ${READLINE_LIBRARY} )
ENDIF ( )

# Add Curses support when available
INCLUDE(FindCurses)
IF ( CURSES_LIBRARY )
	INCLUDE_DIRECTORIES ( ${CURSES_INCLUDE_DIR} )
	SET ( LIBS ${LIBS} ${CURSES_LIBRARY} )
ENDIF ( )

# Build Libraries
SET ( SRC_LIBLUA src/lapi.c src/lcode.c src/ldebug.c src/ldo.c src/ldump.c src/lfunc.c src/lgc.c src/llex.c src/lmem.c src/lobject.c src/lopcodes.c src/lparser.c src/lstate.c src/lstring.c src/ltable.c src/ltm.c src/lundump.c src/lvm.c src/lzio.c src/lauxlib.c src/lbaselib.c src/ldblib.c src/liolib.c src/lmathlib.c src/loslib.c src/ltablib.c src/lstrlib.c src/loadlib.c src/linit.c )

ADD_LIBRARY ( liblua SHARED ${SRC_LIBLUA} ${DEF_FILE} ${DLL_RC_FILE})
TARGET_LINK_LIBRARIES ( liblua ${LIBS})
SET_TARGET_PROPERTIES ( liblua PROPERTIES OUTPUT_NAME lua CLEAN_DIRECT_OUTPUT 1 )

ADD_LIBRARY ( liblua_static ${SRC_LIBLUA} )
TARGET_LINK_LIBRARIES ( liblua_static ${LIBS})

INCLUDE_DIRECTORIES ( src )

# Build Executables
SET ( SRC_LUA src/lua.c )
SET ( SRC_LUAC src/luac.c src/print.c )

ADD_EXECUTABLE ( lua ${SRC_LUA} ${LUA_RC_FILE})
ADD_EXECUTABLE ( luac ${SRC_LUAC} ${LUAC_RC_FILE})
TARGET_LINK_LIBRARIES ( lua liblua )
TARGET_LINK_LIBRARIES ( luac liblua_static )

# Install
INSTALL ( TARGETS lua luac liblua RUNTIME DESTINATION ${INSTALL_BIN} LIBRARY DESTINATION ${INSTALL_LIB} )
INSTALL ( FILES src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h etc/lua.hpp DESTINATION ${INSTALL_INC} )
INSTALL ( FILES etc/strict.lua DESTINATION ${INSTALL_LMOD} )
INSTALL ( DIRECTORY doc etc test DESTINATION ${INSTALL_DATA} PATTERN ".git" EXCLUDE )
INSTALL ( FILES README COPYRIGHT HISTORY DESTINATION ${INSTALL_DATA} )
