import os
import sys
import re
import requests
import time
from github import Github

# Initialize GitHub client
github_token = os.getenv("GITHUB_TOKEN")
if not github_token:
    raise EnvironmentError("GITHUB_TOKEN is not set.")

g = Github(github_token)

# Get organization name from command-line argument
if len(sys.argv) < 2:
    raise ValueError("Organization name is required as an argument")
ORG_NAME = sys.argv[1]

# Regex pattern to find S3 URLs
S3_PATTERN = re.compile(r'https?://([a-z0-9\-_]+)\.s3\.amazonaws\.com', re.IGNORECASE)

# Function to check S3 bucket status
def check_s3_bucket(bucket_url):
    print(f"Checking status of bucket: {bucket_url}")
    start_time = time.time()
    try:
        response = requests.head(bucket_url, timeout=10)
        elapsed_time = time.time() - start_time
        print(f"Response status for {bucket_url}: {response.status_code} (Time: {elapsed_time:.2f}s)")
        if response.status_code == 404:
            return "Unclaimed"
        elif response.status_code == 403:
            return "Claimed (Forbidden)"
        elif response.status_code == 200:
            return "Claimed (Accessible)"
        else:
            return f"Unknown Status ({response.status_code})"
    except requests.RequestException as e:
        return f"Error: {e}"

def main():
    print(f"Starting scan for organization: {ORG_NAME}")
    start_time = time.time()
    org = g.get_organization(ORG_NAME)
    
    # Fetch repos
    print("Fetching repositories...")
    repos = org.get_repos()
    print(f"Found {repos.totalCount} repositories")

    total_buckets = 0
    unclaimed_buckets = []
    repo_count = 0

    # Iterate over repositories
    for repo in repos:
        repo_start_time = time.time()
        repo_count += 1
        print(f"\nScanning repository {repo_count}/{repos.totalCount}: {repo.full_name}")

        try:
            contents = repo.get_contents("")
            while contents:
                file_content = contents.pop(0)

                if file_content.type == "dir":
                    print(f"Entering directory: {file_content.path}")
                    contents.extend(repo.get_contents(file_content.path))
                elif file_content.type == "file":
                    if file_content.size > 5 * 1024 * 1024:  # Skip files larger than 5MB
                        print(f"Skipping large file: {file_content.path} (Size: {file_content.size} bytes)")
                        continue
                    try:
                        print(f"Processing file: {file_content.path}")
                        file_data = file_content.decoded_content.decode('utf-8', errors='ignore')
                        matches = S3_PATTERN.findall(file_data)
                        if matches:
                            print(f"Found {len(matches)} S3 bucket(s) in {file_content.path}")
                        for bucket in matches:
                            bucket_url = f"https://{bucket}.s3.amazonaws.com"
                            status = check_s3_bucket(bucket_url)
                            total_buckets += 1
                            if status.startswith("Unclaimed"):
                                unclaimed_buckets.append((bucket, repo.full_name, bucket_url))
                    except Exception as e:
                        print(f"Error reading file {file_content.path}: {e}")
        except Exception as e:
            print(f"Error accessing repository {repo.full_name}: {e}")

        repo_elapsed_time = time.time() - repo_start_time
        print(f"Finished scanning repository {repo.full_name} (Time: {repo_elapsed_time:.2f}s)")

    # Calculate total elapsed time
    total_elapsed_time = time.time() - start_time
    print(f"\nTotal scan completed in {total_elapsed_time:.2f}s")

    # Prepare output message
    if unclaimed_buckets:
        message = "🚨 **Unclaimed S3 Buckets Found** 🚨\n\n"
        for bucket, repo_name, url in unclaimed_buckets:
            message += f"- **Bucket:** `{bucket}`\n  **Repository:** `{repo_name}`\n  **URL:** {url}\n"
        message += f"\n**Total Buckets Scanned:** {total_buckets}\n**Unclaimed Buckets Found:** {len(unclaimed_buckets)}"
    else:
        message = f"✅ **S3 Bucket Scan Complete** ✅\n\nNo unclaimed S3 buckets found.\n\n**Total Buckets Scanned:** {total_buckets}"

    print(message)

if __name__ == "__main__":
    main()
