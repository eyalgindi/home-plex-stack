#!/bin/bash

# ============================================================================
# Home Plex Entertainment Stack - Setup Script
# ============================================================================
# This script guides you through the configuration of the entertainment stack
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
ENV_EXAMPLE="${SCRIPT_DIR}/env.example"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for dry-run mode
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]] || [[ "${1:-}" == "-n" ]]; then
    DRY_RUN=true
    print_info "DRY RUN MODE: No files will be created, no containers will be started"
    echo
fi

# ============================================================================
# Validation Functions
# ============================================================================

# Validate IP address
validate_ip() {
    local ip="$1"
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    IFS='.' read -ra ADDR <<< "$ip"
    for i in "${ADDR[@]}"; do
        if [[ $i -gt 255 ]]; then
            return 1
        fi
    done
    return 0
}

# Validate CIDR subnet
validate_cidr() {
    local cidr="$1"
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 1
    fi
    local subnet=$(echo "$cidr" | cut -d'/' -f1)
    local mask=$(echo "$cidr" | cut -d'/' -f2)
    if ! validate_ip "$subnet"; then
        return 1
    fi
    if [[ $mask -lt 8 ]] || [[ $mask -gt 30 ]]; then
        return 1
    fi
    return 0
}

# Validate email address
validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Validate URL
validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]; then
        return 1
    fi
    return 0
}

# Validate domain name
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    return 0
}

# Validate port number
validate_port() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ $port -lt 1 ]] || [[ $port -gt 65535 ]]; then
        return 1
    fi
    return 0
}

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local is_secret="${4:-false}"
    
    if [ "$is_secret" = "true" ]; then
        read -sp "${prompt} [default: ${default}]: " input
        echo
    else
        read -p "${prompt} [default: ${default}]: " input
    fi
    
    if [ -z "$input" ]; then
        input="$default"
    fi
    eval "$var_name='$input'"
}

# Function to prompt for required input
prompt_required() {
    local prompt="$1"
    local var_name="$2"
    local is_secret="${3:-false}"
    local input=""
    
    while [ -z "$input" ]; do
        if [ "$is_secret" = "true" ]; then
            read -sp "${prompt}: " input
            echo
        else
            read -p "${prompt}: " input
        fi
        if [ -z "$input" ]; then
            print_error "This field is required. Please enter a value."
        fi
    done
    eval "$var_name='$input'"
}

# Check if .env already exists (skip in dry-run)
if [ "$DRY_RUN" = "false" ]; then
    if [ -f "$ENV_FILE" ]; then
        print_warning ".env file already exists!"
        read -p "Do you want to overwrite it? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            print_info "Setup cancelled. Existing .env file preserved."
            exit 0
        fi
        print_info "Backing up existing .env to .env.backup"
        cp "$ENV_FILE" "${ENV_FILE}.backup"
    fi
else
    if [ -f "$ENV_FILE" ]; then
        print_warning ".env file exists (will be validated but not modified in dry-run)"
    fi
fi

print_info "Starting Home Plex Entertainment Stack setup..."
echo

# ============================================================================
# System Configuration
# ============================================================================
print_info "=== System Configuration ==="
prompt_with_default "Timezone" "America/New_York" "TZ"
prompt_with_default "User ID (PUID)" "1000" "PUID"
prompt_with_default "Group ID (PGID)" "998" "PGID"
echo

# ============================================================================
# Network Configuration
# ============================================================================
print_info "=== Network Configuration ==="
while true; do
    prompt_with_default "Plex Network Subnet" "172.21.0.0/16" "PLEX_NETWORK_SUBNET"
    if validate_cidr "$PLEX_NETWORK_SUBNET"; then
        break
    else
        print_error "Invalid CIDR notation. Please use format: x.x.x.x/y (e.g., 172.21.0.0/16)"
    fi
done
echo

# ============================================================================
# Traefik Configuration
# ============================================================================
print_info "=== Traefik Reverse Proxy Configuration ==="
while true; do
    prompt_with_default "Traefik IP Address" "172.21.0.10" "TRAEFIK_IP"
    if validate_ip "$TRAEFIK_IP"; then
        break
    else
        print_error "Invalid IP address format. Please use format: x.x.x.x"
    fi
done

while true; do
    prompt_with_default "Traefik HTTP Port" "80" "TRAEFIK_HTTP_PORT"
    if validate_port "$TRAEFIK_HTTP_PORT"; then
        break
    else
        print_error "Invalid port number. Please use a number between 1-65535"
    fi
done

while true; do
    prompt_with_default "Traefik HTTPS Port" "443" "TRAEFIK_HTTPS_PORT"
    if validate_port "$TRAEFIK_HTTPS_PORT"; then
        break
    else
        print_error "Invalid port number. Please use a number between 1-65535"
    fi
done

while true; do
    prompt_with_default "Traefik Dashboard Port" "8088" "TRAEFIK_DASHBOARD_PORT"
    if validate_port "$TRAEFIK_DASHBOARD_PORT"; then
        break
    else
        print_error "Invalid port number. Please use a number between 1-65535"
    fi
done

while true; do
    prompt_with_default "Traefik Domain (FQDN)" "traefik.example.com" "TRAEFIK_DOMAIN"
    if validate_domain "$TRAEFIK_DOMAIN"; then
        break
    else
        print_error "Invalid domain format. Please use a valid domain name"
    fi
done

while true; do
    prompt_required "Traefik ACME Email (for Let's Encrypt)" "TRAEFIK_ACME_EMAIL"
    if validate_email "$TRAEFIK_ACME_EMAIL"; then
        break
    else
        print_error "Invalid email format. Please use a valid email address"
    fi
done

prompt_with_default "Traefik Log Level" "INFO" "TRAEFIK_LOG_LEVEL"
prompt_with_default "Traefik Let's Encrypt Path" "/nfs/data/docker/traefik/letsencrypt" "TRAEFIK_LETSENCRYPT_PATH"
prompt_with_default "Cloudflare DNS API Token (leave empty if not using Cloudflare)" "" "CF_DNS_API_TOKEN"
prompt_with_default "Traefik Middleware (e.g., 'authelia@docker' or leave empty)" "" "TRAEFIK_MIDDLEWARE"
echo

# ============================================================================
# Database Configuration
# ============================================================================
print_info "=== Database Configuration ==="
prompt_with_default "PostgreSQL Username" "postgres" "POSTGRES_USER"
prompt_required "PostgreSQL Password" "POSTGRES_PASSWORD" "true"
prompt_with_default "Riven Database Name" "riven" "POSTGRES_DB_RIVEN"
prompt_with_default "Zilean Database Name" "zilean" "POSTGRES_DB_ZILEAN"
echo

# ============================================================================
# Plex Configuration
# ============================================================================
print_info "=== Plex Configuration ==="
while true; do
    prompt_with_default "Plex URL (external)" "http://192.168.1.100:32400" "PLEX_URL"
    if validate_url "$PLEX_URL"; then
        break
    else
        print_error "Invalid URL format. Please use format: http://host:port or https://host:port"
    fi
done

while true; do
    prompt_with_default "Plex URL (internal)" "http://192.168.1.100:32400" "PLEX_URL_INTERNAL"
    if validate_url "$PLEX_URL_INTERNAL"; then
        break
    else
        print_error "Invalid URL format. Please use format: http://host:port or https://host:port"
    fi
done

prompt_required "Plex Token" "PLEX_TOKEN" "true"
echo

# ============================================================================
# Real-Debrid Configuration
# ============================================================================
print_info "=== Real-Debrid Configuration ==="
prompt_required "Real-Debrid API Key" "REAL_DEBRID_API_KEY" "true"
echo

# ============================================================================
# Riven Configuration
# ============================================================================
print_info "=== Riven Configuration ==="
prompt_required "Riven API Key" "RIVEN_API_KEY" "true"

while true; do
    prompt_with_default "Riven Frontend URL" "https://riven.example.com" "RIVEN_FRONTEND_URL"
    if validate_url "$RIVEN_FRONTEND_URL"; then
        break
    else
        print_error "Invalid URL format. Please use format: http://host:port or https://host:port"
    fi
done

while true; do
    prompt_with_default "Riven Backend URL" "http://riven:8080" "RIVEN_BACKEND_URL"
    if validate_url "$RIVEN_BACKEND_URL"; then
        break
    else
        print_error "Invalid URL format. Please use format: http://host:port or https://host:port"
    fi
done

while true; do
    prompt_with_default "Zilean URL" "http://zilean:8181" "ZILEAN_URL"
    if validate_url "$ZILEAN_URL"; then
        break
    else
        print_error "Invalid URL format. Please use format: http://host:port or https://host:port"
    fi
done
prompt_with_default "Enable Overseerr integration? (true/false)" "true" "RIVEN_CONTENT_OVERSEERR_ENABLED"
prompt_with_default "Enable Plex Watchlist monitoring? (true/false)" "true" "RIVEN_CONTENT_PLEX_WATCHLIST_ENABLED"
prompt_with_default "Plex Watchlist update interval (seconds)" "60" "RIVEN_CONTENT_PLEX_WATCHLIST_UPDATE_INTERVAL"
prompt_with_default "Enable Torrentio scraping? (true/false)" "false" "RIVEN_SCRAPING_TORRENTIO_ENABLED"
prompt_with_default "Rclone symlink path" "/nfs/data/docker/storageRD/torrents/__all__" "RIVEN_SYMLINK_RCLONE_PATH"
prompt_with_default "Plex library path" "/nfs/media/plex" "RIVEN_SYMLINK_LIBRARY_PATH"
prompt_with_default "Riven webhook URL for Overseerr" "http://riven:8080/api/v1/webhook/overseerr" "RIVEN_WEBHOOK_OVERSEERR_URL"
echo

# ============================================================================
# Overseerr Configuration
# ============================================================================
print_info "=== Overseerr Configuration ==="
while true; do
    prompt_with_default "Overseerr URL" "http://overseerr:5055" "OVERSEERR_URL"
    if validate_url "$OVERSEERR_URL"; then
        break
    else
        print_error "Invalid URL format. Please use format: http://host:port or https://host:port"
    fi
done
prompt_with_default "Overseerr API Key (leave empty if not configured)" "" "OVERSEERR_API_KEY"
echo

# ============================================================================
# Domain Configuration
# ============================================================================
print_info "=== Domain Configuration (FQDN and Local) ==="

validate_domain_input() {
    local prompt_text="$1"
    local default_value="$2"
    local var_name="$3"
    while true; do
        prompt_with_default "$prompt_text" "$default_value" "$var_name"
        if validate_domain "${!var_name}"; then
            break
        else
            print_error "Invalid domain format. Please use a valid domain name"
        fi
    done
}

validate_domain_input "Zurg Domain (FQDN)" "zurg.example.com" "ZURG_DOMAIN"
validate_domain_input "Zurg Local Domain" "zurg.local" "ZURG_LOCAL_DOMAIN"
validate_domain_input "Zurger Domain (FQDN)" "zurger.example.com" "ZURGER_DOMAIN"
validate_domain_input "Zurger Local Domain" "zurger.local" "ZURGER_LOCAL_DOMAIN"
validate_domain_input "Zilean Domain (FQDN)" "zilean.example.com" "ZILEAN_DOMAIN"
validate_domain_input "Zilean Local Domain" "zilean.local" "ZILEAN_LOCAL_DOMAIN"
validate_domain_input "Overseerr Domain (FQDN)" "over.example.com" "OVERSEERR_DOMAIN"
validate_domain_input "Overseerr Local Domain" "over.local" "OVERSEERR_LOCAL_DOMAIN"
validate_domain_input "Riven Domain (FQDN)" "riven.example.com" "RIVEN_DOMAIN"
validate_domain_input "Riven Local Domain" "riven.local" "RIVEN_LOCAL_DOMAIN"
echo

# ============================================================================
# Static IP Configuration
# ============================================================================
print_info "=== Static IP Configuration (in plex_network subnet) ==="

validate_ip_input() {
    local prompt_text="$1"
    local default_value="$2"
    local var_name="$3"
    while true; do
        prompt_with_default "$prompt_text" "$default_value" "$var_name"
        if validate_ip "${!var_name}"; then
            break
        else
            print_error "Invalid IP address format. Please use format: x.x.x.x"
        fi
    done
}

validate_ip_input "Zurg IP" "172.21.0.25" "ZURG_IP"
validate_ip_input "Rclone IP" "172.21.0.43" "RCLONE_IP"
validate_ip_input "Zurger IP" "172.21.0.26" "ZURGER_IP"
validate_ip_input "Riven DB IP" "172.21.0.32" "RIVEN_DB_IP"
validate_ip_input "Zilean IP" "172.21.0.28" "ZILEAN_IP"
validate_ip_input "Overseerr IP" "172.21.0.29" "OVERSEERR_IP"
validate_ip_input "Riven IP" "172.21.0.31" "RIVEN_IP"
validate_ip_input "Riven Frontend IP" "172.21.0.30" "RIVEN_FRONTEND_IP"
validate_ip_input "FlareSolverr IP" "172.21.0.20" "FLARESOLVERR_IP"

# Check for IP conflicts
print_info "Checking for IP address conflicts..."
declare -a IPS=("$TRAEFIK_IP" "$ZURG_IP" "$RCLONE_IP" "$ZURGER_IP" "$RIVEN_DB_IP" "$ZILEAN_IP" "$OVERSEERR_IP" "$RIVEN_IP" "$RIVEN_FRONTEND_IP" "$FLARESOLVERR_IP")
declare -A IP_COUNT
for ip in "${IPS[@]}"; do
    ((IP_COUNT["$ip"]++))
done
CONFLICTS=0
for ip in "${!IP_COUNT[@]}"; do
    if [[ ${IP_COUNT["$ip"]} -gt 1 ]]; then
        print_error "IP address conflict detected: $ip is used ${IP_COUNT["$ip"]} times"
        ((CONFLICTS++))
    fi
done
if [[ $CONFLICTS -gt 0 ]]; then
    print_error "Please fix IP address conflicts before continuing"
    exit 1
fi
print_success "No IP address conflicts detected"
echo

# ============================================================================
# Path Configuration
# ============================================================================
print_info "=== Path Configuration ==="
prompt_with_default "Zurg Config Path" "/nfs/data/docker/zurg/config.yml" "ZURG_CONFIG_PATH"
prompt_with_default "Zurg Data Path" "/nfs/data/docker/zurg/" "ZURG_DATA_PATH"
prompt_with_default "Zurger Build Context" "/nfs/data/docker/zurger" "ZURGER_BUILD_CONTEXT"
prompt_with_default "Zurger Templates Path" "/nfs/data/docker/zurger/templates" "ZURGER_TEMPLATES_PATH"
prompt_with_default "Zurger Config Path" "/nfs/data/docker/zurger/config.ini" "ZURGER_CONFIG_PATH"
prompt_with_default "Zurger Trigger Path" "/nfs/media/zurger/" "ZURGER_TRIGGER_PATH"
prompt_with_default "Rclone Config Path" "/nfs/data/docker/rclone/rclone.conf" "RCLONE_CONFIG_PATH"
prompt_with_default "Storage Torrents Path" "/nfs/data/docker/storageRD/torrents" "STORAGE_TORRENTS_PATH"
prompt_with_default "Storage RD Path" "/nfs/data/docker/storageRD" "STORAGE_RD_PATH"
prompt_with_default "Plex Library Path" "/nfs/media/plex" "PLEX_LIBRARY_PATH"
prompt_with_default "Zilean Data Path" "/nfs/data/docker/zilean" "ZILEAN_DATA_PATH"
prompt_with_default "Overseerr Config Path" "/nfs/data/docker/overseerr/config" "OVERSEERR_CONFIG_PATH"
prompt_with_default "Riven Data Path" "/nfs/data/docker/riven/data" "RIVEN_DATA_PATH"
prompt_with_default "Riven DB Path" "/nfs/data/docker/riven-db" "RIVEN_DB_PATH"
echo

# ============================================================================
# FlareSolverr Configuration (Optional)
# ============================================================================
print_info "=== FlareSolverr Configuration (Optional) ==="
prompt_with_default "Log Level" "info" "LOG_LEVEL"
prompt_with_default "Log HTML (true/false)" "false" "LOG_HTML"
prompt_with_default "Captcha Solver (leave empty if not using)" "" "CAPTCHA_SOLVER"
echo

# ============================================================================
# Generate .env file
# ============================================================================
if [ "$DRY_RUN" = "true" ]; then
    print_info "DRY RUN: Would generate .env file with the following content:"
    echo
    ENV_OUTPUT=$(cat << EOF
# ============================================================================
# Home Plex Entertainment Stack - Environment Variables
# ============================================================================
# Generated by setup.sh on $(date)
# ============================================================================

# ----------------------------------------------------------------------------
# System Configuration
# ----------------------------------------------------------------------------
TZ=${TZ}
PUID=${PUID}
PGID=${PGID}

# ----------------------------------------------------------------------------
# Network Configuration
# ----------------------------------------------------------------------------
PLEX_NETWORK_SUBNET=${PLEX_NETWORK_SUBNET}

# ----------------------------------------------------------------------------
# Traefik Configuration
# ----------------------------------------------------------------------------
TRAEFIK_IP=${TRAEFIK_IP}
TRAEFIK_HTTP_PORT=${TRAEFIK_HTTP_PORT}
TRAEFIK_HTTPS_PORT=${TRAEFIK_HTTPS_PORT}
TRAEFIK_DASHBOARD_PORT=${TRAEFIK_DASHBOARD_PORT}
TRAEFIK_DOMAIN=${TRAEFIK_DOMAIN}
TRAEFIK_ACME_EMAIL=${TRAEFIK_ACME_EMAIL}
TRAEFIK_LOG_LEVEL=${TRAEFIK_LOG_LEVEL}
TRAEFIK_LETSENCRYPT_PATH=${TRAEFIK_LETSENCRYPT_PATH}
TRAEFIK_MIDDLEWARE=${TRAEFIK_MIDDLEWARE}
CF_DNS_API_TOKEN=${CF_DNS_API_TOKEN}

# ----------------------------------------------------------------------------
# Database Configuration
# ----------------------------------------------------------------------------
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB_RIVEN=${POSTGRES_DB_RIVEN}
POSTGRES_DB_ZILEAN=${POSTGRES_DB_ZILEAN}

# ----------------------------------------------------------------------------
# Plex Configuration
# ----------------------------------------------------------------------------
PLEX_URL=${PLEX_URL}
PLEX_URL_INTERNAL=${PLEX_URL_INTERNAL}
PLEX_TOKEN=${PLEX_TOKEN}

# ----------------------------------------------------------------------------
# Real-Debrid Configuration
# ----------------------------------------------------------------------------
REAL_DEBRID_API_KEY=${REAL_DEBRID_API_KEY}

# ----------------------------------------------------------------------------
# Riven Configuration
# ----------------------------------------------------------------------------
RIVEN_API_KEY=${RIVEN_API_KEY}
RIVEN_FRONTEND_URL=${RIVEN_FRONTEND_URL}
RIVEN_BACKEND_URL=${RIVEN_BACKEND_URL}
ZILEAN_URL=${ZILEAN_URL}
RIVEN_CONTENT_OVERSEERR_ENABLED=${RIVEN_CONTENT_OVERSEERR_ENABLED}
RIVEN_CONTENT_PLEX_WATCHLIST_ENABLED=${RIVEN_CONTENT_PLEX_WATCHLIST_ENABLED}
RIVEN_CONTENT_PLEX_WATCHLIST_UPDATE_INTERVAL=${RIVEN_CONTENT_PLEX_WATCHLIST_UPDATE_INTERVAL}
RIVEN_SCRAPING_TORRENTIO_ENABLED=${RIVEN_SCRAPING_TORRENTIO_ENABLED}
RIVEN_SYMLINK_RCLONE_PATH=${RIVEN_SYMLINK_RCLONE_PATH}
RIVEN_SYMLINK_LIBRARY_PATH=${RIVEN_SYMLINK_LIBRARY_PATH}
RIVEN_WEBHOOK_OVERSEERR_URL=${RIVEN_WEBHOOK_OVERSEERR_URL}

# ----------------------------------------------------------------------------
# Overseerr Configuration
# ----------------------------------------------------------------------------
OVERSEERR_URL=${OVERSEERR_URL}
OVERSEERR_API_KEY=${OVERSEERR_API_KEY}

# ----------------------------------------------------------------------------
# Domain Configuration (FQDN and Local)
# ----------------------------------------------------------------------------
ZURG_DOMAIN=${ZURG_DOMAIN}
ZURG_LOCAL_DOMAIN=${ZURG_LOCAL_DOMAIN}
ZURGER_DOMAIN=${ZURGER_DOMAIN}
ZURGER_LOCAL_DOMAIN=${ZURGER_LOCAL_DOMAIN}
ZILEAN_DOMAIN=${ZILEAN_DOMAIN}
ZILEAN_LOCAL_DOMAIN=${ZILEAN_LOCAL_DOMAIN}
OVERSEERR_DOMAIN=${OVERSEERR_DOMAIN}
OVERSEERR_LOCAL_DOMAIN=${OVERSEERR_LOCAL_DOMAIN}
RIVEN_DOMAIN=${RIVEN_DOMAIN}
RIVEN_LOCAL_DOMAIN=${RIVEN_LOCAL_DOMAIN}

# ----------------------------------------------------------------------------
# Static IP Configuration (in plex_network subnet)
# ----------------------------------------------------------------------------
ZURG_IP=${ZURG_IP}
RCLONE_IP=${RCLONE_IP}
ZURGER_IP=${ZURGER_IP}
RIVEN_DB_IP=${RIVEN_DB_IP}
ZILEAN_IP=${ZILEAN_IP}
OVERSEERR_IP=${OVERSEERR_IP}
RIVEN_IP=${RIVEN_IP}
RIVEN_FRONTEND_IP=${RIVEN_FRONTEND_IP}
FLARESOLVERR_IP=${FLARESOLVERR_IP}

# ----------------------------------------------------------------------------
# Path Configuration
# ----------------------------------------------------------------------------
ZURG_CONFIG_PATH=${ZURG_CONFIG_PATH}
ZURG_DATA_PATH=${ZURG_DATA_PATH}
ZURGER_BUILD_CONTEXT=${ZURGER_BUILD_CONTEXT}
ZURGER_TEMPLATES_PATH=${ZURGER_TEMPLATES_PATH}
ZURGER_CONFIG_PATH=${ZURGER_CONFIG_PATH}
ZURGER_TRIGGER_PATH=${ZURGER_TRIGGER_PATH}
RCLONE_CONFIG_PATH=${RCLONE_CONFIG_PATH}
STORAGE_TORRENTS_PATH=${STORAGE_TORRENTS_PATH}
STORAGE_RD_PATH=${STORAGE_RD_PATH}
PLEX_LIBRARY_PATH=${PLEX_LIBRARY_PATH}
ZILEAN_DATA_PATH=${ZILEAN_DATA_PATH}
OVERSEERR_CONFIG_PATH=${OVERSEERR_CONFIG_PATH}
RIVEN_DATA_PATH=${RIVEN_DATA_PATH}
RIVEN_DB_PATH=${RIVEN_DB_PATH}

# ----------------------------------------------------------------------------
# FlareSolverr Configuration (Optional)
# ----------------------------------------------------------------------------
LOG_LEVEL=${LOG_LEVEL}
LOG_HTML=${LOG_HTML}
CAPTCHA_SOLVER=${CAPTCHA_SOLVER}
EOF
)
    echo "$ENV_OUTPUT"
    echo
    print_info "DRY RUN: .env file would be written to: ${ENV_FILE}"
else
    print_info "Generating .env file..."
    cat > "$ENV_FILE" << EOF
# ============================================================================
# Home Plex Entertainment Stack - Environment Variables
# ============================================================================
# Generated by setup.sh on $(date)
# ============================================================================

# ----------------------------------------------------------------------------
# System Configuration
# ----------------------------------------------------------------------------
TZ=${TZ}
PUID=${PUID}
PGID=${PGID}

# ----------------------------------------------------------------------------
# Network Configuration
# ----------------------------------------------------------------------------
PLEX_NETWORK_SUBNET=${PLEX_NETWORK_SUBNET}

# ----------------------------------------------------------------------------
# Traefik Configuration
# ----------------------------------------------------------------------------
TRAEFIK_IP=${TRAEFIK_IP}
TRAEFIK_HTTP_PORT=${TRAEFIK_HTTP_PORT}
TRAEFIK_HTTPS_PORT=${TRAEFIK_HTTPS_PORT}
TRAEFIK_DASHBOARD_PORT=${TRAEFIK_DASHBOARD_PORT}
TRAEFIK_DOMAIN=${TRAEFIK_DOMAIN}
TRAEFIK_ACME_EMAIL=${TRAEFIK_ACME_EMAIL}
TRAEFIK_LOG_LEVEL=${TRAEFIK_LOG_LEVEL}
TRAEFIK_LETSENCRYPT_PATH=${TRAEFIK_LETSENCRYPT_PATH}
TRAEFIK_MIDDLEWARE=${TRAEFIK_MIDDLEWARE}
CF_DNS_API_TOKEN=${CF_DNS_API_TOKEN}

# ----------------------------------------------------------------------------
# Database Configuration
# ----------------------------------------------------------------------------
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB_RIVEN=${POSTGRES_DB_RIVEN}
POSTGRES_DB_ZILEAN=${POSTGRES_DB_ZILEAN}

# ----------------------------------------------------------------------------
# Plex Configuration
# ----------------------------------------------------------------------------
PLEX_URL=${PLEX_URL}
PLEX_URL_INTERNAL=${PLEX_URL_INTERNAL}
PLEX_TOKEN=${PLEX_TOKEN}

# ----------------------------------------------------------------------------
# Real-Debrid Configuration
# ----------------------------------------------------------------------------
REAL_DEBRID_API_KEY=${REAL_DEBRID_API_KEY}

# ----------------------------------------------------------------------------
# Riven Configuration
# ----------------------------------------------------------------------------
RIVEN_API_KEY=${RIVEN_API_KEY}
RIVEN_FRONTEND_URL=${RIVEN_FRONTEND_URL}
RIVEN_BACKEND_URL=${RIVEN_BACKEND_URL}
ZILEAN_URL=${ZILEAN_URL}
RIVEN_CONTENT_OVERSEERR_ENABLED=${RIVEN_CONTENT_OVERSEERR_ENABLED}
RIVEN_CONTENT_PLEX_WATCHLIST_ENABLED=${RIVEN_CONTENT_PLEX_WATCHLIST_ENABLED}
RIVEN_CONTENT_PLEX_WATCHLIST_UPDATE_INTERVAL=${RIVEN_CONTENT_PLEX_WATCHLIST_UPDATE_INTERVAL}
RIVEN_SCRAPING_TORRENTIO_ENABLED=${RIVEN_SCRAPING_TORRENTIO_ENABLED}
RIVEN_SYMLINK_RCLONE_PATH=${RIVEN_SYMLINK_RCLONE_PATH}
RIVEN_SYMLINK_LIBRARY_PATH=${RIVEN_SYMLINK_LIBRARY_PATH}
RIVEN_WEBHOOK_OVERSEERR_URL=${RIVEN_WEBHOOK_OVERSEERR_URL}

# ----------------------------------------------------------------------------
# Overseerr Configuration
# ----------------------------------------------------------------------------
OVERSEERR_URL=${OVERSEERR_URL}
OVERSEERR_API_KEY=${OVERSEERR_API_KEY}

# ----------------------------------------------------------------------------
# Domain Configuration (FQDN and Local)
# ----------------------------------------------------------------------------
ZURG_DOMAIN=${ZURG_DOMAIN}
ZURG_LOCAL_DOMAIN=${ZURG_LOCAL_DOMAIN}
ZURGER_DOMAIN=${ZURGER_DOMAIN}
ZURGER_LOCAL_DOMAIN=${ZURGER_LOCAL_DOMAIN}
ZILEAN_DOMAIN=${ZILEAN_DOMAIN}
ZILEAN_LOCAL_DOMAIN=${ZILEAN_LOCAL_DOMAIN}
OVERSEERR_DOMAIN=${OVERSEERR_DOMAIN}
OVERSEERR_LOCAL_DOMAIN=${OVERSEERR_LOCAL_DOMAIN}
RIVEN_DOMAIN=${RIVEN_DOMAIN}
RIVEN_LOCAL_DOMAIN=${RIVEN_LOCAL_DOMAIN}

# ----------------------------------------------------------------------------
# Static IP Configuration (in plex_network subnet)
# ----------------------------------------------------------------------------
ZURG_IP=${ZURG_IP}
RCLONE_IP=${RCLONE_IP}
ZURGER_IP=${ZURGER_IP}
RIVEN_DB_IP=${RIVEN_DB_IP}
ZILEAN_IP=${ZILEAN_IP}
OVERSEERR_IP=${OVERSEERR_IP}
RIVEN_IP=${RIVEN_IP}
RIVEN_FRONTEND_IP=${RIVEN_FRONTEND_IP}
FLARESOLVERR_IP=${FLARESOLVERR_IP}

# ----------------------------------------------------------------------------
# Path Configuration
# ----------------------------------------------------------------------------
ZURG_CONFIG_PATH=${ZURG_CONFIG_PATH}
ZURG_DATA_PATH=${ZURG_DATA_PATH}
ZURGER_BUILD_CONTEXT=${ZURGER_BUILD_CONTEXT}
ZURGER_TEMPLATES_PATH=${ZURGER_TEMPLATES_PATH}
ZURGER_CONFIG_PATH=${ZURGER_CONFIG_PATH}
ZURGER_TRIGGER_PATH=${ZURGER_TRIGGER_PATH}
RCLONE_CONFIG_PATH=${RCLONE_CONFIG_PATH}
STORAGE_TORRENTS_PATH=${STORAGE_TORRENTS_PATH}
STORAGE_RD_PATH=${STORAGE_RD_PATH}
PLEX_LIBRARY_PATH=${PLEX_LIBRARY_PATH}
ZILEAN_DATA_PATH=${ZILEAN_DATA_PATH}
OVERSEERR_CONFIG_PATH=${OVERSEERR_CONFIG_PATH}
RIVEN_DATA_PATH=${RIVEN_DATA_PATH}
RIVEN_DB_PATH=${RIVEN_DB_PATH}

# ----------------------------------------------------------------------------
# FlareSolverr Configuration (Optional)
# ----------------------------------------------------------------------------
LOG_LEVEL=${LOG_LEVEL}
LOG_HTML=${LOG_HTML}
CAPTCHA_SOLVER=${CAPTCHA_SOLVER}
EOF

    print_success ".env file generated successfully!"
fi
echo

# ============================================================================
# Verify paths exist
# ============================================================================
print_info "Verifying paths..."
MISSING_PATHS=()

check_path() {
    local path="$1"
    local name="$2"
    if [ ! -e "$path" ]; then
        MISSING_PATHS+=("$name: $path")
    fi
}

check_path "$ZURG_CONFIG_PATH" "Zurg Config"
check_path "$ZURG_DATA_PATH" "Zurg Data"
check_path "$ZURGER_BUILD_CONTEXT" "Zurger Build Context"
check_path "$ZURGER_TEMPLATES_PATH" "Zurger Templates"
check_path "$ZURGER_CONFIG_PATH" "Zurger Config"
check_path "$RCLONE_CONFIG_PATH" "Rclone Config"
check_path "$PLEX_LIBRARY_PATH" "Plex Library"
check_path "$TRAEFIK_LETSENCRYPT_PATH" "Traefik Let's Encrypt"

if [ ${#MISSING_PATHS[@]} -gt 0 ]; then
    print_warning "The following paths do not exist:"
    for path in "${MISSING_PATHS[@]}"; do
        echo "  - $path"
    done
    echo
    print_info "You may need to create these paths or update the configuration."
else
    print_success "All paths verified!"
fi
echo

# ============================================================================
# Network check
# ============================================================================
print_info "Checking Docker network..."
NETWORK_NAME="plex_network"
if [ "$DRY_RUN" = "true" ]; then
    if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        print_warning "Docker network '$NETWORK_NAME' already exists"
        print_info "DRY RUN: Would check if subnet matches: ${PLEX_NETWORK_SUBNET}"
    else
        print_info "DRY RUN: Would create Docker network '$NETWORK_NAME' with subnet: ${PLEX_NETWORK_SUBNET}"
    fi
else
    if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        print_warning "Docker network '$NETWORK_NAME' already exists"
        read -p "Do you want to remove and recreate it? (y/N): " recreate_network
        if [[ "$recreate_network" =~ ^[Yy]$ ]]; then
            docker network rm "$NETWORK_NAME" 2>/dev/null || true
            docker network create --subnet="${PLEX_NETWORK_SUBNET}" "$NETWORK_NAME"
            print_success "Docker network '$NETWORK_NAME' recreated"
        else
            print_info "Using existing network '$NETWORK_NAME'"
        fi
    else
        print_info "Creating Docker network '$NETWORK_NAME'..."
        docker network create --subnet="${PLEX_NETWORK_SUBNET}" "$NETWORK_NAME"
        print_success "Docker network '$NETWORK_NAME' created"
    fi
fi
echo

# ============================================================================
# Summary
# ============================================================================
if [ "$DRY_RUN" = "true" ]; then
    print_success "DRY RUN completed successfully!"
    echo
    print_info "Summary of what would be created:"
    echo "  ✓ .env file would be generated at: ${ENV_FILE}"
    echo "  ✓ Docker network 'plex_network' would be checked/created"
    echo "  ✓ All configuration validated"
    echo
    print_info "Validation results:"
    if [ ${#MISSING_PATHS[@]} -eq 0 ]; then
        print_success "  ✓ All paths validated"
    else
        print_warning "  ⚠️  ${#MISSING_PATHS[@]} paths need to be created"
    fi
    print_success "  ✓ All IP addresses validated"
    print_success "  ✓ No IP conflicts detected"
    print_success "  ✓ All domains validated"
    print_success "  ✓ All URLs validated"
    print_success "  ✓ All ports validated"
    print_success "  ✓ Email validated"
    print_success "  ✓ CIDR subnet validated"
    echo
    print_info "To perform actual setup, run:"
    echo "  ./setup.sh"
    echo
    print_info "To validate Docker Compose configuration:"
    echo "  docker compose -f docker-compose.yml config"
else
    print_success "Setup completed successfully!"
    echo
    print_info "Next steps:"
    echo "  1. Review the generated .env file: ${ENV_FILE}"
    echo "  2. Make any necessary adjustments to paths or configuration"
    echo "  3. Validate configuration: docker compose config"
    echo "  4. Start the services: docker compose up -d"
    echo "  5. Check logs: docker compose logs -f"
    echo "  6. Configure Overseerr webhook:"
    echo "     - Login to Overseerr"
    echo "     - Go to Settings → Notifications → Webhooks"
    echo "     - Add webhook: ${RIVEN_WEBHOOK_OVERSEERR_URL}"
    echo "     - Set Auth Header: Bearer ${RIVEN_API_KEY}"
    echo "     - Enable events: Media Requested, Media Available"
    echo "  7. Verify Plex Watchlist monitoring is enabled in Riven settings"
    echo
    print_info "Configuration file location: ${ENV_FILE}"
    print_info "Integration guide: ${SCRIPT_DIR}/integration-config.md"
    print_warning "Keep your .env file secure! It contains sensitive information."
fi

