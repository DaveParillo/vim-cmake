cmake_minimum_required(VERSION 3.15)

project(HelloWorld)

option(WITH_BYE "Print bye world" OFF)

configure_file(configure.h.cmake configure.h)
add_executable(hello main.cpp)
target_include_directories(hello PRIVATE ${CMAKE_BINARY_DIR})
