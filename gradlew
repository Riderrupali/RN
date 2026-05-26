#!/usr/bin/env sh

##############################################################################
## Gradle start up script for UN*X
##############################################################################

APP_NAME="Gradle"
APP_BASE_NAME=`basename "$0"`

# Default JVM options
DEFAULT_JVM_OPTS='"-Xmx64m" "-Xms64m"'

# OS detection
case "`uname`" in
  CYGWIN* )
    cygwin=true
    ;;
  Darwin* )
    darwin=true
    ;;
  MSYS* | MINGW* )
    msys=true
    ;;
esac

CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar

exec "$JAVACMD" "$@"
