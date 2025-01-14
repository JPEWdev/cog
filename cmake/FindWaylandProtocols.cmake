# - Try to find wayland-protocols, and define utility functions
#   to add code generated from them to be added to projets
#
# Once done, this will define
#
#   WAYLAND_PROTOCOLS_FOUND - the system has wayland-protocols
#   WAYLAND_PROTOCOLS - path to the wayland-protocols directory
#   add_wayland_protocol()
#
# Copyright (C) 2019 Igalia S.L.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1.  Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
# 2.  Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER AND ITS CONTRIBUTORS ``AS
# IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR ITS
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

find_package(WaylandScanner)

set(WAYLAND_PROTOCOLS "" CACHE FILEPATH "Path to the wayland-protocols data directory")

#
# Method 1: If -DWAYLAND_PROTOCOLS=... was passed in the command line,
#           check whether the "stable" and "unstable" subdirectories
#           exist.
#
if (WAYLAND_PROTOCOLS)
    get_filename_component(WAYLAND_PROTOCOLS "${WAYLAND_PROTOCOLS}" REALPATH)
    if (NOT IS_DIRECTORY "${WAYLAND_PROTOCOLS_BASE}/stable")
        set(WAYLAND_PROTOCOLS "")
    endif ()
    if (NOT IS_DIRECTORY "${WAYLAND_PROTOCOLS_BASE}/unstable")
        set(WAYLAND_PROTOCOLS "")
    endif ()
endif ()

#
# Method 2: Try to find the directory using pkg-config.
#
if (NOT DEFINED WAYLAND_PROTOCOLS OR NOT WAYLAND_PROTOCOLS)
    find_package(PkgConfig)
    pkg_check_modules(WAYLAND_PROTOCOLS_PC wayland-protocols)
    if (WAYLAND_PROTOCOLS_PC_FOUND)
        pkg_get_variable(WAYLAND_PROTOCOLS_PC_DATADIR wayland-protocols pkgdatadir)
        if (WAYLAND_PROTOCOLS_PC_DATADIR)
            set(WAYLAND_PROTOCOLS "${WAYLAND_PROTOCOLS_PC_DATADIR}")
        endif ()
    endif ()
    unset(WAYLAND_PROTOCOLS_PC)
    unset(WAYLAND_PROTOCOLS_PC_DATADIR)
endif ()


include(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(
    WAYLAND_PROTOCOLS
    DEFAULT_MSG
    WAYLAND_PROTOCOLS
    WAYLAND_SCANNER
)

function(add_wayland_protocol _target _kind _protocol)
    if (NOT TARGET ${_target})
        message(FATAL_ERROR "No such target '${_target}'")
    endif ()

    set(do_client_header OFF)
    set(do_server_header OFF)

    string(TOUPPER "${_kind}" _kind)
    if ("${_kind}" STREQUAL CLIENT)
        set(do_client_header ON)
    elseif ("${_kind}" STREQUAL SERVER)
        set(do_server_header ON)
    elseif ("${_kind}" STREQUAL BOTH)
        set(do_client_header ON)
        set(do_server_header ON)
    else ()
        message(FATAL_ERROR "Wrong argument '${_kind}', options: CLIENT, SERVER, BOTH.")
    endif ()

    set(proto_subdir "stable")
    set(proto_basename "${_protocol}")
    string(FIND "${_protocol}" "-unstable-" _unstable_index REVERSE)
    if (_unstable_index GREATER 1)
        set(proto_subdir "unstable")
        string(SUBSTRING "${_protocol}" 0 ${_unstable_index} proto_basename)
    endif ()

    get_filename_component(proto_file
        "${WAYLAND_PROTOCOLS}/${proto_subdir}/${proto_basename}/${_protocol}.xml"
        REALPATH
    )
    if (NOT EXISTS "${proto_file}")
        message(FATAL_ERROR "Cannot find Wayland protocol '${_protocol}'")
    endif ()

    message(STATUS "Wayland protocol (${_target}): ${proto_file}")

    set(proto_code "${CMAKE_BINARY_DIR}/WaylandProtocols.dir/${_protocol}.c")
    if (NOT TARGET "${proto_code}")
        add_custom_command(
            OUTPUT "${proto_code}"
            MAIN_DEPENDENCY "${proto_file}"
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_BINARY_DIR}/WaylandProtocols.dir"
            COMMAND "${WAYLAND_SCANNER}" "${WAYLAND_SCANNER_CODE_ARG}" "${proto_file}" "${proto_code}"
            VERBATIM
        )
    endif ()

    target_sources(${_target} PRIVATE "${proto_code}")
    target_include_directories(${_target} PRIVATE "${CMAKE_BINARY_DIR}/WaylandProtocols.dir")

    if (do_client_header)
        set(proto_client "${CMAKE_BINARY_DIR}/WaylandProtocols.dir/${_protocol}-client.h")
        if (NOT TARGET "${proto_client}")
            add_custom_command(
                OUTPUT "${proto_client}"
                MAIN_DEPENDENCY "${proto_file}"
                COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_BINARY_DIR}/WaylandProtocols.dir"
                COMMAND "${WAYLAND_SCANNER}" client-header "${proto_file}" "${proto_client}"
                VERBATIM
            )
        endif ()
        target_sources(${_target} PRIVATE "${proto_client}")
    endif ()

    if (do_server_header)
        set(proto_server "${CMAKE_BINARY_DIR}/WaylandProtocols.dir/${_protocol}-server.h")
        if (NOT TARGET "${proto_server}")
            add_custom_command(
                OUTPUT "${proto_server}"
                MAIN_DEPENDENCY "${proto_file}"
                COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_BINARY_DIR}/WaylandProtocols.dir"
                COMMAND "${WAYLAND_SCANNER}" server-header "${proto_file}" "${proto_server}"
                VERBATIM
            )
        endif ()
        target_sources(${_target} PRIVATE "${proto_server}")
    endif ()
endfunction()
