# qBittorrent + VueTorrent + Samba Setup

## 1. Storage & Config Directories
```bash
sudo mkdir -p /nas-pi/downloads /nas-pi/torrents /opt/qbittorrent/config
```
* `/nas-pi/downloads`: Incomplete/temporary downloads.
* `/nas-pi/torrents`: Completed torrent storage.
* `/opt/qbittorrent/config`: qBittorrent persistent configuration files.

---

## 2. Dedicated User & Permissions
```bash
export SAMBA_USER="USER"

sudo adduser --no-create-home --shell /usr/sbin/nologin "$SAMBA_USER"
sudo chown -R "$SAMBA_USER":"$SAMBA_USER" /nas-pi
sudo chmod -R 775 /nas-pi
```

Check User ID and Group ID:
```bash
id "$SAMBA_USER"
```

---

## 3. Samba (SMB) Configuration

### 3.1 Samba User Password
```bash
sudo smbpasswd -a SAMBA_USER
sudo smbpasswd -e SAMBA_USER
```

### 3.2 /etc/samba/smb.conf
Append to `/etc/samba/smb.conf`:
```ini
[nas-pi]
        comment = DietPi NAS Storage
        path = /nas-pi
        browseable = yes
        create mask = 0664
        directory mask = 0775
        valid users = SAMBA_USER
        writeable = yes
        max connections = 8
```

Restart service:
```bash
sudo systemctl restart smbd
```

---

## 4. qBittorrent + VueTorrent Deployment

### 4.1 /opt/qbittorrent/docker-compose.yml
```yaml
services:
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    environment:
      - PUID=1001          # Match UID from 'id SAMBA_USER'
      - PGID=1001          # Match GID from 'id SAMBA_USER'
      - TZ=Europe/Rome
      - WEBUI_PORT=8080
      - TORRENTING_PORT=6881
      - DOCKER_MODS=ghcr.io/vuetorrent/vuetorrent-lsio-mod:latest
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    volumes:
      - /opt/qbittorrent/config:/config
      - /nas-pi:/nas-pi
```

### 4.2 Start Service
```bash
cd /opt/qbittorrent
sudo docker compose up -d
```

---

## 5. Post-Deployment & Access

### 5.1 Initial WebUI Credentials
Retrieve generated temporary password:
```bash
sudo docker logs qbittorrent 2>&1 | grep "temporary password"
```

### 5.2 Endpoints
* **WebUI (qBittorrent + VueTorrent):** http://<HOST_IP>:8080 (User: admin)
* **SMB (Windows):** \\<HOST_IP>\nas-pi
* **SMB (Linux/macOS/Kodi):** smb://<HOST_IP>/nas-pi