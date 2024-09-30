#!/bin/bash

# Check if the organization name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <organization-name>"
    exit 1
fi

ORG_NAME="$1"

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

# Function to search for S3 buckets in the organization
search_s3_buckets() {
    local org="$1"
    echo "Searching for 's3.amazonaws.com' in organization: $org"

    # Perform a search for the S3 bucket pattern
    search_results=$(gh search code "s3.amazonaws.com org:$org" --limit 100)

    # Check if any results were found
    if [ -z "$search_results" ]; then
        echo "✅ No S3 buckets found."
    else
        echo "🚨 **S3 Bucket URLs Found** 🚨"

        # Initialize arrays to store claimed and unclaimed buckets
        claimed_buckets=()
        unclaimed_buckets=()
        
        # Extract and check the status of URLs containing s3.amazonaws.com
        echo "$search_results" | grep -o 'https\?://[^ ]*s3.amazonaws.com[^ ]*' | \
        awk -F'/' '{print $1 "//" $3 "/" $4 }' | sort -u | while read -r url; do
            # Perform a HEAD request to check the status code
            status_code=$(curl -o /dev/null -s -w "%{http_code}" "$url" 2>/dev/null)

            # Check if the curl command succeeded
            if [[ $? -ne 0 ]]; then
                echo "⚠️ Error retrieving URL: $url"
                continue
            fi
            
            # Categorize based on the status code
            if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 403 ]; then
                claimed_buckets+=("$url")
            elif [ "$status_code" -eq 404 ]; then
                unclaimed_buckets+=("$url")
            else
                echo "🔍 Found URL: $url with status code: $status_code"
            fi
        done

        # Print the categorized buckets
        if [ ${#claimed_buckets[@]} -gt 0 ]; then
            echo -e "${GREEN}✅ **Claimed Buckets (200/403)** ✅${RESET}"
            for bucket in "${claimed_buckets[@]}"; do
                echo "- $bucket"
            done
        else
            echo "No claimed buckets found."
        fi

        if [ ${#unclaimed_buckets[@]} -gt 0 ]; then
            echo -e "${RED}🚫 **Unclaimed Buckets (404)** 🚫${RESET}"
            for bucket in "${unclaimed_buckets[@]}"; do
                echo "- $bucket"
            done
        else
            echo "No unclaimed buckets found."
        fi
    fi
}

# Call the function with the organization name
search_s3_buckets "$ORG_NAME"
