# Copyright (c) 2015 Piotr L. Figlarek
#
# CMake module for Unity test framework, for more details visit:
#  - http://www.throwtheswitch.org/
#  - https://github.com/ThrowTheSwitch/Unity
#
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
# documentation files (the "Software"), to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions
# of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
# LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# name of the target with all Unity tests
set(UNITY_TARGET utest CACHE STRING "Common target for all Unity tests")

# option(UNITY_GNU99 "Add --std=gnu99 flag during test compilation" ON)
option(UNITY_C99 "Add --std=c99 flag during test compilation" ON)

# module was not tested with earlier versions
cmake_minimum_required(VERSION 3.0.2)

# use C99 if it's allowed
if(UNITY_C99)
    set(CMAKE_C_FLAGS "-std=c99 ${CMAKE_C_FLAGS}")
endif()

# Unity root directory
set(UNITY_DIR ${CMAKE_CURRENT_LIST_DIR}/..)

# find Unity framework
find_file(UNITY_SRC unity.c ${UNITY_DIR}/src)
if(UNITY_SRC)
    message(STATUS "Unity src: ${UNITY_SRC}")
else()
    message(FATAL_ERROR "Unity src: NOT FOUND!")
endif()

# create static library for all Unity tests
add_library(unity STATIC ${UNITY_SRC})

# create full name for test target
macro(create_TEST_TARGET TEST_NAME)
    set(TEST_TARGET ${UNITY_TARGET}.${TEST_NAME})
endmacro()

# show results from all Unity tests
add_custom_target(${UNITY_TARGET}
    COMMAND ruby ${UNITY_DIR}/auto/unity_test_summary.rb ./

    COMMENT "Show Unity tests summary"
)

# unity.h header file should be available for all tests
include_directories(${UNITY_DIR}/src)

# add Unity test
#  arg1 - test name
#  arg2 - unit test main file
#  arg3, ... - all other sources needed for test
function(unity_add_test TEST_NAME)
    create_TEST_TARGET(${TEST_NAME})

    # first file should contain full Unity test definition
    get_filename_component(TEST_FULLPATH ${ARGV1} REALPATH)
    # generate Unity test runner
    set(TEST_RUNNER ${TEST_NAME}_Runner.c)
    add_custom_command(
        OUTPUT ${TEST_RUNNER}
        COMMAND ruby ${UNITY_DIR}/auto/generate_test_runner.rb
                     ${TEST_FULLPATH}
                     ${TEST_RUNNER} > /dev/null
        DEPENDS ${ARGV1}
        COMMENT "Generating test runner for test: ${TEST_RUNNER}"
    )

    # build test application
    add_executable(${TEST_TARGET} ${TEST_RUNNER} ${ARGN})
    # and link it with Unity lib
    target_link_libraries(${TEST_TARGET} unity)

    # run test and prepare test result file
    set(TEST_RESULT ${TEST_TARGET}.testresults)
    add_custom_command(
        OUTPUT ${TEST_RESULT}
        COMMAND ${TEST_TARGET} > ${TEST_TARGET}.testresults || true    # dirty hack to ignore any potential error
        COMMENT "Running test: ${TEST_NAME}"
        DEPENDS ${TEST_TARGET}
    )

    # fake target to build & run tests
    set(TEST_EXECUTOR ${TEST_TARGET}.executor)
    add_custom_target(${TEST_EXECUTOR}
        SOURCES ${TEST_RESULT}
    )

    # connect this test with Unity test target
    add_dependencies(${UNITY_TARGET} ${TEST_EXECUTOR})

    # add this test to CTest
    add_test(${TEST_TARGET} ${TEST_TARGET})

    message(STATUS "Unity test '${TEST_TARGET}' added")
endfunction()


# link unity test with library
#  arg1 - test name
#  arg2, ... - all STATIC librarties
function(unity_link_libraries TEST_NAME)
    create_TEST_TARGET(${TEST_NAME})

    # link each library with test target
    foreach(lib ${ARGN})
        target_link_libraries(${TEST_TARGET} ${lib})
        message(STATUS "Unity test '${TEST_TARGET}' linked with 'lib${lib}'")
    endforeach()
endfunction()
