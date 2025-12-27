# Home Plex Entertainment Stack

Complete Docker Compose setup for a fully automated media management stack. This stack provides seamless integration from media requests to automatic downloading, processing, and library management.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Architecture & Workflow](#architecture--workflow)
- [Services](#services)
- [Configuration](#configuration)
- [Integration & Webhooks](#integration--webhooks)
- [Network & Infrastructure](#network--infrastructure)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Reference](#reference)

---

## Overview

This stack automates the entire media acquisition and management workflow:

1. **Request Media**: Users request content via Overseerr or add to Plex watchlist
2. **Automated Download**: Riven orchestrates scraping, downloading via Real-Debrid
3. **Content Management**: Zurg organizes downloads, Rclone provides filesystem access
4. **File Organization**: Zurger matches metadata and organizes files
5. **Library Integration**: Automatic Plex library updates and availability

### Key Features

- ✅ **Fully Automated**: From request to library availability
- ✅ **Multiple Entry Points**: Overseerr requests or Plex watchlist monitoring
- ✅ **Reverse Proxy**: Traefik with SSL certificates (Let's Encrypt)
- ✅ **Isolated Network**: Dedicated `plex_network` with static IPs
- ✅ **Webhook Integration**: Real-time notifications and triggers
- ✅ **Dual Domain Support**: FQDN and local domains for flexible access

---

## Quick Start

### 1. Run Setup Script

```bash
cd ~/home_plex  # or wherever you cloned/extracted this
./setup.sh
```

The setup script will:
- Ask if you want to enable Traefik (skip for local-only setups)
- Prompt for all required configuration values
- Generate a `.env` file organized by application
- Verify paths exist
- Create Docker network if needed

### 2. Start Services

**With Traefik (for external access with SSL):**
```bash
docker compose --profile traefik up -d
```

**Without Traefik (for local-only access via direct ports):**
```bash
docker compose up -d
```

> **Note:** If you skipped Traefik during setup, services will be accessible via direct ports (see `docker-compose.yml` for port mappings). Traefik labels on services will be ignored when Traefik is not running.

### 3. Configure Webhooks (Optional)

```bash
./configure-webhooks.sh
```

Or manually configure Overseerr webhook in the UI.

### 4. Verify Services

```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f

# Test connectivity
docker exec overseerr ping -c 1 riven
```

---

## Architecture & Workflow

### Complete Integration Flow

```
┌─────────────┐
│   Plex      │ (External - on host)
│ Watchlist   │
└──────┬──────┘
       │ Polls every 60s
       ▼
┌─────────────┐     ┌─────────────┐
│   Riven     │◄────│  Overseerr │ (Webhook on request)
│ (Orchestrator)│     └─────────────┘
└──────┬──────┘
       │
       ├──► Scrapes torrents
       │    └──► Zilean (http://zilean:8181)
       │
       ├──► Downloads via Real-Debrid API
       │    └──► Real-Debrid (External API)
       │
       └──► Creates symlinks
            └──► ~/plex (Plex Library on host, mounted as /nfs/media/plex in containers)
                 │
                 └──► Triggers Plex library scan

Real-Debrid ──► Zurg (Monitors downloads)
                 │
                 ├──► WebDAV: http://zurg:9999/dav
                 │    └──► Rclone (Mounts as filesystem)
                 │         └──► ~/Docker/storageRD/torrents (on host, mounted as /nfs/data/docker/storageRD/torrents in containers)
                 │              │
                 │              └──► Zurger (Reads & organizes)
                 │                   │
                 │                   ├──► Moves to Plex library
                 │                   └──► Triggers Plex scan
                 │
                 └──► Library update trigger
                      └──► Zurger (http://zurger:8000/scan/all)
```

### Workflow Example

**Scenario**: User adds movie to Plex watchlist

1. **Plex**: Movie added to watchlist
2. **Riven**: Polls Plex API (every 60s), detects new watchlist item
3. **Riven**: Queries Zilean for torrent sources
4. **Zilean**: Returns matching torrents
5. **Riven**: Selects best torrent, sends to Real-Debrid
6. **Real-Debrid**: Downloads torrent
7. **Zurg**: Monitors Real-Debrid, detects completed download
8. **Zurg**: Organizes content, triggers Zurger
9. **Rclone**: Mounts Zurg WebDAV, content appears in mount
10. **Zurger**: Reads from mount, matches with TMDB, organizes files
11. **Zurger**: Moves files to Plex library, triggers Plex scan
12. **Plex**: Scans library, movie appears and is available

**Total Time**: ~5-15 minutes depending on download speed

---

## Services

### Traefik - Reverse Proxy
**Container**: `plex-traefik`  
**IP**: 172.21.0.10 (default)  
**Ports**: 80, 443, 8088 (dashboard)

**Purpose**: Reverse proxy and load balancer with automatic SSL certificates.

**Features**:
- Automatic Let's Encrypt certificates (Cloudflare DNS challenge)
- HTTP to HTTPS redirect
- Support for both FQDN and local domains
- Dashboard on port 8088

**Configuration**:
- Domain: `${TRAEFIK_DOMAIN}`
- ACME Email: `${TRAEFIK_ACME_EMAIL}`
- Cloudflare Token: `${CF_DNS_API_TOKEN}`

---

### Zurg - Real-Debrid Media Manager
**Container**: `zurg`  
**IP**: 172.21.0.25 (default)  
**Ports**: 9999 (WebDAV/HTTP), 8000 (web UI)

**Purpose**: Manages Real-Debrid torrents and provides WebDAV/HTTP access.

**Key Features**:
- Monitors Real-Debrid for new downloads (every 15 seconds)
- Organizes content into `anime`, `shows`, and `movies` groups
- Provides WebDAV endpoint at `/dav` and HTTP endpoint at `/http`
- Auto-repair enabled for broken downloads
- Library update triggers

**Configuration**:
- Real-Debrid Token: Configured in `config.yml`
- Check Interval: 15 seconds
- Auto-repair: Enabled
- Library Update Trigger: `/nfs/media/zurger/trigger.sh`

---

### Rclone - Filesystem Mount
**Container**: `rclone`  
**IP**: 172.21.0.43 (default)

**Purpose**: Mounts Zurg's WebDAV interface as a local filesystem.

**Configuration**:
- Mount Point: `~/Docker/storageRD/torrents` (host) → `/nfs/data/docker/storageRD/torrents` (container)
- Zurg WebDAV: `http://zurg:9999/dav`
- Requires FUSE support

**Mount Options**:
- `--dir-cache-time 10s`
- `--vfs-cache-mode off`
- `--vfs-read-chunk-size 128M`
- `--vfs-read-chunk-size-limit 2G`

---

### Zurger - Media Organization Interface
**Container**: `zurger`  
**IP**: 172.21.0.26 (default)  
**Ports**: 8000 (internal), 6464 (host)

**Purpose**: Organizes and manages media files from Real-Debrid downloads.

**Key Features**:
- Reads torrents from rclone mount
- Matches content with TMDB metadata
- Moves/organizes files to Plex library structure
- Triggers Plex library scans

**Configuration**:
- Plex URL: `${PLEX_URL}`
- Plex Token: `${PLEX_TOKEN}`
- TMDB API: Configured in `config.ini`
- Torrents Path: Read-only from rclone mount
- Plex Library: Read-write access

---

### Riven - Automation Orchestrator
**Container**: `riven`  
**IP**: 172.21.0.31 (default)  
**Ports**: 8080 (internal), 8085 (host)

**Purpose**: Main automation service coordinating downloads, scraping, and library updates.

**Key Features**:
- Receives webhooks from Overseerr
- Monitors Plex watchlists
- Scrapes torrents via Zilean
- Downloads via Real-Debrid
- Creates symlinks to Plex library
- Triggers Plex library scans

**Content Sources**:
- Overseerr (webhook-enabled)
- Plex Watchlist (polling every 60s)
- Trakt, MDBList, Listrr (optional)

**Scraping Sources**:
- Zilean (primary)
- Torrentio (optional)
- Prowlarr (optional)

**Downloaders**:
- Real-Debrid (primary)
- All-Debrid, Torbox (optional)

---

### Riven Frontend - Web UI
**Container**: `riven-frontend`  
**IP**: 172.21.0.30 (default)  
**Port**: 3000

**Purpose**: Web interface for managing Riven.

**Features**:
- Dashboard for monitoring downloads
- Configuration interface
- Status and logs viewing

---

### Zilean - Torrent Scraping Service
**Container**: `zilean`  
**IP**: 172.21.0.28 (default)  
**Port**: 8181

**Purpose**: Scrapes and indexes torrents from various sources.

**Key Features**:
- Scrapes torrents from configured sources
- Indexes torrent metadata
- Provides Torznab API for Riven
- Matches content with IMDb data
- Hourly scraping schedule

**Configuration**:
- Database: Shared PostgreSQL (riven-db)
- Scrape Schedule: Hourly (`0 * * * *`)
- Minimum Score Match: 0.85
- Max Filtered Results: 200

---

### Overseerr - Media Request Management
**Container**: `overseerr`  
**IP**: 172.21.0.29 (default)  
**Ports**: 5055 (internal), 5056 (host)

**Purpose**: Web interface for users to request movies and TV shows.

**Key Features**:
- User-friendly request interface
- Plex integration for availability checking
- Webhook support for Riven integration
- Automatic library scanning

**Integration**:
- Plex: Monitors library availability
- Riven: Sends webhooks on media requests
- Radarr/Sonarr: Optional integration

---

### Riven Database - PostgreSQL
**Container**: `riven-db`  
**IP**: 172.21.0.32 (default)  
**Port**: 5432

**Purpose**: Shared PostgreSQL database for Riven and Zilean.

**Databases**:
- `riven`: Riven's main database
- `zilean`: Zilean's database

---

### FlareSolverr - Cloudflare Bypass
**Container**: `flaresolverr`  
**IP**: 172.21.0.20 (default)

**Purpose**: Optional service for bypassing Cloudflare protection on some sites.

**Configuration**:
- Log Level: `${LOG_LEVEL}`
- Log HTML: `${LOG_HTML}`
- Captcha Solver: `${CAPTCHA_SOLVER}` (optional)

---

## Configuration

### Setup Process

1. **Run Setup Script**:
   ```bash
   ./setup.sh
   ```

2. **Configuration Categories**:
   - System (TZ, PUID, PGID)
   - Network (subnet, static IPs)
   - Traefik (domains, SSL, ports)
   - Database (credentials, database names)
   - Plex (URL, token)
   - Real-Debrid (API key)
   - Riven (API key, integrations)
   - Overseerr (API key)
   - Domains (FQDN and local)
   - Paths (all volume mounts)

3. **Generated Files**:
   - `.env`: Environment variables (contains secrets)
   - `.env.backup`: Backup of previous .env (if overwritten)

### Environment Variables

The setup script organizes variables by category. Key variables:

```bash
# System
TZ=America/New_York
PUID=1000
PGID=998

# Network
PLEX_NETWORK_SUBNET=172.21.0.0/16

# Traefik
TRAEFIK_IP=172.21.0.10
TRAEFIK_DOMAIN=traefik.example.com
TRAEFIK_ACME_EMAIL=your_email@example.com
CF_DNS_API_TOKEN=your_cloudflare_token

# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password
POSTGRES_DB_RIVEN=riven
POSTGRES_DB_ZILEAN=zilean

# Plex
PLEX_URL=http://192.168.1.100:32400
PLEX_URL_INTERNAL=http://192.168.1.100:32400
PLEX_TOKEN=your_plex_token

# Real-Debrid
REAL_DEBRID_API_KEY=your_real_debrid_token

# Riven
RIVEN_API_KEY=your_riven_api_key
RIVEN_CONTENT_OVERSEERR_ENABLED=true
RIVEN_CONTENT_PLEX_WATCHLIST_ENABLED=true
RIVEN_CONTENT_PLEX_WATCHLIST_UPDATE_INTERVAL=60
RIVEN_SCRAPING_ZILEAN_ENABLED=true
ZILEAN_URL=http://zilean:8181
RIVEN_WEBHOOK_OVERSEERR_URL=http://riven:8080/api/v1/webhook/overseerr

# Overseerr
OVERSEERR_URL=http://overseerr:5055
OVERSEERR_API_KEY=your_overseerr_api_key
```

### Manual Configuration

If you prefer manual configuration:

1. Copy example file:
   ```bash
   cp env.example .env
   ```

2. Edit `.env` with your values

3. Start services:
   ```bash
   docker compose up -d
   ```

---

## Integration & Webhooks

### Service Interconnections

| From Service | To Service | Type | Purpose |
|-------------|-----------|------|---------|
| Overseerr | Riven | Webhook | Media request notifications |
| Plex Watchlist | Riven | API Polling | Automatic watchlist monitoring |
| Riven | Zilean | HTTP API | Torrent scraping |
| Riven | Real-Debrid | External API | Download management |
| Real-Debrid | Zurg | API Polling | Download monitoring |
| Zurg | Rclone | WebDAV | Filesystem access |
| Rclone | Zurger | Filesystem | File organization |
| Zurger | Plex | HTTP API | Library updates |
| Zurg | Zurger | HTTP Webhook | Library change triggers |
| Riven | Plex | HTTP API | Library scans |

### Overseerr → Riven Webhook

**Purpose**: Automatically trigger downloads when media is requested in Overseerr.

**Configuration Steps**:

1. **Get Riven API Key**: From your `.env` file (`RIVEN_API_KEY`)

2. **Configure in Overseerr**:
   - Login to Overseerr
   - Go to: Settings → Notifications → Webhooks
   - Click "Add Webhook"
   - Configure:
     - **Name**: Riven Integration
     - **URL**: `http://riven:8080/api/v1/webhook/overseerr`
     - **Method**: POST
     - **Auth Header**: `Bearer ${RIVEN_API_KEY}`
   - **Enable Events**:
     - ✓ Media Requested
     - ✓ Media Available
     - ✓ Media Approved
     - ✓ Media Auto-Approved

3. **Test Webhook**:
   ```bash
   # From Overseerr container
   docker exec overseerr wget -q --spider http://riven:8080/api/v1/webhook/overseerr
   ```

### Plex Watchlist → Riven

**Purpose**: Automatically monitor Plex watchlists and download new items.

**Configuration**:

The setup script enables this by default. To verify:

1. **Check Environment Variables**:
   ```bash
   grep PLEX_WATCHLIST .env
   ```

2. **Verify in Riven**:
   - Login to Riven frontend
   - Go to: Settings → Content → Plex Watchlist
   - Ensure enabled: `true`
   - Update interval: `60` seconds

3. **How It Works**:
   - Riven polls Plex API every 60 seconds
   - Checks user watchlists for new items
   - Compares with existing downloads
   - Automatically triggers download workflow

### Riven → Zilean Integration

**Purpose**: Riven queries Zilean for torrent sources.

**Configuration**:
- Already configured via environment variables
- Zilean URL: `http://zilean:8181`
- Rate limiting: Enabled
- Timeout: 30 seconds

**Verification**:
```bash
docker exec riven wget -q --spider http://zilean:8181/healthchecks/ping
```

### Zurg → Zurger Trigger

**Purpose**: Trigger Zurger when Zurg detects library changes.

**Configuration**:
- Configured in Zurg `config.yml`:
  ```yaml
  on_library_update: sh /nfs/media/zurger/trigger.sh
  ```
- Trigger script: `/nfs/media/zurger/trigger.sh`
- Trigger URL: `http://zurger:8000/scan/all`

**Verification**:
```bash
# Check trigger script exists
ls -la /nfs/media/zurger/trigger.sh

# Test trigger
curl http://zurger:8000/scan/all
```

---

## Network & Infrastructure

### Network Architecture

All services run on the `plex_network` network (default: `172.21.0.0/16`).

**Network Isolation**:
- Separate from main `home_lab` network
- Ensures service isolation
- Static IPs for reliable connectivity

### Static IP Assignment

| Service | Default IP | Ports |
|---------|-----------|-------|
| traefik | 172.21.0.10 | 80, 443, 8088 |
| zurg | 172.21.0.25 | 9999, 8000 |
| zurger | 172.21.0.26 | 8000, 6464 |
| zilean | 172.21.0.28 | 8181 |
| overseerr | 172.21.0.29 | 5055, 5056 |
| riven-frontend | 172.21.0.30 | 3000 |
| riven | 172.21.0.31 | 8080, 8085 |
| riven-db | 172.21.0.32 | 5432 |
| rclone | 172.21.0.43 | - |
| flaresolverr | 172.21.0.20 | - |

All IPs are configurable during setup.

### Domain Configuration

Each service supports both FQDN and local domains:

- **FQDN**: For external access (e.g., `zurg.example.com`)
- **Local**: For internal access (e.g., `zurg.local`)

Traefik routes based on the domain used, allowing flexible access patterns.

### Service URLs

After configuration, services are available via Traefik:

- **Traefik Dashboard**: `https://${TRAEFIK_DOMAIN}:8088`
- **Zurg**: `https://${ZURG_DOMAIN}` or `https://${ZURG_LOCAL_DOMAIN}`
- **Zurger**: `https://${ZURGER_DOMAIN}` or `https://${ZURGER_LOCAL_DOMAIN}`
- **Zilean**: `https://${ZILEAN_DOMAIN}` or `https://${ZILEAN_LOCAL_DOMAIN}`
- **Overseerr**: `https://${OVERSEERR_DOMAIN}` or `https://${OVERSEERR_LOCAL_DOMAIN}`
- **Riven**: `https://${RIVEN_DOMAIN}` or `https://${RIVEN_LOCAL_DOMAIN}`

---

## Usage

### Starting Services

```bash
# Start all services
docker compose up -d

# Start specific service
docker compose up -d riven

# Start with logs
docker compose up
```

### Stopping Services

```bash
# Stop all services
docker compose down

# Stop specific service
docker compose stop riven

# Stop and remove volumes (⚠️ deletes data)
docker compose down -v
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f riven

# Last 100 lines
docker compose logs --tail=100 riven

# Since specific time
docker compose logs --since 10m riven
```

### Restarting Services

```bash
# Restart all services
docker compose restart

# Restart specific service
docker compose restart riven

# Restart with recreation
docker compose up -d --force-recreate riven
```

### Service Status

```bash
# Check all services
docker compose ps

# Check specific service
docker compose ps riven

# Check service health
docker compose ps --format json | jq '.[] | select(.Health != "healthy")'
```

### Testing Connectivity

```bash
# Test Overseerr → Riven
docker exec overseerr ping -c 1 riven

# Test Riven → Zilean
docker exec riven wget -q --spider http://zilean:8181/healthchecks/ping

# Test Riven → Overseerr
docker exec riven wget -q --spider http://overseerr:5055/api/v1/status

# Test Database
docker exec riven pg_isready -h riven-db -p 5432
```

---

## Troubleshooting

### Services Won't Start

**Symptoms**: Services fail to start or exit immediately

**Solutions**:
1. Check network exists:
   ```bash
   docker network ls | grep plex_network
   ```
   If missing, create it:
   ```bash
   docker network create --subnet=172.21.0.0/16 plex_network
   ```

2. Verify environment variables:
   ```bash
   docker compose config
   ```

3. Check logs:
   ```bash
   docker compose logs [service-name]
   ```

4. Verify paths exist:
   ```bash
   # Check paths from .env
   grep PATH .env | while read line; do
     path=$(echo $line | cut -d'=' -f2)
     test -e "$path" && echo "✓ $path" || echo "✗ $path (missing)"
   done
   ```

### Webhook Not Working

**Symptoms**: Overseerr requests don't trigger downloads

**Solutions**:
1. Verify Riven API key matches:
   ```bash
   # In Overseerr webhook config
   Auth Header: Bearer $(grep RIVEN_API_KEY .env | cut -d'=' -f2)
   ```

2. Test connectivity:
   ```bash
   docker exec overseerr wget -q --spider http://riven:8080/api/v1/webhook/overseerr
   ```

3. Check Riven logs:
   ```bash
   docker compose logs riven | grep webhook
   ```

4. Verify webhook URL uses service name (not IP):
   - Correct: `http://riven:8080/api/v1/webhook/overseerr`
   - Wrong: `http://172.21.0.31:8080/api/v1/webhook/overseerr`

### Plex Watchlist Not Triggering

**Symptoms**: Items added to watchlist don't download

**Solutions**:
1. Verify Plex watchlist is enabled:
   ```bash
   grep PLEX_WATCHLIST .env
   ```

2. Check Plex token is valid:
   ```bash
   curl -s "http://${PLEX_URL}/library/sections?X-Plex-Token=${PLEX_TOKEN}"
   ```

3. Verify Plex URL is accessible:
   ```bash
   docker exec riven ping -c 1 $(grep PLEX_URL_INTERNAL .env | cut -d'=' -f2 | sed 's|http://||' | cut -d':' -f1)
   ```

4. Check Riven logs for watchlist polling:
   ```bash
   docker compose logs riven | grep -i watchlist
   ```

### Rclone Mount Fails

**Symptoms**: Rclone container exits or mount not accessible

**Solutions**:
1. Ensure Zurg is running:
   ```bash
   docker compose ps zurg
   ```

2. Check FUSE is available:
   ```bash
   ls -la /dev/fuse
   ```

3. Verify rclone config exists:
   ```bash
   test -f $(grep RCLONE_CONFIG_PATH .env | cut -d'=' -f2) && echo "Config exists" || echo "Config missing"
   ```

4. Check Zurg WebDAV is accessible:
   ```bash
   docker exec rclone curl -s http://zurg:9999/dav
   ```

5. Review rclone logs:
   ```bash
   docker compose logs rclone
   ```

### Database Connection Issues

**Symptoms**: Riven or Zilean can't connect to database

**Solutions**:
1. Wait for database to be healthy:
   ```bash
   docker compose ps riven-db
   # Should show "healthy" status
   ```

2. Check database logs:
   ```bash
   docker compose logs riven-db
   ```

3. Verify credentials:
   ```bash
   docker exec riven-db psql -U $(grep POSTGRES_USER .env | cut -d'=' -f2) -d $(grep POSTGRES_DB_RIVEN .env | cut -d'=' -f2) -c "SELECT 1;"
   ```

4. Test connection from service:
   ```bash
   docker exec riven pg_isready -h riven-db -p 5432
   ```

### Downloads Not Processing

**Symptoms**: Downloads complete but don't appear in library

**Solutions**:
1. Verify Real-Debrid API key:
   ```bash
   # Check in .env
   grep REAL_DEBRID_API_KEY .env
   ```

2. Check Zurg is monitoring:
   ```bash
   docker compose logs zurg | tail -20
   ```

3. Verify rclone mount:
   ```bash
   docker exec rclone ls /data/__all__ | head -5
   ```

4. Check Zurger can access mount:
   ```bash
   docker exec zurger ls /nfs/data/docker/storageRD/torrents | head -5  # Container path
   ```

5. Verify Plex library paths:
   ```bash
   docker exec zurger ls /nfs/media/plex/movies | head -5  # Container path
   docker exec zurger ls /nfs/media/plex/shows | head -5  # Container path
   ```

### Library Not Updating

**Symptoms**: Files organized but Plex doesn't see them

**Solutions**:
1. Verify Plex token has permissions:
   ```bash
   curl -s "http://${PLEX_URL}/library/sections?X-Plex-Token=${PLEX_TOKEN}"
   ```

2. Check trigger scripts are executable:
   ```bash
   ls -la /nfs/media/zurger/trigger.sh
   chmod +x /nfs/media/zurger/trigger.sh
   ```

3. Manually trigger Plex scan:
   ```bash
   curl "http://${PLEX_URL}/library/sections/all/refresh?X-Plex-Token=${PLEX_TOKEN}"
   ```

4. Check Zurger logs:
   ```bash
   docker compose logs zurger | tail -20
   ```

### Traefik SSL Issues

**Symptoms**: SSL certificates not generating

**Solutions**:
1. Verify Cloudflare token:
   ```bash
   grep CF_DNS_API_TOKEN .env
   ```

2. Check DNS challenge:
   ```bash
   docker compose logs traefik | grep -i acme
   ```

3. Verify domain DNS points to server:
   ```bash
   dig ${TRAEFIK_DOMAIN}
   ```

4. Check Let's Encrypt storage:
   ```bash
   ls -la $(grep TRAEFIK_LETSENCRYPT_PATH .env | cut -d'=' -f2)
   ```

---

## Reference

### File Structure

```
home_plex/
├── docker-compose.yml      # Main compose file
├── env.example            # Environment template
├── setup.sh               # Interactive setup script
├── configure-webhooks.sh  # Webhook configuration helper
├── README.md              # This file
├── .env                   # Generated environment file (not in repo)
└── .gitignore            # Excludes .env files
```

### Key Paths

| Purpose | Default Path (Host) |
|---------|-------------|
| Zurg Config | `~/Docker/zurg/config.yml` |
| Zurg Data | `~/Docker/zurg/` |
| Zurger Config | `~/Docker/zurger/config.ini` |
| Rclone Config | `~/Docker/rclone/rclone.conf` |
| Storage Torrents | `~/Docker/storageRD/torrents` |
| Plex Library | `~/plex` |
| Zilean Data | `~/Docker/zilean` |
| Overseerr Config | `~/Docker/overseerr/config` |
| Riven Data | `~/Docker/riven/data` |
| Riven DB | `~/Docker/riven-db` |
| Traefik Let's Encrypt | `~/Docker/traefik/letsencrypt` |

### Port Reference

| Service | Internal Port | Host Port | Purpose |
|---------|--------------|-----------|---------|
| Traefik | 80 | 80 | HTTP |
| Traefik | 443 | 443 | HTTPS |
| Traefik | 8080 | 8088 | Dashboard |
| Zurg | 9999 | 9999 | WebDAV/HTTP |
| Zurg | 8000 | - | Web UI |
| Zurger | 8000 | 6464 | Web UI |
| Zilean | 8181 | 8181 | API |
| Overseerr | 5055 | 5056 | Web UI |
| Riven | 8080 | 8085 | API |
| Riven Frontend | 3000 | 3000 | Web UI |
| Riven DB | 5432 | - | PostgreSQL |

### Environment Variable Reference

See `env.example` for complete list. Key variables:

- **System**: `TZ`, `PUID`, `PGID`
- **Network**: `PLEX_NETWORK_SUBNET`, `*_IP` (for each service)
- **Traefik**: `TRAEFIK_*`
- **Database**: `POSTGRES_*`
- **Plex**: `PLEX_*`
- **Real-Debrid**: `REAL_DEBRID_API_KEY`
- **Riven**: `RIVEN_*`
- **Overseerr**: `OVERSEERR_*`
- **Domains**: `*_DOMAIN`, `*_LOCAL_DOMAIN`
- **Paths**: `*_PATH`

### Common Commands

```bash
# Setup
./setup.sh

# Start/Stop
docker compose up -d
docker compose down

# Logs
docker compose logs -f [service]

# Restart
docker compose restart [service]

# Status
docker compose ps

# Config validation
docker compose config

# Shell access
docker exec -it [service] sh

# Network inspection
docker network inspect plex_network
```

### Support & Documentation

- **Integration Guide**: See `integration-config.md` (if exists)
- **Service Details**: See `ENTERTAINMENT_SETUP.md` (if exists)
- **Interconnections**: See `INTERCONNECTIONS.md` (if exists)

### Security Notes

⚠️ **Important Security Considerations**:

1. **`.env` File**: Contains sensitive information (API keys, passwords, tokens)
   - Never commit to version control
   - Keep secure and backed up
   - Restrict file permissions: `chmod 600 .env`

2. **Network Isolation**: Services run on isolated `plex_network`
   - Separate from main infrastructure
   - Static IPs prevent conflicts

3. **Traefik**: Handles SSL termination
   - Automatic certificate renewal
   - HTTPS enforced for all services

4. **API Keys**: Rotate regularly
   - Real-Debrid API token
   - Plex tokens
   - Riven API key
   - Overseerr API key

---

## License & Credits

This stack combines multiple open-source projects:
- [Zurg](https://github.com/debridmediamanager/zurg) - Real-Debrid manager
- [Riven](https://github.com/spoked/riven) - Automation orchestrator
- [Zilean](https://github.com/ipromknight/zilean) - Torrent scraping
- [Overseerr](https://github.com/sct/overseerr) - Media requests
- [Traefik](https://traefik.io/) - Reverse proxy
- [Rclone](https://rclone.org/) - Cloud storage sync

---

**Last Updated**: 2024-12-27  
**Version**: 1.0
