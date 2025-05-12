#!/bin/bash

# Set log file location
HOME_DIR=$HOME
LOG_FILE="$HOME_DIR/build_and_deploy.log"

source ~/flon.env

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Parse args
BUILD_CHAIN=false
BUILD_CDT=false
BUILD_SCAN=false
BUILD_DEB=false
DO_BUILD=false
DO_PUSH=false

for arg in "$@"; do
    case $arg in
        chain) BUILD_CHAIN=true ;;
        cdt) BUILD_CDT=true ;;
        scan) BUILD_SCAN=true ;;
        deb) BUILD_DEB=true ;;
        build) DO_BUILD=true ;;
        push) DO_PUSH=true ;;
        build_push|bp) DO_BUILD=true; DO_PUSH=true ;;
        all)
            BUILD_CHAIN=true
            BUILD_CDT=true
            BUILD_SCAN=true
            BUILD_DEB=true
            DO_BUILD=true
            DO_PUSH=true ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# If no args, do everything
if [ "$#" -eq 0 ]; then
    BUILD_CHAIN=true
    BUILD_CDT=true
    BUILD_SCAN=true
    BUILD_DEB=true
    DO_BUILD=true
    DO_PUSH=true
fi

if [ "$DO_PUSH" = true ]; then
    if [ ! -f "$HOME_DIR/ghcr.txt" ]; then
        log "Error: ghcr.txt not found"
        exit 1
    fi
fi

if [ "$BUILD_DEB" = true ]; then
    if ! command -v ossutil &> /dev/null; then
        log "Error: ossutil not installed"
        exit 1
    fi
    if [ ! -f "$HOME_DIR/.ossutilconfig" ]; then
        log "Error: .ossutilconfig not found"
        exit 1
    fi
fi

log "Starting build and deployment process"
log "Home directory: $HOME_DIR"

# ----------- Version Helpers -----------
get_version_from_cmake() {
    local url="$1"
    local content
    content=$(curl -s "$url")

    local major minor patch suffix

    # Extract major, minor, and patch versions
    major=$(echo "$content" | grep -Po 'set\s*\(\s*VERSION_MAJOR\s+\K[0-9]+')
    minor=$(echo "$content" | grep -Po 'set\s*\(\s*VERSION_MINOR\s+\K[0-9]+')
    patch=$(echo "$content" | grep -Po 'set\s*\(\s*VERSION_PATCH\s+\K[0-9]+')

    # Extract suffix, handling both quoted and unquoted values without capturing ')'
    suffix=$(echo "$content" | grep -Po 'set\s*\(\s*VERSION_SUFFIX\s+(?:"\K[^"]*|\K[^)\s]+)')

    # Combine into full version string (only append suffix if it exists)
    if [ -n "$suffix" ]; then
        echo "${major}.${minor}.${patch}-${suffix}"
    else
        echo "${major}.${minor}.${patch}"
    fi
}

check_version() {
    local name="$1"
    local url="$2"
    local expected="$3"

    local actual
    actual=$(get_version_from_cmake "$url")
    echo "$name version: $actual"

    if [ "$actual" != "$expected" ]; then
        log "Error: $name version mismatch. Expected $expected, but found $actual"
        exit 1
    fi
}

check_all_versions() {
    log "Checking all versions before starting..."

    if [ "$BUILD_CHAIN" = true ]; then
        check_version "flon.chain" "https://raw.githubusercontent.com/fullon-labs/flon-core/main/CMakeLists.txt" "$FULLON_VERSION"
    fi

    if [ "$BUILD_CDT" = true ]; then
        check_version "flon.cdt" "https://raw.githubusercontent.com/fullon-labs/flon.cdt/main/CMakeLists.txt" "$CDT_VERSION"
    fi

    if [ "$BUILD_SCAN" = true ]; then
        check_version "flon.history (scan)" "https://raw.githubusercontent.com/fullon-labs/history-tools/refs/heads/master/CMakeLists.txt" "$HISTORY_VERSION"
    fi
}


# Call before build
check_all_versions
PROJ_DIR="$HOME_DIR/flon-docker"
# ----------- Build & Push Logic -----------

if [ "$BUILD_CHAIN" = true ]; then
    log "Processing flon.chain..."
    cd "$PROJ_DIR/flon.chain/node-build/" || { log "Error: cd flon.chain/node-build failed"; exit 1; }

    if [ "$DO_BUILD" = true ]; then
        log "Building flon.chain..."
        ./build.sh >> "$LOG_FILE" 2>&1 || { log "Error: flon.chain build.sh failed"; exit 1; }
        log "flon.chain build complete"
    fi

    if [ "$DO_PUSH" = true ]; then
        log "Pushing flon.chain..."
        ./docker_push.sh >> "$LOG_FILE" 2>&1 || { log "Error: flon.chain docker_push.sh failed"; exit 1; }
        log "flon.chain push complete"
    fi
fi

if [ "$BUILD_CDT" = true ]; then
    log "Processing flon.cdt..."
    cd "$PROJ_DIR/flon.cdt" || { log "Error: cd flon.cdt failed"; exit 1; }

    if [ "$DO_BUILD" = true ]; then
        log "Building flon.cdt..."
        ./build-cdt-docker.sh >> "$LOG_FILE" 2>&1 || { log "Error: flon.cdt build failed"; exit 1; }
        log "flon.cdt build complete"
    fi

    if [ "$DO_PUSH" = true ]; then
        log "Pushing flon.cdt..."
        ./docker_push.sh >> "$LOG_FILE" 2>&1 || { log "Error: flon.cdt push failed"; exit 1; }
        log "flon.cdt push complete"
    fi
fi

if [ "$BUILD_SCAN" = true ]; then
    log "Processing flon.scan..."
    cd "$PROJ_DIR/flon.scan/docker-build/" || { log "Error: cd flon.scan failed"; exit 1; }

    if [ "$DO_BUILD" = true ]; then
        log "Building flon.scan..."
        ./build.sh >> "$LOG_FILE" 2>&1 || { log "Error: flon.scan build failed"; exit 1; }
        log "flon.scan build complete"
    fi

    if [ "$DO_PUSH" = true ]; then
        log "Pushing flon.scan..."
        ./docker_push.sh >> "$LOG_FILE" 2>&1 || { log "Error: flon.scan push failed"; exit 1; }
        log "flon.scan push complete"
    fi
fi

if [ "$BUILD_DEB" = true ]; then
    log "Generating and uploading DEB packages..."
    cd "$PROJ_DIR/flon.chain/node-build-deb/" || { log "Error: cd node-build-deb failed"; exit 1; }

    ./get_fullon_cdt_deb.sh >> "$LOG_FILE" 2>&1 || { log "Error: get_fullon_cdt_deb.sh failed"; exit 1; }
    ./get_fullon_deb.sh >> "$LOG_FILE" 2>&1 || { log "Error: get_fullon_deb.sh failed"; exit 1; }

    log "DEB packages uploaded successfully"
fi

log "✅ All selected build and deployment processes completed successfully"
