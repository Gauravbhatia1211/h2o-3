import os
import sys
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

# Search for s3.amazonaws.com in the organization's repositories
def search_s3_buckets(org_name):
    print(f"Searching for 's3.amazonaws.com' in organization: {org_name}")
    query = f's3.amazonaws.com org:{org_name}'
    
    s3_buckets = []
    page = 0

    while True:
        # Fetch search results with pagination
        search_results = g.search_code(query, page=page, per_page=100)
        if search_results.totalCount == 0:
            print("No more results found.")
            break

        for result in search_results:
            url = result.html_url
            path = result.path
            print(f"Found in {result.repository.full_name}: {url} (File: {path})")
            s3_buckets.append(url)

        if len(search_results) < 100:  # Less than requested means no more pages
            break
        page += 1

    return s3_buckets

def main():
    s3_buckets = search_s3_buckets(ORG_NAME)

    # Output found S3 buckets
    if s3_buckets:
        print("\n🚨 **S3 Buckets Found** 🚨")
        for bucket in s3_buckets:
            print(f"- {bucket}")
        print(f"\n**Total S3 Buckets Found:** {len(s3_buckets)}")
    else:
        print("✅ No S3 buckets found.")

if __name__ == "__main__":
    main()
