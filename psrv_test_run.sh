#!/bin/bash

# Default environment
ENV_NAME="LIME"

# Function to update the psrv.zip
update_psrv() {
    cd "/home/jks/test_psrv" || exit

    echo "Start download of psrv zip"
    curl --fail --ssl-reqd -o psrv.zip "https://psrv.pages.hsoftware.com/fmk2-psrv/psrv-latest-build.zip"
    if [ $? -ne 0 ]; then
        echo "Failed to download psrv.zip"
        exit 1
    fi

    unzip -u psrv.zip

    rm psrv.zip

    # Check and delete the existing psrv-all.jar if it exists
    if [ -f psrv-all.jar ]; then
        rm psrv-all.jar
        echo "Deleted existing psrv-all.jar"
        echo "Successfully deleted the old version of psrv jar 👴🏻 ......... . 🔫"
    fi

    # Find the JAR file and rename it
    JAR_FILE=$(find . -name 'psrv*.jar' | head -n 1)
    if [ -z "$JAR_FILE" ]; then
        echo "No JAR file found after unzipping"
        exit 1
    fi

    mv "$JAR_FILE" psrv-all.jar

    echo "JAR file renamed to psrv-all.jar"
    echo "Update complete....🍺  🍺    🍺   🍺      🍺         🍺"
}

# Handle arguments
if [ $# -eq 0 ]; then
    # No arguments provided, run with default environment
    echo "No arguments provided. Running with default environment: LIME"
else
    ARG=$1

    if [ "$ARG" == "-u" ]; then
        update_psrv
        exit 0
    elif [ "$ARG" == "lme" ]; then
        ENV_NAME="LMEUK-STAGING"
    else
        echo "Invalid argument: $ARG"
        exit 1
    fi
fi

cd "/home/jks/test_psrv" || exit

# Run the Java application
java -Xmx4g -DredirectOutput=false -Dpsrv.preferNetInterface=en0 -Dlogging.impl=async -jar psrv-all.jar \
    -env "$ENV_NAME" \
    -setup DEVELOPMENT \
    -artifactoryHost artifactory.hsoftware.com
