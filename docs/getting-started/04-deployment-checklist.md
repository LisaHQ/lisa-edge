# Deployment Checklist

This checklist helps ensure a successful and repeatable LISA Edge deployment.

---

# Host Preparation

## Operating System

* [ ] Ubuntu Server LTS installed
* [ ] Debian installed
* [ ] System fully updated
* [ ] Hostname configured
* [ ] Timezone configured

Verify:

```bash
hostnamectl
timedatectl
```

---

## SSH Access

* [ ] SSH server installed
* [ ] SSH key authentication working
* [ ] Password authentication disabled (recommended)

Verify:

```bash
ssh user@host
```

---

# Storage

## Data Storage

* [ ] DATA_ROOT selected
* [ ] Persistent storage available
* [ ] Sufficient free space

Recommended:

```text
/srv/lisa-edge
```

Avoid:

```text
/root
/tmp
```

---

## Backup Storage

* [ ] Backup location configured
* [ ] External SSD or NAS available
* [ ] Backup retention strategy defined

Examples:

```text
NAS
External SSD
Encrypted USB Drive
```

---

# Networking

## Host Networking

* [ ] Static IP assigned
* [ ] DNS working
* [ ] Internet access verified

Verify:

```bash
ping 1.1.1.1
ping google.com
```

---

## VLAN Planning

Recommended:

* Management VLAN
* Services VLAN
* IoT VLAN
* Camera VLAN
* Guest VLAN

Review firewall rules before deployment.

---

# Docker

* [ ] Docker installed
* [ ] Docker Compose available

Verify:

```bash
docker version
docker compose version
```

---

# Service Selection

Choose only the services required.

## MQTT

Required if:

* Home Assistant
* Homey
* Custom automation
* LISA event bus

---

## OTBR

Required if:

* Matter over Thread devices exist

Additional requirements:

* Thread RCP radio
* Dataset backup configured

---

## NUT

Required if:

* UPS is present

---

## Tailscale

Required if:

* Remote access is desired

---

## Uptime Kuma

Required if:

* Service monitoring is desired

---

# Security Review

* [ ] SSH keys configured
* [ ] Default passwords removed
* [ ] Secrets reviewed
* [ ] Firewall reviewed
* [ ] VPN configured if required

---

# Backup Review

* [ ] Backup destination configured
* [ ] Restore procedure documented
* [ ] Test restore performed

---

# Deployment

Clone repository:

```bash
git clone https://github.com/lisahq/lisa-edge.git
cd lisa-edge
```

Configure:

```bash
cp .env.example .env
```

Deploy:

```bash
./scripts/deploy.sh
```

---

# Post Deployment Validation

* [ ] Containers healthy
* [ ] Logs reviewed
* [ ] Services reachable
* [ ] Backups functioning
* [ ] Monitoring operational

Deployment complete.
