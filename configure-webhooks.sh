#!/bin/bash

# ============================================================================
# Webhook Configuration Helper Script
# ============================================================================
# This script helps configure webhooks after initial setup
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Load environment variables
if [ ! -f "$ENV_FILE" ]; then
    print_warning ".env file not found. Please run setup.sh first."
    exit 1
fi

source "$ENV_FILE"

print_info "Webhook Configuration Helper"
echo
print_info "This script will help you configure webhooks for seamless integration."
echo

# Overseerr Webhook Configuration
print_info "=== Overseerr → Riven Webhook ==="
echo
echo "To configure Overseerr webhook:"
echo "1. Open Overseerr in your browser: ${OVERSEERR_DOMAIN}"
echo "2. Go to: Settings → Notifications → Webhooks"
echo "3. Click 'Add Webhook'"
echo "4. Configure:"
echo "   - Name: Riven Integration"
echo "   - URL: ${RIVEN_WEBHOOK_OVERSEERR_URL}"
echo "   - Method: POST"
echo "   - Auth Header: Bearer ${RIVEN_API_KEY}"
echo "   - Events to enable:"
echo "     ✓ Media Requested"
echo "     ✓ Media Available"
echo "     ✓ Media Approved"
echo "     ✓ Media Auto-Approved"
echo
read -p "Press Enter when you've configured the webhook in Overseerr..."

# Test webhook connectivity
print_info "Testing webhook connectivity..."
if docker exec overseerr wget -q --spider --timeout=5 "${RIVEN_WEBHOOK_OVERSEERR_URL}" 2>/dev/null; then
    print_success "Webhook endpoint is reachable from Overseerr"
else
    print_warning "Could not reach webhook endpoint. Verify:"
    echo "  - Riven is running: docker compose ps riven"
    echo "  - Network connectivity: docker exec overseerr ping -c 1 riven"
    echo "  - Webhook URL is correct: ${RIVEN_WEBHOOK_OVERSEERR_URL}"
fi
echo

# Plex Watchlist Configuration
print_info "=== Plex Watchlist Monitoring ==="
echo
if [ "${RIVEN_CONTENT_PLEX_WATCHLIST_ENABLED}" = "true" ]; then
    print_success "Plex Watchlist monitoring is enabled"
    echo "  - Update interval: ${RIVEN_CONTENT_PLEX_WATCHLIST_UPDATE_INTERVAL} seconds"
    echo "  - Plex URL: ${PLEX_URL_INTERNAL}"
    echo
    echo "Riven will automatically:"
    echo "  1. Monitor Plex watchlists every ${RIVEN_CONTENT_PLEX_WATCHLIST_UPDATE_INTERVAL} seconds"
    echo "  2. Detect new items added to watchlist"
    echo "  3. Trigger download workflow automatically"
    echo "  4. Process and add to Plex library when ready"
else
    print_warning "Plex Watchlist monitoring is disabled"
    echo "To enable, set RIVEN_CONTENT_PLEX_WATCHLIST_ENABLED=true in .env"
fi
echo

# Service Connectivity Check
print_info "=== Service Connectivity Check ==="
echo

check_connectivity() {
    local service=$1
    local target=$2
    local port=$3
    
    if docker exec "$service" ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
        print_success "$service → $target: OK"
        return 0
    else
        print_warning "$service → $target: FAILED"
        return 1
    fi
}

echo "Checking service-to-service connectivity..."
check_connectivity "riven" "overseerr" "5055"
check_connectivity "riven" "zilean" "8181"
check_connectivity "riven" "riven-db" "5432"
check_connectivity "zilean" "riven-db" "5432"
check_connectivity "rclone" "zurg" "9999"
echo

# Summary
print_info "=== Configuration Summary ==="
echo
echo "Integration Status:"
echo "  ✓ Overseerr → Riven: Webhook configured"
echo "  ✓ Plex Watchlist → Riven: ${RIVEN_CONTENT_PLEX_WATCHLIST_ENABLED}"
echo "  ✓ Riven → Zilean: Enabled"
echo "  ✓ Riven → Real-Debrid: Enabled"
echo "  ✓ Zurg → Zurger: Trigger configured"
echo "  ✓ Zurger → Plex: Library update configured"
echo
print_info "For detailed integration documentation, see: integration-config.md"
echo

