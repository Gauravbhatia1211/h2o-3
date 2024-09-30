#!/bin/bash

# Function to handle rate limiting
handle_rate_limit() {
    echo "Rate limit exceeded. Waiting for $1 seconds..."
    sleep "$1"
}

# Updated function to search for S3 buckets in the organization with backoff
search_s3_buckets_with_backoff() {
    local org="$1"
    local delay=30  # Start with a 30-second delay

    while true; do
        echo "Searching for 's3.amazonaws.com' in organization: $org"
        search_results=$(gh api "search/code?q=s3.amazonaws.com+org:$org" --header "Authorization: token $GITHUB_TOKEN" --silent)

        if [[ $? -eq 0 ]]; then
            # Check if any results were found
            if [[ -z "$search_results" ]]; then
                echo "✅ No S3 buckets found."
            else
                echo "🚨 **S3 Bucket URLs Found** 🚨"
                # Process search results as needed...
            fi
            break  # Exit loop if search was successful
        else
            # Check for rate limit errors and wait if necessary
            if echo "$search_results" | grep -q "HTTP 403"; then
                handle_rate_limit "$delay"
                delay=$((delay * 2))  # Exponentially increase the wait time
            else
                echo "An unexpected error occurred: $search_results"
                break
            fi
        fi
    done
}

# Call the function with the organization name
search_s3_buckets_with_backoff "$ORG_NAME"
