# Streamio Server Deployment Guide

## 1. Kernel Network Optimization

Create `/etc/sysctl.d/99-stremio-network.conf`:
```ini
net.core.default_qdisc = fq

# Extended receive and transmit buffers (prevent torrent packet drops)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Backlog queues for high connection spikes
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 4096

vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
```

Apply parameters:
```bash
sudo sysctl --system
```

---

## 2. Docker Daemon Configuration

Create or update `/etc/docker/daemon.json`:
```json
{
  "data-root": "/mnt/dietpi_userdata/docker-data",
  "log-driver": "journald",
  "log-level": "warn",
  "debug": false,
  "dns": [
    "1.1.1.1"
  ]
}
```

Restart Docker service:
```bash
sudo systemctl restart docker
```

---

## 3. Directory Setup & Pre-configuration

Create directories:
```bash
sudo mkdir -p /opt/stremio/data
```

Create `/opt/stremio/data/server-settings.json`:
```json
{
    "serverVersion": "4.22.4",
    "appPath": "/root/.stremio-server",
    "cacheRoot": "/root/.stremio-server",
    "cacheRootVersion": 0,
    "cacheRootsToClean": [],
    "cacheSize": 10737418240,
    "btMaxConnections": 35,
    "btHandshakeTimeout": 20000,
    "btRequestTimeout": 4000,
    "btDownloadSpeedSoftLimit": 0,
    "btDownloadSpeedHardLimit": 0,
    "btMinPeersForStable": 5,
    "remoteHttps": "",
    "localAddonEnabled": false,
    "transcodeHorsepower": 0.75,
    "transcodeMaxBitRate": 0,
    "transcodeConcurrency": 0,
    "transcodeTrackConcurrency": 1,
    "transcodeHardwareAccel": false,
    "transcodeProfile": null,
    "allTranscodeProfiles": [],
    "transcodeMaxWidth": 1920,
    "proxyStreamsEnabled": false
}
```

---

## 4. Docker Compose Deployment

Create `/opt/stremio/docker-compose.yml`:
```yaml
services:
  streamio:
    image: stremio/server:latest
    container_name: streamio
    restart: unless-stopped
    ports:
      - "11470:11470"
      - "12470:12470"
    environment:
      - NO_CORS=1
      - CACHE_SIZE=10737418240
    volumes:
      - /opt/stremio/data:/root/.stremio-server
```

Start container:
```bash
cd /opt/stremio
sudo docker compose up -d
```

---

## 5. Maintenance & Updates

Check running container logs:
```bash
sudo docker logs -f streamio
```

Check and pull image updates:
```bash
cd /opt/stremio
sudo docker compose pull
```

Recreate container if updated:
```bash
cd /opt/stremio
sudo docker compose up -d --remove-orphans
```

Clean obsolete images:
```bash
sudo docker image prune -f
```

---

## 6. Endpoints & Access
* **HTTP Endpoint:** `http://<HOST_IP>:11470`
* **HTTPS/Alternative Endpoint:** `http://<HOST_IP>:12470`
* **Status Verification:** `curl -s http://localhost:11470/stats.json`