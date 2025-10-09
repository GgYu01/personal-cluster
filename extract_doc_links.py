# This script downloads HTML content from a list of URLs, saves each as a .html file,
# aggregates all unique, absolute hyperlinks from all pages, and saves them to a single
# consolidated file named 'all_docs_links.txt'.

import os
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse

# --- Configuration ---
URLS_TO_PROCESS = [
    "https://github.com/k3s-io/k3s/releases/tag/v1.33.3+k3s1", 
    "https://docs.k3s.io/helm", 

    # -- K3s: 安装、配置、外置数据存储、网络 --
    "https://docs.k3s.io/installation",
    "https://docs.k3s.io/installation/configuration",
    "https://docs.k3s.io/datastore",
    "https://docs.k3s.io/networking",
    "https://github.com/k3s-io/helm-controller",

    # -- Traefik: Kubernetes CRD, IngressRoute/TCP, EntryPoints/TLS, Helm Chart --
    "https://doc.traefik.io/traefik/",
    "https://doc.traefik.io/traefik/providers/kubernetes-crd/",
    "https://doc.traefik.io/traefik/routing/routers/",
    "https://doc.traefik.io/traefik/routing/entrypoints/",
    "https://doc.traefik.io/traefik/https/tls/",
    "https://github.com/traefik/traefik-helm-chart/tree/master/traefik",
    "https://github.com/traefik/traefik-helm-chart/blob/master/traefik/values.yaml",

    # -- cert-manager: 安装、ACME DNS-01、Cloudflare、故障排查、概念 --
    "https://cert-manager.io/docs/",
    "https://cert-manager.io/docs/installation/helm/",
    "https://cert-manager.io/docs/configuration/acme/",
    "https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/",
    "https://cert-manager.io/docs/troubleshooting/acme/",
    "https://cert-manager.io/docs/usage/certificate/",

    # -- Let's Encrypt: 频率限制 --
    "https://letsencrypt.org/docs/rate-limits/",

    # -- Cloudflare API v4: Zone 和 DNS Records --
    "https://developers.cloudflare.com/api/",
    "https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-list-dns-records",
    "https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-create-dns-record",
    "https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-update-dns-record",

    # -- Argo CD: Chart、声明式应用、同步波次/依赖、Ingress --
    "https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd",
    "https://argo-cd.readthedocs.io/en/stable/",
    "https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/",
    "https://argo-cd.readthedocs.io/en/stable/user-guide/application_dependencies/",
    "https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/",

    # -- FRP: frps 配置、子域/HTTP vhost、版本 --
    "https://gofrp.org/",
    "https://gofrp.org/docs/reference/server-configures/",
    "https://gofrp.org/docs/features/http/",
    "https://github.com/fatedier/frp/releases",

    # -- MetalLB: 安装与配置（如后续需要） --
    "https://metallb.universe.tf/",
    "https://metallb.universe.tf/installation/",
    "https://metallb.universe.tf/configuration/",

    # -- Authentik: 文档与 Helm Chart --
    "https://docs.goauthentik.io/",
    "https://docs.goauthentik.io/docs/installation/kubernetes/",
    "https://docs.goauthentik.io/docs/installation/kubernetes/helm-chart/",
    "https://charts.goauthentik.io/",
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