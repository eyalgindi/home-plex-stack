# Service Integration Configuration Guide

This document outlines all the inter-service connections, webhooks, and integrations required for seamless automation.

## Complete Workflow

```
Plex Watchlist → Riven → Zilean (scraping) → Real-Debrid → Zurg → Rclone → Zurger → Plex Library
     ↓              ↓
Overseerr → Riven (webhook) → [same flow]
```

## Required Interconnections

### 1. Overseerr → Riven (Webhook)
**Purpose**: When a user requests media in Overseerr, it sends a webhook to Riven

**Configuration**:
- **Overseerr Webhook URL**: `http://riven:8080/api/v1/webhook/overseerr`
- **Riven API Key**: Must match in both services
- **Auth Header**: `Bearer ${RIVEN_API_KEY}`

**Setup**:
1. In Overseerr settings → Notifications → Webhooks
2. Add webhook: `http://riven:8080/api/v1/webhook/overseerr`
3. Set Auth Header: `Bearer ${RIVEN_API_KEY}`
4. Enable for: Media Requested, Media Available

### 2. Plex Watchlist → Riven
**Purpose**: Monitor Plex watchlist and automatically download items

**Configuration**:
- **Riven Settings**: Enable `plex_watchlist` content source
- **Update Interval**: 60 seconds (recommended)
- **Plex Token**: Required for API access
- **Plex URL**: Internal network address

**Setup**:
1. In Riven settings → Content → Plex Watchlist
2. Enable: `true`
3. Set update interval: `60` seconds
4. Configure Plex connection (uses existing Plex updater settings)

### 3. Riven → Zilean (Scraping)
**Purpose**: Riven queries Zilean for torrent sources

**Configuration**:
- **Zilean URL**: `http://zilean:8181`
- **Riven Settings**: Enable Zilean scraping
- **Timeout**: 30 seconds
- **Rate Limiting**: Enabled

**Setup**:
- Already configured via environment variables
- Ensure Zilean is accessible from Riven container

### 4. Riven → Real-Debrid (Download)
**Purpose**: Riven sends torrents to Real-Debrid for downloading

**Configuration**:
- **Real-Debrid API Key**: Configured in Riven
- **Enabled**: `true`
- **Size Limits**: Movies (700MB+), Episodes (100MB+)

**Setup**:
- Configured via `REAL_DEBRID_API_KEY` environment variable

### 5. Real-Debrid → Zurg (Management)
**Purpose**: Zurg monitors and organizes Real-Debrid downloads

**Configuration**:
- **Zurg Token**: Real-Debrid API token
- **Check Interval**: 15 seconds
- **Auto-repair**: Enabled
- **Library Update Trigger**: Configured

**Setup**:
- Configured in Zurg config.yml
- Uses Real-Debrid API token

### 6. Zurg → Rclone (Mount)
**Purpose**: Rclone mounts Zurg's WebDAV interface as filesystem

**Configuration**:
- **Rclone Config**: WebDAV endpoint to Zurg
- **Mount Point**: `/nfs/data/docker/storageRD/torrents`
- **Zurg WebDAV**: `http://zurg:9999/dav`

**Setup**:
- Configured in rclone.conf
- Mount command in docker-compose.yml

### 7. Rclone → Zurger (Organization)
**Purpose**: Zurger reads from rclone mount and organizes files

**Configuration**:
- **Torrents Path**: `/nfs/data/docker/storageRD/torrents` (read-only)
- **Plex Library Path**: `/nfs/media/plex` (read-write)
- **TMDB API**: For metadata matching

**Setup**:
- Configured in zurger config.ini
- Reads from rclone mount
- Writes to Plex library directories

### 8. Zurger → Plex (Library Update)
**Purpose**: Zurger triggers Plex library scans after organizing files

**Configuration**:
- **Plex URL**: `http://${PLEX_HOST}:32400`
- **Plex Token**: Required
- **Trigger URL**: `http://${PLEX_HOST}:32400/library/sections/all/refresh`

**Setup**:
- Configured in zurger config.ini
- Trigger script: `/nfs/media/zurger/trigger.sh`

### 9. Riven → Plex (Library Update)
**Purpose**: Riven triggers Plex library scans after creating symlinks

**Configuration**:
- **Plex URL**: Internal network address
- **Plex Token**: Required
- **Update Interval**: 120 seconds

**Setup**:
- Configured via environment variables
- Riven automatically updates Plex when symlinks are created

### 10. Zurg → Zurger (Library Update Trigger)
**Purpose**: When Zurg detects library changes, it triggers Zurger

**Configuration**:
- **Zurg Config**: `on_library_update` hook
- **Trigger Script**: `/nfs/media/zurger/trigger.sh`
- **Trigger URL**: `http://zurger:8000/scan/all`

**Setup**:
- Configured in zurg config.yml
- Trigger script must be executable

## Network Connectivity Requirements

All services must be able to communicate on the `plex_network`:

```
Traefik (172.21.0.10) → All services (routing)
Riven (172.21.0.31) → Overseerr (172.21.0.29), Zilean (172.21.0.28), riven-db (172.21.0.32)
Zilean (172.21.0.28) → riven-db (172.21.0.32)
Rclone (172.21.0.43) → Zurg (172.21.0.25)
Zurger (172.21.0.26) → Zurg (172.21.0.25), Plex (external)
Zurg (172.21.0.25) → Real-Debrid (external API)
```

## Environment Variables for Integration

```bash
# Riven Configuration
RIVEN_API_KEY=your_api_key
RIVEN_CONTENT_OVERSEERR_ENABLED=true
RIVEN_SCRAPING_ZILEAN_ENABLED=true
ZILEAN_URL=http://zilean:8181
OVERSEERR_URL=http://overseerr:5055
OVERSEERR_API_KEY=your_overseerr_api_key

# Plex Configuration
PLEX_URL=http://192.168.1.100:32400
PLEX_URL_INTERNAL=http://192.168.1.100:32400
PLEX_TOKEN=your_plex_token

# Real-Debrid
REAL_DEBRID_API_KEY=your_real_debrid_token

# Zurg Configuration (in config.yml)
token: your_real_debrid_token
on_library_update: sh /nfs/media/zurger/trigger.sh
```

## Webhook Configuration

### Overseerr Webhook Setup
1. Login to Overseerr
2. Go to Settings → Notifications → Webhooks
3. Add new webhook:
   - **Name**: Riven Integration
   - **URL**: `http://riven:8080/api/v1/webhook/overseerr`
   - **Method**: POST
   - **Auth Header**: `Bearer ${RIVEN_API_KEY}`
   - **Events**: 
     - Media Requested
     - Media Available
     - Media Approved
     - Media Auto-Approved

### Riven Webhook Endpoint
- **Endpoint**: `/api/v1/webhook/overseerr`
- **Method**: POST
- **Authentication**: Bearer token (RIVEN_API_KEY)
- **Payload**: Overseerr webhook JSON

## Plex Watchlist Monitoring

To enable Plex watchlist monitoring in Riven:

1. **Via Riven Settings JSON** (`/nfs/data/docker/riven/data/settings.json`):
```json
"plex_watchlist": {
    "update_interval": 60,
    "enabled": true,
    "rss": []
}
```

2. **Requirements**:
   - Plex updater must be configured
   - Plex token must be valid
   - Plex URL must be accessible from Riven container

3. **How it works**:
   - Riven polls Plex API every 60 seconds
   - Checks for new items in user watchlists
   - Automatically triggers download workflow
   - Processes movies and TV shows

## Verification Checklist

- [ ] Overseerr can reach Riven webhook endpoint
- [ ] Riven can reach Zilean API
- [ ] Riven can reach Overseerr API
- [ ] Riven can reach Plex API
- [ ] Rclone can mount Zurg WebDAV
- [ ] Zurger can read from rclone mount
- [ ] Zurger can write to Plex library
- [ ] Zurger can trigger Plex library scans
- [ ] Zurg can trigger Zurger via script
- [ ] All services on same network (plex_network)
- [ ] All internal URLs use service names or IPs
- [ ] All API keys and tokens configured
- [ ] Plex watchlist monitoring enabled (if desired)

## Troubleshooting

### Webhook not working
- Check Riven API key matches in both services
- Verify network connectivity: `docker exec riven ping overseerr`
- Check Riven logs: `docker compose logs riven`
- Verify webhook URL uses internal network address

### Plex watchlist not triggering
- Verify Plex updater is enabled in Riven
- Check Plex token is valid
- Verify Plex URL is accessible from Riven
- Check Riven logs for watchlist polling errors

### Downloads not processing
- Verify Real-Debrid API key is correct
- Check Zurg is monitoring Real-Debrid
- Verify rclone mount is working
- Check Zurger can access rclone mount
- Verify Plex library paths are correct



