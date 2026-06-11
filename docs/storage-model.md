# Storage Model

Production OS and service data live on SSD.

The eMMC is reserved for Rescue OS.

Recommended mount points:

```text
/opt/lisa-edge   Git repo
/srv/lisa-edge   Docker volumes, logs, backups cache
```

Avoid heavy writes to eMMC.
