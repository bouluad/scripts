#!/bin/bash

# Configuration
REGION="AMER"  # Change for each region
LOG_FILE="/var/log/artifact_download.log"
DEST_DIR="/tmp/artifact_download_test"
ARTIFACT_URL_SLB="https://artifactory-slb.domain.com/artifactory/repo/path/to/artifact.zip"
ARTIFACT_URL_DIRECT="https://artifactory-backend-01.domain.local/artifactory/repo/path/to/artifact.zip"

mkdir -p "$DEST_DIR"

download_and_time() {
  local URL=$1
  local LABEL=$2
  local FILENAME="$DEST_DIR/${LABEL}_artifact.zip"

  TIME_TOTAL=$(curl -o "$FILENAME" -s -w "%{time_total}" "$URL")
  rm -f "$FILENAME"

  echo "$LABEL | ${TIME_TOTAL}s"
  echo "$TIME_TOTAL"
}

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

DURATION_SLB=$(download_and_time "$ARTIFACT_URL_SLB" "via_SLB")
DURATION_DIRECT=$(download_and_time "$ARTIFACT_URL_DIRECT" "direct_backend")

echo "$TIMESTAMP | Region: $REGION | SLB: ${DURATION_SLB}s | Direct: ${DURATION_DIRECT}s" >> "$LOG_FILE"
