# USB Autoinstall Flow

The USB installer should install Ubuntu Server to the SSD, not the eMMC.

Late command pattern:

```yaml
late-commands:
  - curtin in-target --target=/target -- apt-get update
  - curtin in-target --target=/target -- apt-get install -y git curl ca-certificates
  - curtin in-target --target=/target -- git clone https://github.com/YOUR_ORG/lisa-edge.git /opt/lisa-edge
  - curtin in-target --target=/target -- bash /opt/lisa-edge/bootstrap/bootstrap.sh
```

Disk matching should be explicit. Prefer matching the Samsung SSD by model or serial instead of using `/dev/sda` blindly.
