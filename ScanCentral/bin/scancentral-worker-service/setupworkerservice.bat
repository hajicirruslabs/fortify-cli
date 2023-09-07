@echo off

rem /***************************************************************************
rem * (C) Copyright 2008-2022 Micro Focus or one of its affiliates. All Rights Reserved.
rem * The only warranties for products and services of Micro Focus and its affiliates and licensors 
rem * (“Micro Focus”) are set forth in the express warranty statements accompanying such products
rem * and services. Nothing herein should be construed as constituting an additional warranty.
rem * Micro Focus shall not be liable for technical or editorial errors or omissions contained herein.
rem * The information contained herein is subject to change without notice.
rem * Confidential computer software. Except as specifically indicated otherwise, a valid license
rem * from Micro Focus is required for possession, use or copying. Consistent with FAR 12.211 and 12.212,
rem * Commercial Computer Software, Computer Software Documentation, and Technical Data for Commercial
rem * Items are licensed to the U.S. Government under vendor's standard commercial license.
rem ****************************************************************************/

echo ****************************************************************
echo (C) Copyright 2008-2022 Micro Focus or one of its affiliates.
echo Running batch file for configuring the ScanCentral Worker service
echo ****************************************************************

REM Caution: Batch file syntax for "SET var=value" requires that there are NO SPACES between variable name, '=', and value.
REM Also NO TRAILING SPACES following the value.

set MINIMUM_VERSION=4.00

if []==[%1] (goto :NOARGS)
if []==[%2] (goto :NOARGS)
if []==[%3] (goto :NOARGS)
if NOT []==[%5] (goto :NOARGS)
goto :ARGSOK

:NOARGS
echo Incorrect arguments to command.
echo[
echo Usage: "%~0"  ^<fortify_release_version^> ^<scancentral_controller_url^> ^<scancentral_worker_auth^> [pwtool_keys_file]
echo   fortify_release_version    - major.minor version of Fortify release (minimum supported version is %MINIMUM_VERSION%)
echo   scancentral_controller_url   - url of ScanCentral controller (of the form http(s)://controllerhost:port/sc-ctrl)
echo   scancentral_worker_auth      - worker auth token as configured in controller's config.properties
echo   pwtool_keys_file:          - only required if value of scancentral_worker_auth is encoded using pwtool
echo[
echo For example using plaintext password:
echo   "%~0"  22.1  http://example.com:8080/scancentral-ctrl  changeme
echo or using encoded password:
echo   "%~0"  22.1  http://example.com:8080/scancentral-ctrl  {fp0}a3OYiOetjwRcUjE5oGnMykbw5MtBckqS6NHaRBYv1+E=  c:\secrets\pwtool.keys
exit /b 1

:ARGSOK
REM RELEASE_VERSION is the major.minor release number (of the form N.XY) of the Fortify SCA install.(eg. Fortify_SCA_and_Apps_4.21_windows_x64.exe is from the 4.21 release). Do *not* use the output of "sourceanalyzer.exe -version"
set RELEASE_VERSION=%~1

set CONTROLLER_URL=%~2
REM The auth_token needs to match the value configured in the controller's config.properties
set WORKER_AUTH_TOKEN=%~3

set PWTOOL_KEYS_FILE=%~4

set SCA_INSTALL_DIR=%~dp0..\..
set PROCRUN_PATH=%~dp0

REM  *** RELEASE_VERSION 4.4+ are already bundled with JRE8 **
REM  **Optional: Set this variable if you want to use Java8 instead of the bundled Java7 on older SCA releases**
REM  ***Java8  option is only supported for RELEASE_VERSION 4.21 to 4.3X. **
set JAVA8HOME=

echo If you want to assign a sensor to the sensor pool on startup, specify the sensor pool ID. If assignment is not required, leave the value empty and press ENTER.
SET /P POOL=^>
IF DEFINED POOL echo Selected Sensor Pool is %POOL%

REM ***************DO NOT MAKE ANY CHANGES BELOW **************************

VERIFY OTHER 2>nul
SETLOCAL ENABLEEXTENSIONS
IF ERRORLEVEL 1 (
	echo Fatal error: unable to enable command processor extensions.
	exit /b 1
)
REM Turn on delayed expansion here so passwords with ! inside are not broken
VERIFY OTHER 2>nul
SETLOCAL ENABLEDELAYEDEXPANSION
IF ERRORLEVEL 1 (
	echo Fatal error: failed to enable delayed variable expansion.
	exit /b 1
)

REM Subroutine to compare versions in the form of MAJOR.MINOR
REM Usage:
REM   CALL :compare_versions %a% %b%
REM   IF !_result! LSS 0 (echo %a% lt %b%)
REM   IF !_result! EQU 0 (echo %a% eq %b%)
REM   IF !_result! GTR 0 (echo %a% gt %b%)
GOTO :compare_versions_end
:compare_versions
FOR /F "tokens=1-2 delims=." %%a IN ('echo %1') DO (
    FOR /F "tokens=1* delims=." %%x IN ('echo %2') DO (
        IF %%a LSS %%x GOTO :compare_versions_lt
        IF %%a GTR %%x GOTO :compare_versions_gt
        IF %%b LSS %%y GOTO :compare_versions_lt
        IF %%b GTR %%y GOTO :compare_versions_gt
        GOTO :compare_versions_eq
    )
)
:compare_versions_lt
SET _result=-1
GOTO :eof
:compare_versions_eq
SET _result=0
GOTO :eof
:compare_versions_gt
SET _result=1
GOTO :eof
:compare_versions_end


IF NOT DEFINED WORKDIR (
	set WORKDIR=%PUBLIC%\Fortify\SC
)
REM No spaces in the serviceName and Only one worker instance is supported per machine
set WORKER_SERVICENAME=FortifyScancentralWorkerService


echo[
echo **Please REVIEW and UPDATE the parameter values before running the script**
echo[

IF DEFINED RELEASE_VERSION (
  IF DEFINED SCA_INSTALL_DIR (
    IF DEFINED CONTROLLER_URL (
      echo RELEASE_VERSION=%RELEASE_VERSION%
      echo SCA_INSTALL_DIR=%SCA_INSTALL_DIR%
      echo PROCRUN_PATH=%PROCRUN_PATH%
      echo CONTROLLER_URL=%CONTROLLER_URL%
      echo WORKDIR=%WORKDIR%
      echo WORKER_SERVICENAME=%WORKER_SERVICENAME%
      if DEFINED PWTOOL_KEYS_FILE echo PWTOOL_KEYS_FILE=%PWTOOL_KEYS_FILE%
      if DEFINED POOL echo POOL=%POOL%
      echo[
    ) ELSE (
      echo "CONTROLLER_URL is not defined"
      goto :NO
    )
  ) ELSE (
    echo "SCA_INSTALL_DIR is not defined"
    goto :NO
  )
) ELSE (
  echo "RELEASE_VERSION is not defined"
  goto :NO
)

REM Check for minimum supported version
CALL :compare_versions %RELEASE_VERSION% %MINIMUM_VERSION%
IF !_result! LSS 0 (goto :NO)

SET /P ANSWER=Are you running the script in an Administrative command window and Have you reviewed and configured the values of all the required parameters (Y/N)?
echo You chose: %ANSWER%
echo[
if /i {%ANSWER%}=={y} (goto :YES)
if /i {%ANSWER%}=={yes} (goto :YES)

goto :NO


:NO
echo Please configure the appropriate values and re-run the script.
exit /b 1


:YES
echo Configuring ScanCentral worker service...
echo[
REM Set the Desktop folder property for localsystem (add '/f' option to avoid prompt if Value Desktop exists)
REM reg add "HKU\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v Desktop /t REG_SZ /d "C:\windows\system32\config\systemprofile\Desktop"
reg add "HKU\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v Desktop /t REG_SZ /d "%WORKDIR%\Desktop"
IF %ERRORLEVEL% NEQ 0 (
  echo Please ensure the script is being run in an administrator command window.
  exit /b 1
)

REM in release versions prior to 4.20, SCA shipped with both 32bit and 64bit JREs. we want the 64bit JRE to match with 64bit prunsrv.exe
CALL :compare_versions %RELEASE_VERSION% 4.20
IF !_result! LSS 0 (SET JHOME=%SCA_INSTALL_DIR%\jre64) ELSE (SET JHOME=%SCA_INSTALL_DIR%\jre)
REM Override JHOME if using Java8
IF NOT []==[%JAVA8HOME%] (
  CALL :compare_versions %RELEASE_VERSION% 4.21
  IF !_result! GEQ 0 (
    echo Using Java 8
	set JHOME=%JAVA8HOME%
  ) ELSE (
	echo JAVA8HOME option is not supported for RELEASE_VERSION=%RELEASE_VERSION% -- Exiting
	exit /b 1
  )
)

REM Turn off delayed expansion here so passwords with ! inside are not broken
SETLOCAL DISABLEDELAYEDEXPANSION

echo JHOME=%JHOME%
echo[
REM create the workdir
echo Creating work directory...
mkdir "%WORKDIR%"

REM create or overwrite %SCA_INSTALL_DIR%\Core\config\scancentral.properties and set the controller location property:
echo configuring controller url...
(echo com.fortify.scancentral.cli.url=%CONTROLLER_URL%) > "%SCA_INSTALL_DIR%\Core\config\scancentral.properties"
if DEFINED POOL (echo com.fortify.scancentral.cli.pool=%POOL%) >> "%SCA_INSTALL_DIR%\Core\config\scancentral.properties"

REM create or overwrite %SCA_INSTALL_DIR%\Core\config\worker.properties as usual.
echo configuring worker properties...
set WORKER_PROPS=%SCA_INSTALL_DIR%\Core\config\worker.properties
(echo worker_auth_token=%WORKER_AUTH_TOKEN%) > "%WORKER_PROPS%"
if DEFINED PWTOOL_KEYS_FILE echo pwtool_keys_file=%PWTOOL_KEYS_FILE:\=\\%>> "%WORKER_PROPS%"


REM Shutdown and Delete the service wrapper if it exists from a prior run (Delete will also stop it)
echo Deleting service (if it exists)...
"%PROCRUN_PATH%\prunsrv.exe" //DS//%WORKER_SERVICENAME%
echo[

REM Now run the prunsrv.exe command line to install the service wrapper for the worker.
echo Installing service...
"%PROCRUN_PATH%\prunsrv.exe" //IS//%WORKER_SERVICENAME%  --Description="ScanCentral worker Service"  --Install="%PROCRUN_PATH%\prunsrv.exe" ^
--Jvm="%JHOME%\bin\server\jvm.dll"  --JavaHome="%JHOME%"  ++Environment="JAVA_HOME=%JHOME%" --Classpath="%SCA_INSTALL_DIR%\Core\lib\scancentral-launcher-22.2.1.0003.jar"  --Startup=auto  ^
--StartMode=jvm --StartPath="%WORKDIR%" --StartClass=com.fortify.scancentral.launcher.Launcher --StartParams=worker  ^
--StopMode=jvm  --StopClass=com.fortify.scancentral.launcher.Launcher --StopMethod=stop  ^
--LogPath="%WORKDIR%"  --StdOutput="%WORKDIR%\workerout.log" --StdError="%WORKDIR%\workererr.log"  --LogLevel=INFO  --StopTimeout=10  ^
++JvmOptions=-Duser.dir="%WORKDIR%" ++JvmOptions=-Dscancentral.installRoot="%SCA_INSTALL_DIR%"
if ERRORLEVEL 1 goto :FAILED

echo Script complete.
goto :END

:FAILED
echo Script failed.
goto :END

:END
REM review the output for a few seconds.
c:\Windows\system32\timeout.exe /T 20
