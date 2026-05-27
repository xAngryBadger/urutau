@echo off
setlocal
REM Usa JAVA_HOME se ja for Java 11+
if defined JAVA_HOME (
  "%JAVA_HOME%\bin\java.exe" -version 2>nul | findstr /R "version \"1[1-9]\\. version \"2[0-9]\\." >nul
  if %errorlevel% equ 0 goto run
)
REM Procura JDK 17/21 em locais comuns (Windows)
set "JAVA_HOME="
for %%P in (
  "C:\Program Files\Eclipse Adoptium\jdk-17.0.13.11-hotspot"
  "C:\Program Files\Eclipse Adoptium\jdk-17"
  "C:\Program Files\Microsoft\jdk-17.0.13"
  "C:\Program Files\Microsoft\jdk-17"
  "C:\Program Files\Java\jdk-17"
  "C:\Program Files\Android\Android Studio\jbr"
) do if exist "%%~P\bin\java.exe" (set "JAVA_HOME=%%~P" & goto run)
dir "C:\Program Files\Eclipse Adoptium\jdk-17*" /b /ad 2>nul | findstr . >nul
if %errorlevel% equ 0 (
  for /f "delims=" %%D in ('dir "C:\Program Files\Eclipse Adoptium\jdk-17*" /b /ad 2^>nul') do (
    set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\%%D"
    goto run
  )
)
echo.
echo [ERRO] Gradle precisa de Java 11+. Instale JDK 17 (adoptium.net) e defina JAVA_HOME
echo        ou em android\gradle.properties defina org.gradle.java.home
echo.
exit /b 1
:run
call "%~dp0gradlew.bat" %*
exit /b %errorlevel%
