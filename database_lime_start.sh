#!/bin/bash

# Default path for LIME database
DB_PATH="/home/jks/projects/LIME/launcher/database"

# Log function for output messages
log_info() {
    echo "[INFO] $1"
}

# Check for arguments
if [ $# -eq 0 ]; then
    # No argument provided
    log_info "No argument provided. Using default path for LIME database."
    cd "$DB_PATH" || exit
    log_info "Navigated to: $DB_PATH"
    ./startDatabase.sh
    log_info "LIME database script executed."
else
    # Argument provided
    ARG=$1
    if [ "$ARG" == "lme" ]; then
        # Path for LMEUK database
        DB_PATH="/home/jks/projects/LMEUK/launcher/"
        log_info "Argument 'lme' provided. Using path for LMEUK database."
        cd "$DB_PATH" || exit
        log_info "Navigated to: $DB_PATH"
        ./startDatabase.sh
        log_info "LMEUK database script executed."
    else
        log_info "Invalid argument: $ARG. Only 'lme' is supported."
        exit 1
    fi
fi
