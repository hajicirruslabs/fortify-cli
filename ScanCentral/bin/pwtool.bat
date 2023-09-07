@echo off

rem /***************************************************************************
rem * (C) Copyright 2016 Micro Focus or one of its affiliates. All Rights Reserved.
rem * The only warranties for products and services of Micro Focus and its affiliates and licensors
rem * ("Micro Focus") are set forth in the express warranty statements accompanying such products
rem * and services. Nothing herein should be construed as constituting an additional warranty.
rem * Micro Focus shall not be liable for technical or editorial errors or omissions contained herein.
rem * The information contained herein is subject to change without notice.
rem * Confidential computer software. Except as specifically indicated otherwise, a valid license
rem * from Micro Focus is required for possession, use or copying. Consistent with FAR 12.211 and 12.212,
rem * Commercial Computer Software, Computer Software Documentation, and Technical Data for Commercial
rem * Items are licensed to the U.S. Government under vendor's standard commercial license.
rem ****************************************************************************/

set SELF=%~0

rem Detect base and directory fortify home
set BASE_DIR=%~dp0
set FORTIFY_HOME=%BASE_DIR%..\

rem Detect path to pwtool jar
set PWTOOL_JAR=pwtool.jar
set PWTOOL_JAR_PATH=%FORTIFY_HOME%Core\lib\exe\%PWTOOL_JAR%
if not exist "%PWTOOL_JAR_PATH%" set PWTOOL_JAR_PATH=%BASE_DIR%%PWTOOL_JAR%
if not exist "%PWTOOL_JAR_PATH%" (
    echo Unable to find %PWTOOL_JAR%
    exit /B 1
)

rem Detect JRE
set JAVA_CMD=%FORTIFY_HOME%jre\bin\java.exe
if not exist "%JAVA_CMD%" set JAVA_CMD=java.exe

rem Check for decode option
set DECODE=false
if "%~1"=="-d" (
    set DECODE=true
    shift
)

rem Check if filename has been provided
if "%~1"=="" goto :usage

rem Check for common help options
if "%~1"=="/?" goto :usage
if "%~1"=="-?" goto :usage
if "%~1"=="-h" goto :usage
if "%~1"=="--help" goto :usage

rem Get keys filename
set KEYS_FILE=%~1
shift

rem Check for excess arguments
if NOT "%~1"=="" goto :usage

rem Everything is ok, execute
goto :execute

:usage
echo Usage: "%SELF%" [-d] FILENAME
echo   -d          - switch to decryption mode
echo   FILENAME    - path to pwtool keys file; if the file exists,
echo                 stored key will be read,
echo                 otherwise new key will be generated and stored
exit /B 1

:execute
"%JAVA_CMD%" "-Dpwtool_keys_file=%KEYS_FILE%" -Dpwtool_decode=%DECODE% -jar "%PWTOOL_JAR_PATH%"
