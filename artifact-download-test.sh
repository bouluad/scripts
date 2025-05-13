#!/bin/bash

# Configuration
REGION="AMER"  # Change per VM
LOG_FILE="/var/log/artifact_download.log"
DEST_DIR="/tmp/artifact_download_test"
ARTIFACT_URL_SLB="https://artifactory-slb.domain.com/artifactory/repo/path/to/artifact.zip"
ARTIFACT_URL_DIRECT="https://artifactory-backend-01.domain.local/artifactory/repo/path/to/artifact.zip"

# Prepare destination directory
mkdir -p $DEST_DIR

download_and_measure() {
  local URL=$1
  local LABEL=$2
  local FILENAME="$DEST_DIR/${LABEL}_artifact.zip"

  START=$(date +%s%N)
  curl -s -o "$FILENAME" -w "%{http_code}" "$URL" > /dev/null
  END=$(date +%s%N)

  DURATION=$(echo "scale=3; ($END - $START)/1000000000" | bc)
  echo "$LABEL | ${DURATION}s"
  rm -f "$FILENAME"

  echo "$DURATION"
}

# Timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Download via SLB
DURATION_SLB=$(download_and_measure "$ARTIFACT_URL_SLB" "via_SLB")

# Download directly to backend
DURATION_DIRECT=$(download_and_measure "$ARTIFACT_URL_DIRECT" "direct_backend")

# Log the result
echo "$TIMESTAMP | Region: $REGION | SLB: ${DURATION_SLB}s | Direct: ${DURATION_DIRECT}s" >> $LOG_FILE
