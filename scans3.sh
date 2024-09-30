#!/bin/bash

# Check if the organization name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <organization-name>"
    exit 1
fi

ORG_NAME="$1"

# ANSI color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"  # No Color

# Function to search for S3 buckets in the organization
search_s3_buckets() {
    local org="$1"
    echo "Searching for 's3.amazonaws.com' in organization: $org"

    # Perform a search for the S3 bucket pattern
    search_results=$(gh search code "s3.amazonaws.com org:$org" --limit 100)

    # Check if any results were found
    if [ -z "$search_results" ]; then
        echo "✅ No S3 buckets found."
        return
    fi

    echo "🚨 **S3 Bucket URLs Found** 🚨"
    # Extract URLs and format them
    urls=($(echo "$search_results" | grep -o 'https\?://[^ ]*s3.amazonaws.com[^ ]*' | awk -F'/' '{print $1 "//" $3 "/" $4 "/" $5}' | sort -u))

    # Categorize URLs based on their status codes
    claimed=()
    unclaimed=()

    # Function to check URL status and categorize
    check_url() {
        url=$1
        status_code=$(curl -o /dev/null -s -w "%{http_code}" "$url")
        
        if [ "$status_code" -eq 200 ]; then
            claimed+=("$url")
        elif [ "$status_code" -eq 404 ]; then
            unclaimed+=("$url")
        fi
    }
    export -f check_url

    # Use xargs to run curl in parallel for faster processing
    printf "%s\n" "${urls[@]}" | xargs -n 1 -P 10 -I {} bash -c 'check_url "$@"' _ {}

    # Print categorized results
    echo -e "✅ **Results** ✅"
    echo -e "${GREEN}Claimed URLs (200):${NC}"
    for url in "${claimed[@]}"; do
        echo -e "- $GREEN$url${NC}"
    done

    echo -e "${RED}Unclaimed URLs (404):${NC}"
    for url in "${unclaimed[@]}"; do
        echo -e "- $RED$url${NC}"
    done
}

# Call the function with the organization name
search_s3_buckets "$ORG_NAME"
