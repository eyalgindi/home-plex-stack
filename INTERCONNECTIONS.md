# Service Interconnections Map

This document provides a visual map of all service interconnections, webhooks, and data flows.

## Complete Integration Flow

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
            └──► /nfs/media/plex (Plex Library)
                 │
                 └──► Triggers Plex library scan

Real-Debrid ──► Zurg (Monitors downloads)
                 │
                 ├──► WebDAV: http://zurg:9999/dav
                 │    └──► Rclone (Mounts as filesystem)
                 │         └──► /nfs/data/docker/storageRD/torrents
                 │              │
                 │              └──► Zurger (Reads & organizes)
                 │                   │
                 │                   ├──► Moves to Plex library
                 │                   └──► Triggers Plex scan
                 │
                 └──► Library update trigger
                      └──► Zurger (http://zurger:8000/scan/all)
```

## Service-to-Service Connections

### 1. Overseerr → Riven (Webhook)
- **Type**: HTTP Webhook
- **URL**: `http://riven:8080/api/v1/webhook/overseerr`
- **Method**: POST
- **Auth**: Bearer token (RIVEN_API_KEY)
- **Trigger**: Media requested/approved in Overseerr
- **Action**: Riven starts download workflow

### 2. Plex Watchlist → Riven (Polling)
- **Type**: API Polling
- **URL**: `http://${PLEX_URL_INTERNAL}/library/sections/all/all`
- **Interval**: 60 seconds (configurable)
- **Trigger**: New item added to Plex watchlist
- **Action**: Riven detects and starts download workflow

### 3. Riven → Zilean (Scraping)
- **Type**: HTTP API
- **URL**: `http://zilean:8181`
- **Purpose**: Query for torrent sources
- **Method**: GET/POST
- **Rate Limited**: Yes

### 4. Riven → Real-Debrid (Download)
- **Type**: External API
- **URL**: `https://api.real-debrid.com`
- **Purpose**: Submit torrents for downloading
- **Auth**: API Key (REAL_DEBRID_API_KEY)

### 5. Real-Debrid → Zurg (Monitoring)
- **Type**: API Polling
- **URL**: `https://api.real-debrid.com`
- **Interval**: 15 seconds
- **Purpose**: Monitor download status
- **Auth**: Real-Debrid API token

### 6. Zurg → Rclone (WebDAV)
- **Type**: WebDAV Protocol
- **URL**: `http://zurg:9999/dav`
- **Purpose**: Provide filesystem access to downloads
- **Mount Point**: `/nfs/data/docker/storageRD/torrents`

### 7. Rclone → Zurger (File Access)
- **Type**: Filesystem (read-only)
- **Path**: `/nfs/data/docker/storageRD/torrents`
- **Purpose**: Zurger reads organized content
- **Action**: Match with TMDB, organize, move to Plex

### 8. Zurger → Plex (Library Update)
- **Type**: HTTP API
- **URL**: `http://${PLEX_HOST}:32400/library/sections/all/refresh`
- **Method**: GET
- **Auth**: Plex Token
- **Trigger**: After file organization

### 9. Zurg → Zurger (Library Update Trigger)
- **Type**: HTTP Webhook
- **URL**: `http://zurger:8000/scan/all`
- **Method**: GET/POST
- **Trigger**: When Zurg detects library changes
- **Config**: `on_library_update` in zurg config.yml

### 10. Riven → Plex (Library Update)
- **Type**: HTTP API
- **URL**: `http://${PLEX_URL_INTERNAL}/library/sections/all/refresh`
- **Method**: GET
- **Auth**: Plex Token
- **Interval**: 120 seconds (after symlink creation)

### 11. Riven → Riven-DB (Database)
- **Type**: PostgreSQL Connection
- **Host**: `riven-db`
- **Port**: `5432`
- **Database**: `riven`
- **Purpose**: Store download state, metadata

### 12. Zilean → Riven-DB (Database)
- **Type**: PostgreSQL Connection
- **Host**: `riven-db`
- **Port**: `5432`
- **Database**: `zilean`
- **Purpose**: Store scraped torrent metadata

## Network Communication Matrix

| From Service | To Service | Protocol | Port | Purpose |
|-------------|-----------|----------|------|---------|
| Overseerr | Riven | HTTP | 8080 | Webhook |
| Riven | Zilean | HTTP | 8181 | Scraping API |
| Riven | Overseerr | HTTP | 5055 | Content API |
| Riven | Riven-DB | PostgreSQL | 5432 | Database |
| Riven | Plex | HTTP | 32400 | Library updates |
| Zilean | Riven-DB | PostgreSQL | 5432 | Database |
| Rclone | Zurg | WebDAV | 9999 | File access |
| Zurger | Zurg | HTTP | 9999 | Status check |
| Zurger | Plex | HTTP | 32400 | Library refresh |
| Zurg | Zurger | HTTP | 8000 | Library update trigger |
| Traefik | All Services | HTTP/HTTPS | Various | Reverse proxy |

## Environment Variables for Interconnections

```bash
# Riven Configuration
RIVEN_API_KEY=your_api_key
RIVEN_BACKEND_URL=http://riven:8080
RIVEN_WEBHOOK_OVERSEERR_URL=http://riven:8080/api/v1/webhook/overseerr

# Content Sources
RIVEN_CONTENT_OVERSEERR_ENABLED=true
RIVEN_CONTENT_OVERSEERR_URL=http://overseerr:5055
RIVEN_CONTENT_OVERSEERR_API_KEY=your_overseerr_api_key
RIVEN_CONTENT_PLEX_WATCHLIST_ENABLED=true
RIVEN_CONTENT_PLEX_WATCHLIST_UPDATE_INTERVAL=60

# Scraping
RIVEN_SCRAPING_ZILEAN_ENABLED=true
ZILEAN_URL=http://zilean:8181

# Plex
PLEX_URL=http://192.168.1.100:32400
PLEX_URL_INTERNAL=http://192.168.1.100:32400
PLEX_TOKEN=your_plex_token

# Real-Debrid
REAL_DEBRID_API_KEY=your_real_debrid_token
```

## Webhook Configuration

### Overseerr Webhook Setup

1. **Login to Overseerr**
2. **Navigate to**: Settings → Notifications → Webhooks
3. **Add Webhook**:
   ```
   Name: Riven Integration
   URL: http://riven:8080/api/v1/webhook/overseerr
   Method: POST
   Auth Header: Bearer ${RIVEN_API_KEY}
   ```
4. **Enable Events**:
   - ✓ Media Requested
   - ✓ Media Available
   - ✓ Media Approved
   - ✓ Media Auto-Approved

### Webhook Payload Example

```json
{
  "notification_type": "MEDIA_REQUESTED",
  "event": "media.request",
  "subject": "New Movie Request",
  "message": "User requested: Movie Title",
  "media": {
    "media_type": "movie",
    "tmdbId": 12345,
    "status": "pending"
  },
  "request": {
    "request_id": 123,
    "requestedBy_email": "user@example.com"
  }
}
```

## Plex Watchlist Integration

### How It Works

1. **Riven polls Plex API** every 60 seconds (configurable)
2. **Checks user watchlists** for new items
3. **Compares with existing downloads** to avoid duplicates
4. **Triggers download workflow** for new items
5. **Processes automatically** through the full pipeline

### Configuration

Enable in Riven settings:
```json
{
  "content": {
    "plex_watchlist": {
      "update_interval": 60,
      "enabled": true,
      "rss": []
    }
  }
}
```

Or via environment variables:
```bash
RIVEN_CONTENT_PLEX_WATCHLIST_ENABLED=true
RIVEN_CONTENT_PLEX_WATCHLIST_UPDATE_INTERVAL=60
```

## Verification Commands

### Test Service Connectivity

```bash
# Test Overseerr → Riven
docker exec overseerr wget -q --spider http://riven:8080/api/v1/webhook/overseerr

# Test Riven → Zilean
docker exec riven wget -q --spider http://zilean:8181/healthchecks/ping

# Test Riven → Overseerr
docker exec riven wget -q --spider http://overseerr:5055/api/v1/status

# Test Rclone → Zurg
docker exec rclone curl -s http://zurg:9999/dav

# Test Database connectivity
docker exec riven pg_isready -h riven-db -p 5432
```

### Check Webhook Logs

```bash
# Riven webhook logs
docker compose logs riven | grep webhook

# Overseerr webhook logs
docker compose logs overseerr | grep webhook
```

## Troubleshooting Interconnections

### Webhook Not Working
1. Verify Riven API key matches in both services
2. Check network: `docker exec overseerr ping riven`
3. Verify webhook URL uses service name, not IP
4. Check Riven logs: `docker compose logs riven`

### Plex Watchlist Not Triggering
1. Verify Plex updater is enabled in Riven
2. Check Plex token is valid
3. Verify Plex URL is accessible from Riven
4. Check Riven logs for watchlist polling

### Downloads Not Processing
1. Verify Real-Debrid API key
2. Check Zurg is monitoring Real-Debrid
3. Verify rclone mount is working
4. Check Zurger can access rclone mount

### Library Not Updating
1. Verify Plex library paths are correct
2. Check Zurger can write to Plex library
3. Verify Plex token has library update permissions
4. Check trigger scripts are executable

## Complete Workflow Example

**Scenario**: User adds movie to Plex watchlist

1. **Plex**: Movie added to watchlist
2. **Riven**: Polls Plex API, detects new watchlist item
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

