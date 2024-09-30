#!/bin/bash

# Check if the organization name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <organization-name>"
    exit 1
fi

ORG_NAME="$1"

# Function to search for S3 buckets
search_s3_buckets() {
    local org="$1"
    echo "Searching for 's3.amazonaws.com' in organization: $org"
    
    # Fetch all repositories in the organization
    repos=$(gh repo list "$org" --json nameWithOwner -q '.[].nameWithOwner')

    # Initialize an array to store found S3 buckets
    found_buckets=()

    # Loop through each repository
    for repo in $repos; do
        echo "Scanning repository: $repo"
        # Use the GitHub API to fetch files and search for the S3 pattern
        # List all files in the repository
        files=$(gh repo view "$repo" --json object -q '.object.entries[].name')
        
        # Loop through each file
        for file in $files; do
            # Fetch the file content and search for S3 URL
            content=$(gh api repos/"$repo"/contents/"$file" | jq -r '.content' | base64 --decode)
            if echo "$content" | grep -q "s3.amazonaws.com"; then
                bucket_url="https://$repo/$file"
                found_buckets+=("$bucket_url")
                echo "Found S3 bucket in $repo: $bucket_url"
            fi
        done
    done

    # Summary of found buckets
    if [ ${#found_buckets[@]} -eq 0 ]; then
        echo "✅ No S3 buckets found."
    else
        echo "🚨 **S3 Buckets Found** 🚨"
        for bucket in "${found_buckets[@]}"; do
            echo "- $bucket"
        done
        echo "**Total S3 Buckets Found:** ${#found_buckets[@]}"
    fi
}

# Call the function with the organization name
search_s3_buckets "$ORG_NAME"
