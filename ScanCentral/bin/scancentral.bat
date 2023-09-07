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

set FORTIFY_HOME=%~dp0..

:CheckJavaAtFortifyHome
set JAVA_CMD=%FORTIFY_HOME%\jre\bin\java.exe
if not exist "%JAVA_CMD%" (
    goto CheckJavaAtCentralJavaHome
) else (
    goto Run
)

:CheckJavaAtCentralJavaHome
if ""=="%SCANCENTRAL_JAVA_HOME%" (
    goto CheckJava11AtAzureHostedAgent
)
set JAVA_CMD=%SCANCENTRAL_JAVA_HOME%\bin\java.exe
if not exist "%JAVA_CMD%" (
    goto ErrorMessage
) else (
    goto Run
)

:CheckJava11AtAzureHostedAgent
if ""=="%JAVA_HOME_11_X64%" (
    goto CheckJava17AtAzureHostedAgent
)
set JAVA_CMD=%JAVA_HOME_11_X64%\bin\java.exe
if not exist "%JAVA_CMD%" (
    goto CheckJava17AtAzureHostedAgent
) else (
    goto Run
)

:CheckJava17AtAzureHostedAgent
if ""=="%JAVA_HOME_17_X64%" (
    goto CheckJavaAtJavaHome
)
set JAVA_CMD=%JAVA_HOME_17_X64%\bin\java.exe
if not exist "%JAVA_CMD%" (
    goto CheckJavaAtJavaHome
) else (
    goto Run
)

:CheckJavaAtJavaHome
if ""=="%JAVA_HOME%" (
    set JAVA_CMD=java.exe
    goto Run
)
set JAVA_CMD=%JAVA_HOME%\bin\java.exe
if not exist "%JAVA_CMD%" (
    goto ErrorMessage
) else (
    goto Run
)

:ErrorMessage
echo ERROR: JAVA_HOME is set to an invalid directory: %JAVA_HOME%
echo ERROR: SCANCENTRAL_JAVA_HOME is not set.
echo If your project requires Java 8:
echo   1. Set the JAVA_HOME variable in your environment to match the
echo      location of your Java 8.
echo   2. Set the SCANCENTRAL_JAVA_HOME variable in your environment to match the
echo      location of your Java 11 or higher.
echo If you scan non Java project or your project requires Java 11 or higher:
echo      Set the JAVA_HOME or SCANCENTRAL_JAVA_HOME variable in your environment
echo      to match the location of your Java 11 or higher.
exit /b 1

:Run
set WORKER_PROPS=%FORTIFY_HOME%\Core\config\worker.properties

set ARGS=
:CollectArgsLoop
set ARGS=%ARGS% %1
shift
if not "%~1"=="" goto CollectArgsLoop

if not "%CLOUDSCAN_LOG%"=="" (
    echo CLOUDSCAN_LOG variable is no longer supported. Use SCANCENTRAL_LOG variable instead.
)

:RunClient
"%JAVA_CMD%" -Dscancentral.installRoot="%FORTIFY_HOME%" -Dlog4j.dir="%SCANCENTRAL_LOG%" -jar "%FORTIFY_HOME%\Core\lib\scancentral-launcher-22.2.1.0003.jar" %ARGS%

:End