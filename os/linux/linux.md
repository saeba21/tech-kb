## Task Manager
### RAM
```bash
ps -eo pid,%mem,rss,cmd --sort=-rss | head -n 10 | awk 'NR==1 {print $0, "MB"} NR>1 {$3 = sprintf("%.1f MB", $3/1024); print}'
```

### Remote Access
**fix problem session rdp**
```bash
loginctl terminate-user USER 
```