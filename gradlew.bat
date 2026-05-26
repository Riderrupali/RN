@rem ##########################################################################
@rem Gradle startup script for Windows
@rem ##########################################################################

@if "%DEBUG%"=="" @echo off
@rem Set local scope for variables
setlocal

set APP_NAME=Gradle
set APP_BASE_NAME=%~n0

@rem Default JVM options
set DEFAULT_JVM_OPTS="-Xmx64m" "-Xms64m"

@rem Execute Gradle
"%JAVA_EXE%" %DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS% "-Dorg.gradle.appname=%APP_BASE_NAME%" -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*

:end
endlocal
