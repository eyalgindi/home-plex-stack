# Entertainment Setup Documentation

## Overview
This document explains the complete entertainment/media management stack, including all services, their configurations, and how they interact with each other.

## Architecture Diagram

```
┌─────────────┐
│  Overseerr  │ ──► User requests media
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│   Riven    │ ◄───│   Zilean    │ ──► Scrapes torrents
└──────┬──────┘     └─────────────┘
       │
       ▼
┌─────────────┐
│ Real-Debrid │ ──► Downloads torrents
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Zurg     │ ──► Manages Real-Debrid content
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Rclone    │ ──► Mounts Zurg as filesystem
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Zurger    │ ──► Organizes & moves files
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Plex     │ ──► Media server (on host)
└─────────────┘
```

## Services Breakdown

### 1. **Zurg** (Real-Debrid Media Manager)
**Container**: `zurg`  
**IP**: 172.20.0.25  
**Port**: 9999 (internal), 8000 (web UI)  
**URL**: https://zurg.gindi.us

**Purpose**: Manages Real-Debrid torrents and provides WebDAV/HTTP access to downloaded content.

**Configuration** (`/nfs/data/docker/zurg/config.yml`):
- **Token**: Real-Debrid API token (WHQMY3T43SX6BR5CTLS3AO2WWELYR2SFILKO7XG6FH7NBMZSQD3Q)
- **Directories**: Organizes content into `anime`, `shows`, and `movies` groups
- **Auto-repair**: Enabled to fix broken downloads
- **Library update trigger**: Executes `/nfs/media/zurger/trigger.sh` when library updates

**Key Features**:
- Monitors Real-Debrid for new downloads
- Organizes content by type (anime, shows, movies)
- Provides WebDAV endpoint at `/dav` and HTTP endpoint at `/http`
- Auto-deletes RAR torrents after extraction

**Volumes**:
- `/nfs/data/docker/zurg/config.yml` → Config file
- `/nfs/data/docker/zurg/` → Data directory
- `/nfs/media/zurger/` → Trigger scripts
- `/nfs` → Full NFS access

---

### 2. **Zurger** (Media Organization Interface)
**Container**: `zurger`  
**IP**: 172.20.0.26  
**Port**: 8000 (internal), 6464 (host)  
**URL**: https://zurger.gindi.us

**Purpose**: Custom web interface for organizing and managing media files from Real-Debrid downloads.

**Configuration** (`/nfs/data/docker/zurger/config.ini`):
- **Plex URL**: http://192.168.1.100:32400
- **Plex Token**: Ra_JTMsmxiTcSuKyXiNj
- **TMDB API Key**: adc28607024836b4a27a03e0cc7f2b61
- **Media Directories**:
  - Shows: `/nfs/media/plex/shows`
  - Movies: `/nfs/media/plex/movies`
  - Torrents: `/nfs/data/docker/storageRD/torrents/`
- **Trigger URL**: http://192.168.1.100:6464/scan/all

**Key Features**:
- Reads torrents from rclone mount
- Matches content with TMDB metadata
- Moves/organizes files to Plex library structure
- Triggers Plex library scans

**Volumes**:
- `/nfs/data/docker/storageRD/torrents` → Read-only access to rclone mount
- `/nfs/media/plex` → Plex library (read-write)
- `/nfs/data/docker/zurger/templates` → Web UI templates
- `/nfs/data/docker/zurger/config.ini` → Configuration

**Relationships**:
- Reads from: Rclone mount (Zurg content)
- Writes to: Plex library directories
- Triggers: Plex library scans

---

### 3. **Rclone** (Filesystem Mount)
**Container**: `rclone`  
**IP**: 172.20.0.43  
**Mount Point**: `/nfs/data/docker/storageRD/torrents`

**Purpose**: Mounts Zurg's WebDAV interface as a local filesystem so other services can access Real-Debrid content.

**Configuration** (`/nfs/data/docker/rclone/rclone.conf`):
```ini
[zurg]
type = webdav
url = http://192.168.1.100:9999/dav
vendor = other
pacer_min_sleep = 0

[zurghttp]
type = http
url = http://192.168.1.100:9999/http
```

**Mount Command**:
```bash
mount zurg: /data --uid 1000 --gid 998 --allow-other --allow-non-empty \
  --dir-cache-time 10s --vfs-cache-mode off --buffer-size 0M \
  --vfs-read-chunk-size 128M --vfs-read-chunk-size-limit 2G \
  --max-read-ahead 2M
```

**Key Features**:
- Mounts Zurg WebDAV as local filesystem
- Provides access to Real-Debrid downloads
- Used by Zurger and Riven to access content

**Dependencies**:
- Requires `zurg` container to be running
- Uses FUSE for filesystem mounting

**Relationships**:
- Mounts: Zurg WebDAV endpoint
- Provides: Filesystem access to Real-Debrid content
- Used by: Zurger, Riven

---

### 4. **Plex** (Media Server)
**Location**: Host machine (not in Docker)  
**IP**: 192.168.1.100  
**Port**: 32400  
**Server Name**: GindiPlex

**Purpose**: Media server that serves content to clients.

**Libraries**:
- Movies: `/nfs/media/plex/movies`
- TV Shows: `/nfs/media/plex/shows`

**Configuration**:
- Machine ID: `72c8751c528e116213349cb191a6ec378e4853de`
- Multiple tokens used by different services:
  - Zurger: `Ra_JTMsmxiTcSuKyXiNj`
  - Riven: `z-NMuEc1mMRARpswSd65`
  - Overseerr: Connected via OAuth

**Relationships**:
- Receives content from: Zurger (file organization)
- Scanned by: Zurger, Riven
- Connected to: Overseerr (for availability checking)

---

### 5. **Overseerr** (Media Request Manager)
**Container**: `overseerr`  
**IP**: 172.20.0.29  
**Port**: 5055 (internal), 5056 (host)  
**URL**: https://over.gindi.us

**Purpose**: Web interface for users to request movies and TV shows.

**Configuration** (`/nfs/data/docker/overseerr/config/settings.json`):
- **Plex Integration**:
  - Server: GindiPlex (192.168.1.100:32400)
  - Libraries: Movies (ID: 3), TV Shows (ID: 4)
- **Riven Integration**:
  - Webhook URL: http://172.20.0.31:8080/api/v1/webhook/overseerr
  - API Key: `MTc1MzY0NjgyMDY2MDI1NWVhN2E3LTRiODUtNGM3Ni04NTNlLWEyZDBhNWM5YzQ4OA==`
  - Auth Header: `Bearer 7fHANjt9jZw4AjQBvnK9cLKqlo6OCl75`
- **Radarr/Sonarr**: Currently empty arrays (not configured)

**Key Features**:
- Users request media through web interface
- Sends webhooks to Riven when requests are made
- Monitors Plex for availability
- Scans Plex libraries every 5 minutes

**Relationships**:
- Sends requests to: Riven (via webhook)
- Monitors: Plex library availability
- Users interact with: Web UI

---

### 6. **Riven** (Automation Orchestrator)
**Container**: `riven`  
**IP**: 172.20.0.31  
**Port**: 8080 (internal), 8085 (host)  
**URL**: https://riven.gindi.us (via frontend)

**Purpose**: Main automation service that coordinates downloads, scraping, and library updates.

**Configuration** (`/nfs/data/docker/riven/data/settings.json`):

**Content Sources**:
- **Overseerr**: Enabled
  - URL: http://overseerr:5055
  - API Key: `MTc1MzY0NjgyMDY2MDI1NWVhN2E3LTRiODUtNGM3Ni04NTNlLWEyZDBhNWM5YzQ4OA==`
  - Update interval: 10 seconds
  - Uses webhooks for real-time updates

**Downloaders**:
- **Real-Debrid**: Enabled
  - API Key: `WHQMY3T43SX6BR5CTLS3AO2WWELYR2SFILKO7XG6FH7NBMZSQD3Q`
  - Movie size: 700MB minimum
  - Episode size: 100MB minimum

**Scraping Sources**:
- **Zilean**: Enabled
  - URL: http://zilean:8181
  - Timeout: 30 seconds
  - Rate limited: Yes
- **Torrentio**: Enabled
  - URL: https://torrentio.strem.fun
  - Filter: Quality filtering (480p, scr, cam, unknown excluded)
- **Prowlarr**: Enabled
  - URL: http://prowlarr:9696
  - API Key: `d113c2109c8c4a0482f6910a966b7dd9`

**Symlink Management**:
- **Rclone Path**: `/nfs/data/docker/storageRD/torrents/__all__`
- **Library Path**: `/nfs/media/plex`
- **Repair Symlinks**: Enabled (every 6 hours)

**Plex Integration**:
- **Enabled**: Yes
- **URL**: http://192.168.1.100:32400
- **Token**: `z-NMuEc1mMRARpswSd65`
- **Update Interval**: 120 seconds

**Database**: PostgreSQL (riven-db container)

**Relationships**:
- Receives requests from: Overseerr (webhooks)
- Scrapes via: Zilean, Torrentio, Prowlarr
- Downloads via: Real-Debrid
- Creates symlinks: From rclone mount to Plex library
- Updates: Plex library

---

### 7. **Zilean** (Torrent Scraping Service)
**Container**: `zilean`  
**IP**: 172.20.0.28  
**Port**: 8181  
**URL**: https://zilean.gindi.us

**Purpose**: Scrapes and indexes torrents from various sources, provides API for Riven.

**Configuration** (`/nfs/data/docker/zilean/settings.json`):
- **DMM Integration**:
  - Enable Scraping: Yes
  - Scrape Schedule: Hourly (`0 * * * *`)
  - Minimum Score Match: 0.85
  - Max Filtered Results: 200
- **Database**: PostgreSQL (shared with Riven)
  - Host: riven-db
  - Database: zilean
- **Torznab Endpoint**: Enabled
- **IMDb Import**: Enabled (minimum score: 0.85)

**Key Features**:
- Scrapes torrents from configured sources
- Indexes torrent metadata
- Provides Torznab API for Riven
- Matches content with IMDb data

**Relationships**:
- Provides scraping data to: Riven
- Uses database: riven-db (PostgreSQL)
- Scrapes from: Various torrent sources

---

### 8. **Riven Frontend** (Web UI)
**Container**: `riven-frontend`  
**IP**: 172.20.0.30  
**Port**: 3000  
**URL**: https://riven.gindi.us

**Purpose**: Web interface for managing Riven.

**Configuration**:
- **Backend URL**: Configured via environment variable
- **Database**: Connects to riven-db
- **Origin**: Configured for CORS

**Relationships**:
- Connects to: Riven backend (172.20.0.31:8080)
- Uses database: riven-db

---

### 9. **Riven Database** (PostgreSQL)
**Container**: `riven-db`  
**IP**: 172.20.0.32  
**Port**: 5432

**Purpose**: Shared PostgreSQL database for Riven and Zilean.

**Databases**:
- `riven`: Riven's main database
- `zilean`: Zilean's database

**Relationships**:
- Used by: Riven, Zilean

---

## Data Flow

### Request Flow (User → Content)

1. **User Request**:
   - User opens Overseerr (https://over.gindi.us)
   - Requests a movie or TV show
   - Overseerr sends webhook to Riven

2. **Scraping**:
   - Riven receives request
   - Queries Zilean for torrents
   - Zilean returns matching torrents
   - Riven may also query Torrentio and Prowlarr

3. **Download**:
   - Riven selects best torrent
   - Sends magnet/torrent to Real-Debrid via API
   - Real-Debrid downloads the content

4. **Content Management**:
   - Zurg monitors Real-Debrid
   - When download completes, Zurg organizes it
   - Rclone mounts Zurg's WebDAV interface
   - Content appears in `/nfs/data/docker/storageRD/torrents/__all__`

5. **File Organization**:
   - Riven creates symlinks from rclone mount to Plex library
   - Symlinks placed in `/nfs/media/plex/movies` or `/nfs/media/plex/shows`
   - Zurger can also organize files (alternative workflow)

6. **Library Update**:
   - Riven triggers Plex library scan
   - Plex indexes new content
   - Content becomes available to users

### Alternative Workflow (Zurger)

1. Content appears in rclone mount
2. Zurger reads from mount
3. Zurger matches with TMDB metadata
4. Zurger moves/organizes files to Plex directories
5. Zurger triggers Plex scan via trigger URL

---

## Key Paths

### Storage Paths
- **Rclone Mount**: `/nfs/data/docker/storageRD/torrents`
- **Plex Library**: `/nfs/media/plex`
  - Movies: `/nfs/media/plex/movies`
  - TV Shows: `/nfs/media/plex/shows`
- **Zurg Data**: `/nfs/data/docker/zurg/`
- **Zurger Data**: `/nfs/data/docker/zurger/`

### Configuration Paths
- **Zurg Config**: `/nfs/data/docker/zurg/config.yml`
- **Zurger Config**: `/nfs/data/docker/zurger/config.ini`
- **Rclone Config**: `/nfs/data/docker/rclone/rclone.conf`
- **Riven Config**: `/nfs/data/docker/riven/data/settings.json`
- **Zilean Config**: `/nfs/data/docker/zilean/settings.json`
- **Overseerr Config**: `/nfs/data/docker/overseerr/config/settings.json`

---

## API Keys & Tokens

### Real-Debrid
- **API Token**: `WHQMY3T43SX6BR5CTLS3AO2WWELYR2SFILKO7XG6FH7NBMZSQD3Q`
  - Used by: Zurg, Riven

### Plex Tokens
- **Zurger Token**: `Ra_JTMsmxiTcSuKyXiNj`
- **Riven Token**: `z-NMuEc1mMRARpswSd65`
- **Overseerr**: Uses OAuth

### Service API Keys
- **Riven API Key**: `7fHANjt9jZw4AjQBvnK9cLKqlo6OCl75`
- **Overseerr API Key**: `MTc1MzY0NjgyMDY2MDI1NWVhN2E3LTRiODUtNGM3Ni04NTNlLWEyZDBhNWM5YzQ4OA==`
- **Zilean API Key**: `7afb847330474afb808d552ac827e60aa28962e78a62478db723f3bebb86b57e`
- **Prowlarr API Key**: `d113c2109c8c4a0482f6910a966b7dd9`
- **TMDB API Key**: `adc28607024836b4a27a03e0cc7f2b61`

---

## Network Architecture

All services run on the `home_lab` network (172.20.0.0/16):

- **Zurg**: 172.20.0.25
- **Zurger**: 172.20.0.26
- **Zilean**: 172.20.0.28
- **Overseerr**: 172.20.0.29
- **Riven Frontend**: 172.20.0.30
- **Riven**: 172.20.0.31
- **Riven DB**: 172.20.0.32
- **Rclone**: 172.20.0.43

**Plex** runs on host: 192.168.1.100:32400

---

## Service Dependencies

```
riven-db (PostgreSQL)
  ├── riven (depends on: riven-db)
  ├── riven-frontend (depends on: riven-db)
  └── zilean (depends on: riven-db)

zurg
  └── rclone (depends on: zurg)

riven
  ├── Uses: zilean (for scraping)
  ├── Uses: overseerr (for content requests)
  └── Uses: real-debrid (for downloads)

zurger
  ├── Reads from: rclone mount
  └── Writes to: Plex library
```

---

## Notes

1. **Radarr/Readarr**: Referenced in some configs (Bazarr) but not actively used in the main workflow. They may be running separately or not configured.

2. **Plex**: Runs on the host machine, not in Docker. All services connect to it at 192.168.1.100:32400.

3. **Symlink Strategy**: Riven creates symlinks from the rclone mount to the Plex library, allowing Plex to see content without moving files.

4. **Dual Organization**: Both Riven and Zurger can organize files. Riven uses symlinks, while Zurger can move files.

5. **Database Sharing**: Riven and Zilean share the same PostgreSQL instance but use different databases.

---

## Troubleshooting

### Content not appearing in Plex
1. Check if Riven created symlinks: `ls -la /nfs/media/plex/movies`
2. Check if Plex scan was triggered
3. Verify rclone mount is working: `ls /nfs/data/docker/storageRD/torrents/__all__`

### Downloads not completing
1. Check Zurg logs: `docker logs zurg`
2. Verify Real-Debrid API token is valid
3. Check Riven logs for download errors

### Scraping not working
1. Check Zilean health: `curl http://zilean:8181/healthchecks/ping`
2. Verify Zilean database connection
3. Check Riven scraping configuration

---

## Summary

This is a sophisticated media automation stack that:
- Accepts user requests via Overseerr
- Scrapes torrents via Zilean, Torrentio, and Prowlarr
- Downloads via Real-Debrid
- Manages downloads via Zurg
- Mounts content via Rclone
- Organizes content via Riven (symlinks) or Zurger (file moves)
- Serves content via Plex

The entire workflow is automated from request to availability in Plex.

