# qBittorrent \+ VueTorrent \+ Samba Setup

## 1\. Storage & Config Directories

```sh
sudo mkdir -p /nas-pi/downloads /nas-pi/torrents /opt/qbittorrent/config
```

* `/nas-pi/downloads`: Incomplete/temporary downloads.  
* `/nas-pi/torrents`: Completed torrent storage.  
* `/opt/qbittorrent/config`: qBittorrent persistent configuration files.

---

## 2\. Dedicated User & Permissions

```sh
export SAMBA_USER="USER"

sudo adduser --no-create-home --shell /usr/sbin/nologin "$SAMBA_USER"
sudo chown -R "$SAMBA_USER":"$SAMBA_USER" /nas-pi
sudo chmod -R 775 /nas-pi
```

Check User ID and Group ID:

```sh
id "$SAMBA_USER"
```

---

## 3\. Samba (SMB) Configuration

### 3.1 Samba User Password

```sh
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

&nbsp;

Restart service:

```sh
sudo systemctl restart smbd
```

---

## 4\. qBittorrent \+ VueTorrent Deployment

### 4.1 /opt/qbittorrent/docker-compose.yml

```yaml
services:
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    stop_grace_period: 30s
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

&nbsp;

### 4.2 Start Service

```sh
cd /opt/qbittorrent
sudo docker compose up -d
```

---

## 5\. Post-Deployment & Access

### 5.1 Initial WebUI Credentials

Retrieve generated temporary password:

```sh
sudo docker logs qbittorrent 2>&1 | grep "temporary password"
```

### 5.2 Endpoints

* **WebUI (qBittorrent \+ VueTorrent):** http\://\<HOST\_IP\>:8080 (User: admin)  
* **SMB (Windows):** \\\<HOST\_IP\>\\nas-pi  
* **SMB (Linux/macOS/Kodi):** smb://\<HOST\_IP\>/nas-pi

### 5.3 Update

create script in opt: update-qbittorrent.sh

```sh
#!/bin/bash

# 0 4 * * * /opt/qbittorrent/update-qbittorrent.sh > /dev/null 2>&1
LOG_FILE="/opt/qbittorrent/qbittorrent-update.log"
DATA=$(date '+%Y-%m-%d %H:%M:%S')

cd /opt/qbittorrent || { echo "[$DATA] ERRORE: Cartella /opt/qbittorrent non trovata" >> "$LOG_FILE"; exit 1; }

# Controlla aggiornamenti, ricrea se necessario, forza il riavvio per pulizia RAM e rimuove vecchie immagini
if /usr/bin/docker compose pull -q && /usr/bin/docker compose up -d && /usr/bin/docker compose restart && /usr/bin/docker image prune -f > /dev/null 2>&1; then
    echo "[$DATA] OK - Controllo/aggiornamento e riavvio completati" >> "$LOG_FILE"
else
    echo "[$DATA] ERRORE - Problema durante l'aggiornamento o il riavvio" >> "$LOG_FILE"
fi
```

after create a crontab for every night at 4 am

```sh
0 4 * * * /opt/qbittorrent/update-qbittorrent.sh > /dev/null 2>&1
```