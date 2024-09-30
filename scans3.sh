#!/bin/bash

# Check if the organization name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <organization-name>"
    exit 1
fi

ORG_NAME="$1"

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
        echo "🚨 **S3 Buckets Found** 🚨"
        echo "$search_results" | while read -r line; do
            echo "- $line"
        done
    fi
}

# Call the function with the organization name
search_s3_buckets "$ORG_NAME"
