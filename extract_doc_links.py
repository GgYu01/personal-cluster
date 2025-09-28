# This script downloads HTML content from a list of URLs, saves each as a .html file,
# aggregates all unique, absolute hyperlinks from all pages, and saves them to a single
# consolidated file named 'all_docs_links.txt'.

import os
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse

# --- Configuration ---
URLS_TO_PROCESS = [
    # K3s 文档根
    "https://docs.k3s.io/",

    # Traefik 文档根
    "https://doc.traefik.io/traefik/",

    # cert-manager 文档根
    "https://cert-manager.io/docs/",

    # Argo CD 文档根
    "https://argo-cd.readthedocs.io/en/stable/",

    # ArtifactHub（如你本地可抓取其 Values 渲染）
    "https://artifacthub.io/packages/helm/argo/argo-cd/",
    "https://artifacthub.io/packages/helm/traefik/traefik/",
    "https://artifacthub.io/packages/helm/goauthentik/authentik/",

    # Cloudflare API 根
    "https://developers.cloudflare.com/api/",

    # Let’s Encrypt 文档根
    "https://letsencrypt.org/docs/",

    # Authentik 文档根
    "https://docs.goauthentik.io/",

    # FRP 仓库根（如需其它子文档）
    "https://github.com/fatedier/frp/",
]

# Directory to save all output files
OUTPUT_DIR = "official_docs_bundle"

# Consolidated file for all extracted links
ALL_LINKS_FILE = os.path.join(OUTPUT_DIR, "all_docs_links.txt")

# User-Agent to mimic a real browser
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36'
}

# --- Main Logic ---

def generate_safe_filename(url):
    """Create a filesystem-safe filename from a URL."""
    parsed = urlparse(url)
    # Combine network location and path, replacing slashes
    filename = f"{parsed.netloc}{parsed.path.replace('/', '_')}".rstrip('_')
    # Fallback for empty paths
    if not filename:
        return f"root_{parsed.netloc}"
    return filename

def process_url(url, output_dir):
    """
    Downloads a URL, saves its HTML, and returns a set of all absolute links found.
    Returns: A set of unique absolute URLs, or an empty set on failure.
    """
    print(f"--> Processing URL: {url}")
    
    try:
        # Step 1: Download the page content
        response = requests.get(url, headers=HEADERS, timeout=20)
        response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)
        
        # Step 2: Prepare HTML file path
        filename_base = generate_safe_filename(url)
        html_filepath = os.path.join(output_dir, f"{filename_base}.html")
        
        # Step 3: Save the HTML content
        with open(html_filepath, 'w', encoding='utf-8') as f:
            f.write(response.text)
        print(f"    Saved HTML to: {html_filepath}")

        # Step 4: Parse HTML and extract links
        soup = BeautifulSoup(response.text, 'lxml')
        found_links = set()

        for a_tag in soup.find_all('a', href=True):
            href = a_tag['href'].strip()
            if not href or href.startswith(('javascript:', 'mailto:', '#')):
                continue

            # Convert relative URLs to absolute ones
            absolute_url = urljoin(url, href)
            
            # Clean the URL by removing the fragment part (e.g., #section-id)
            parsed_absolute = urlparse(absolute_url)
            clean_url = parsed_absolute._replace(fragment='').geturl()
            
            # Only add valid HTTP/HTTPS links
            if clean_url.startswith(('http://', 'https://')):
                found_links.add(clean_url)
        
        print(f"    Extracted {len(found_links)} unique links from this page.\n")
        return found_links

    except requests.RequestException as e:
        print(f"    [ERROR] Failed to process {url}. Reason: {e}\n")
        return set()

if __name__ == "__main__":
    # Create the output directory if it doesn't exist
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Created output directory: {OUTPUT_DIR}\n")
    
    # Set to accumulate all links from all pages
    all_extracted_links = set()
    
    for url in URLS_TO_PROCESS:
        links_from_url = process_url(url, OUTPUT_DIR)
        all_extracted_links.update(links_from_url)
        
    # After processing all URLs, write the consolidated links to a single file
    if all_extracted_links:
        print(f"Writing {len(all_extracted_links)} total unique links to {ALL_LINKS_FILE}...")
        with open(ALL_LINKS_FILE, 'w', encoding='utf-8') as f:
            # Sort the links for consistent and readable output
            for link in sorted(list(all_extracted_links)):
                f.write(link + '\n')
    
    print("==================================================")
    print("Processing complete.")
    print(f"All files are located in the '{OUTPUT_DIR}' directory.")