# ryppl_export([TARGETS [targets...] ]
#              [DEPENDS [packages...] ]
#              [INCLUDE_DIRECTORIES [dirs...] ]
#              [DEFINITIONS [compile_flags...] ]
#              [CODE [lines...] ]
#              [VERSION version])
#
# ryppl_export writes targets declared in the current listfile and
# their usage requirements into a <packagename>Config.cmake file that
# can be found and used by CMake's find_package().  It also calls
# install() to generate installation instructions for -dev, -bin, and
# -dbg packages, and registers the exported package in the CMake
# package registry.
#
# TARGETS names the CMake targets that are part of the package being
# exported.
#
# DEPENDS names any additional packages needed by any project using
# the one being exported.  For example, if library A can't be used
# without library B, library A would declare B in its DEPENDS argument
#
# INCLUDE_DIRECTORIES supplies a list of arguments that will be passed
# to CMake's include_directories() immediately, *and* in the generated
# <packagename>Config.cmake file.  Pass the names of directories that
# users of the exported package will need in their #include paths.
#
# DEFINITIONS supplies compilation flags required by users of the
# exported package.
#
# CODE strings are appended as raw CMake code to the
# <packagename>Config.cmake file, one per line.
#
# VERSION is currently unused
#
##########################################################################
# Copyright (C) 2011-2012 Daniel Pfeifer <daniel@pfeifer-mail.de>        #
#                                                                        #
# Distributed under the Boost Software License, Version 1.0.             #
# See accompanying file LICENSE_1_0.txt or copy at                       #
# http://www.boost.org/LICENSE_1_0.txt                                   #
##########################################################################

if(__RypplExport_INCLUDED)
  return()
endif()
set(__RypplExport_INCLUDED True)

include(CMakeParseArguments)

# Export of projects
function(ryppl_export)
  set(parameters
    CODE
    DEFINITIONS
    DEPENDS
    INCLUDE_DIRECTORIES
    TARGETS
    )
  cmake_parse_arguments(EXPORT "" "VERSION" "${parameters}" ${ARGN})

  # Set up variables to hold fragments of the
  # <packagename>Config.cmake file we're generating
  set(_find_package )
  set(_definitions ${EXPORT_DEFINITIONS})
  set(_include_dirs )
  set(_libraries )    # contains shared libraries only

  # Should we really do this?  It means there's no way to inject
  # directories into clients' #include paths that aren't also in the
  # #include path of the project being exported.  So far, we haven't
  # needed that flexibility.
  if(EXPORT_INCLUDE_DIRECTORIES)
    include_directories(${EXPORT_INCLUDE_DIRECTORIES})
  endif(EXPORT_INCLUDE_DIRECTORIES)

  # Each dependency contributes its own dependencies, include directories, etc.
  foreach(depends ${EXPORT_DEPENDS})
    string(FIND ${depends} " " index)
    message(STATUS "found space in ${depends} at ${index}")
    string(SUBSTRING ${depends} 0 ${index} name)
    set(_find_package "${_find_package}find_package(${depends})\n")
    set(_definitions "${_definitions}\${${name}_DEFINITIONS}\n ")
    set(_include_dirs "${_include_dirs}\${${name}_INCLUDE_DIRS}\n ")
    set(_libraries "${_libraries}\${${name}_LIBRARIES}\n ")
  endforeach(depends)

  # incorporate INCLUDE_DIRECTORIES as absolute paths
  foreach(path ${EXPORT_INCLUDE_DIRECTORIES})
    get_filename_component(path "${path}" ABSOLUTE)
    set(_include_dirs "${_include_dirs}\"${path}/\"\n ")
  endforeach(path)

  set(libraries)
  set(executables)
  foreach(target ${EXPORT_TARGETS})
    get_target_property(type ${target} TYPE)
    if(type STREQUAL "SHARED_LIBRARY" OR type STREQUAL "STATIC_LIBRARY")
      # Separately accumulate shared libraries, since they are not
      # compiled into the targets exported here.
      if(type STREQUAL "SHARED_LIBRARY")
        set(_libraries "${_libraries}${target}\n ")
      endif(type STREQUAL "SHARED_LIBRARY")
      list(APPEND libraries ${target})
    elseif(type STREQUAL "EXECUTABLE")
      list(APPEND executables ${target})
    endif()
  endforeach(target)

  set(_include_guard "__${PROJECT_NAME}Config_included")
  set(_export_file "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake")

  #
  # Write the file
  #
  file(WRITE "${_export_file}"
    "# Generated by Boost.CMake\n\n"
    "if(${_include_guard})\n"
    " return()\n"
    "endif(${_include_guard})\n"
    "set(${_include_guard} TRUE)\n\n"
    )

  if(_find_package)
    file(APPEND "${_export_file}"
      "${_find_package}\n"
      )
  endif(_find_package)

  if(_definitions)
    file(APPEND "${_export_file}"
      "set(${PROJECT_NAME}_DEFINITIONS\n ${_definitions})\n"
      "if(${PROJECT_NAME}_DEFINITIONS)\n"
      " list(REMOVE_DUPLICATES ${PROJECT_NAME}_DEFINITIONS)\n"
      "endif()\n\n"
      )
  endif(_definitions)

  if(_include_dirs)
    install(DIRECTORY ${_include_dirs}
      DESTINATION include
      COMPONENT "${BOOST_DEVELOP_COMPONENT}"
      CONFIGURATIONS "Release"
      )
    file(APPEND "${_export_file}"
      "set(${PROJECT_NAME}_INCLUDE_DIRS\n ${_include_dirs})\n"
      "if(${PROJECT_NAME}_INCLUDE_DIRS)\n"
      " list(REMOVE_DUPLICATES ${PROJECT_NAME}_INCLUDE_DIRS)\n"
      "endif()\n\n"
      )
  endif(_include_dirs)

  if(_libraries)
    file(APPEND "${_export_file}"
      "set(${PROJECT_NAME}_LIBRARIES\n ${_libraries})\n"
      "if(${PROJECT_NAME}_LIBRARIES)\n"
      " list(REMOVE_DUPLICATES ${PROJECT_NAME}_LIBRARIES)\n"
      "endif()\n\n"
      )
  endif(_libraries)

  foreach(code ${EXPORT_CODE})
    file(APPEND "${_export_file}" "${code}")
  endforeach(code)

  # TODO: [NAMELINK_ONLY|NAMELINK_SKIP]
  install(TARGETS ${libraries} ${executables}
    ARCHIVE
      DESTINATION lib
      COMPONENT   dev
      CONFIGURATIONS "Release"
    LIBRARY
      DESTINATION lib
      COMPONENT   bin
      CONFIGURATIONS "Release"
    RUNTIME
      DESTINATION bin
      COMPONENT   bin
      CONFIGURATIONS "Release"
    )
  install(TARGETS ${libraries}
    ARCHIVE
      DESTINATION lib
      COMPONENT   dbg
      CONFIGURATIONS "Debug"
    LIBRARY
      DESTINATION lib
      COMPONENT   dbg
      CONFIGURATIONS "Debug"
    RUNTIME
      DESTINATION bin
      COMPONENT   dbg
      CONFIGURATIONS "Debug"
    )

  export(PACKAGE ${PROJECT_NAME})
endfunction(ryppl_export)