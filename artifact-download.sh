#!/bin/bash

# Configuration
ARTIFACT_URL="https://artifactory.yourdomain.com/artifactory/repo-name/path/to/artifact.zip"
REGION="AMER" # Change per region
LOG_FILE="/var/log/artifact_download.log"
DEST_FILE="/tmp/artifact.zip"

# Timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Download & measure time
START=$(date +%s%N)
curl -o $DEST_FILE -s -w "%{http_code}" $ARTIFACT_URL
END=$(date +%s%N)

# Duration in seconds
DURATION=$(echo "scale=3; ($END - $START)/1000000000" | bc)

# Log the result
echo "$TIMESTAMP | Region: $REGION | Time: ${DURATION}s" >> $LOG_FILE

# Optional: delete file to save space
rm -f $DEST_FILE
