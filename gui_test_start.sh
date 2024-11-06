#!/bin/bash

@include() { source "$@"; } # for testing
export HORIZON_HOME=${HORIZON_HOME:-$HOME/Horizon}
export PSRV_HOME=${PSRV_HOME:-$HORIZON_HOME/Server}
export AGENT_HOME=${AGENT_HOME:-$HORIZON_HOME/Agent}
export TOOLS_HOME=${TOOLS_HOME:-$HORIZON_HOME/Tools}
export LAUNCHER_HOME=${LAUNCHER_HOME:-$HORIZON_HOME/Launcher}

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] ERROR  $@" >&2
}

warn() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] WARN   $@" >&2
}

log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] INFO   $@" >&2
}

debug() {
  [[ -n "$DEBUG" ]] && \
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] DEBUG  $@" >&2
}

# Usage: download URL [DEST]
#   If DEST is missing, outputs URL on stdout, otherwise download into DEST file
function download() {
    local url=$1
    local dest=$2
    local tmp=/tmp/dl$$
    log "Downloading $url" >& 2
    curl --fail -s "$url" > ${tmp}
    if [[ $? = 0 ]]; then
        if [[ -z ${dest} ]]; then
            cat ${tmp}
            rm ${tmp}
        else
            mv ${tmp} ${dest}
        fi
    else
        err "Download failed (status $?) for $url"
        rm -f ${tmp}
        return 2
    fi
}


UNAME=$(uname -s)
case ${UNAME} in
*inux*) SYSTEM=linux-x64 ;;
MSYS*) SYSTEM=windows-x64 ;;
MINGW64*) SYSTEM=windows-x64 ;;
*)
  SYSTEM=unknown:$UNAME
  ;;
esac




#
# Usage: extract archive(.zip|.tar.gz) dest_dir
extract() {
  local ARCHIVE="$1"
  local DEST="$2"

  mkdir -p "$DEST"
  log "Extracting $ARCHIVE into $DEST"
  if [[ ${ARCHIVE} == *.zip ]]; then
    unzip ${ARCHIVE} -d "$DEST" > /dev/null
  elif [[ ${ARCHIVE} == *.tar.gz ]]; then
    tar xfz ${ARCHIVE} -C ${DEST}
  else
    err "Unsupported archive type: $ARCHIVE"
    return 3
  fi
}


_find_java_in_tools() {
  local TOOLS="$TOOLS_HOME/$SYSTEM/jdk"
  local PROCESS_ID="$2"
  local JAVA_EXE=java
  if [[ $SYSTEM == windows* ]]; then
    JAVA_EXE=javaw.exe
  fi

  log "Trying to download JDK from PSRV"
  mkdir -p "$TOOLS"
  if [[ $? != 0 ]]; then
    err "Failed to create directory $TOOLS"
    return 2
  fi

  local WHERE=${TOOLS}
  # not local because used later
  JDK_VERSION=$(curl --silent --fail "$URL/api/whichJDK?system=${SYSTEM}&processId=${PROCESS_ID}")
  if [[ ${JDK_VERSION} != "" ]]; then
    log "JDK version $JDK_VERSION should be used for process: ${PROCESS_ID}"
    WHERE="${TOOLS}/${JDK_VERSION}"
    DEPTH=3
  else
    warn "PSRV did not indicate which JDK version to use for $PROCESS_ID on $SYSTEM. Maybe a JDK is missing or the GUI is wrongly configured."
    DEPTH=4
  fi

  log "Looking in tools directory: $WHERE"
  if [[ -d ${WHERE} ]]; then
    local EXE
    EXE=$(find "${WHERE}" -maxdepth ${DEPTH} -name $JAVA_EXE | head -1)
    if [[ -f ${EXE} ]]; then
      log "Found java in $EXE"
      JAVA=${EXE}
      return
    fi
    log "Java not found in $TOOLS"
  else
    log "Tools directory does not exist: $TOOLS"
  fi

  rm -rf "${TOOLS:-xxx}/$JDK_VERSION"
  mkdir -p "$TOOLS/$JDK_VERSION"
  local ARCHIVE
  ARCHIVE=$(cd "$TOOLS/$JDK_VERSION" && curl -fSOJ -w '%{filename_effective}' "${URL}/api/tools/archive/jdk?system=${SYSTEM}&version=${JDK_VERSION}" | tail -1)
  if [[ $? = 0 ]] && [[ -n "$ARCHIVE" ]]; then
    log "Downloaded $ARCHIVE"
    extract "$TOOLS/$JDK_VERSION/$ARCHIVE" "$TOOLS/$JDK_VERSION"
    rm -f "$TOOLS/$JDK_VERSION/$ARCHIVE"
  fi

  local EXE
  EXE=$(find "$TOOLS/$JDK_VERSION" -maxdepth ${DEPTH} -not -path "*jre*" -name $JAVA_EXE | head -1)
  if [[ -f ${EXE} ]]; then
    log "Found java in $EXE"
    JAVA_HOME=$(dirname "$(dirname "$EXE")")
    PATH="$PATH:$JAVA_HOME/bin"
    log "JAVA_HOME set to $JAVA_HOME"
    JAVA=${EXE}
    return
  fi

  warn "Java not found in $TOOLS. Will look in JAVA_HOME and PATH"
  return 4
}

# The goal of this method is to set the variable JAVA to a working java executable
# Usage:
#   find_or_install_java <tools_dir>
find_or_install_java() {
  local ROOT_DIR="$1"
  local PROCESS_ID=$1
  if [[ -x ${JAVA} ]]; then
    log "Using JAVA=$JAVA"
    return
  else
    log "Looking for java executable (JAVA environment variable not set)"
  fi

  _find_java_in_tools ${ROOT_DIR} ${PROCESS_ID}
  if [[ -n ${JAVA} ]]; then return; fi

  if [[ ${JAVA_HOME} != "" ]]; then
    JAVA=$(echo "${JAVA_HOME}/bin/java" | sed 's/\\\\/\//g')
    if [[ -x ${JAVA} ]]; then
      _extract_java_version
      log "Found in JAVA_HOME: ${JAVA} - JDK_VERSION=${JDK_VERSION}"
      return
    fi
  fi

  log "Looking in PATH"
  JAVA=$(type -P java)
  if [[ -x ${JAVA} ]]; then
    _extract_java_version
    log "Java found in PATH: ${JAVA} - JDK_VERSION=${JDK_VERSION}"
    return
  fi

  err "Java not found in PATH"
}

# Guess the java version (8, 9, 10, ...) by running $JAVA -version
_extract_java_version() {
  JDK_VERSION=$("$JAVA" -version 2>&1 | sed -ne 's/.*version "\(.*\)".*/\1/gp' | sed -e 's/^1\.//g' -e 's/\..*//g')
}

# replace values before execution
# When downloaded from the PSRV, XXX_* is substituted dynamically by PSRV (HOST is
# extracted from the Host Header, PORT and URL come from PSRV configuration)
HOST=${HOST:-192.168.149.16}
PORT=${PORT:-8085}
URL=${URL:-http://192.168.149.16:8085}
USE_HTTPS=${USE_HTTPS:-false}

mkdir -p ${LAUNCHER_HOME}
cd ${LAUNCHER_HOME}

PROCESS_ID=GUI
if [[ -f "processId" ]]; then
  PROCESS_ID=$(cat processId)
fi

find_or_install_java ${PROCESS_ID}
if [[ -z ${JAVA} ]]; then
  err "Java not found"
  exit 2
fi

log "Downloading launcher jar"
download ${URL}/api/download/launcher.jar ${LAUNCHER_HOME}/launcher.jar

"${JAVA}" -jar launcher.jar -host ${HOST} -port ${PORT} -useHttps ${USE_HTTPS} -network default