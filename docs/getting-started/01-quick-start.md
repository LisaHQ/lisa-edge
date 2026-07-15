# Quick Start

## 1. Install Linux

Use Ubuntu Server or Debian.

## 2. Clone Repository

```bash
sudo git clone https://github.com/LisaHQ/lisa-edge.git /opt/lisa-edge
cd /opt/lisa-edge
```

## 3. Run the Configuration Wizard

```bash
sudo ./provisioning/lisa-first-boot.sh --mode config-only
```

At minimum, review:

- `DATA_ROOT`
- `BACKUP_DEST`
- bind addresses
- passwords
- selected service list and each selected service's wizard

## 4. Bootstrap Host

```bash
sudo ./bootstrap/bootstrap.sh
```

## 5. Verify

```bash
sudo ./scripts/healthcheck.sh
```

## 6. Add or Remove Services

Run the wizard again and select one, multiple, or all services:

```bash
sudo ./provisioning/lisa-first-boot.sh
```
