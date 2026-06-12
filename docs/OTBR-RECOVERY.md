# OTBR Disaster Recovery

## Goal

Recover a failed OTBR deployment without re-pairing Thread devices.

---

## Symptoms

Examples:

* SSD failure
* OS corruption
* Hardware replacement
* Accidental container deletion

---

## Required Backup

At minimum:

```text
latest.dataset.hex
```

This file contains the Thread Active Operational Dataset.

---

## Recovery Procedure

### Step 1

Install Linux.

### Step 2

Clone LISA Edge.

```bash
git clone https://github.com/huysrc/lisa-edge.git
```

### Step 3

Restore dataset backup.

```bash
latest.dataset.hex
```

into:

```text
/srv/lisa-edge/backups/otbr/
```

### Step 4

Deploy OTBR.

```bash
./scripts/deploy.sh
```

### Step 5

Verify network state.

```bash
docker exec lisa-otbr ot-ctl state
```

Expected:

```text
leader
```

or

```text
router
```

---

## Verification

Verify:

* Thread devices reconnect
* Matter devices respond
* Existing automations continue working

No re-pairing should be required.

---

## If No Backup Exists

Recovery becomes significantly harder.

A new Thread network must be created.

Consequences:

* devices may require factory reset
* Matter devices may require re-pairing
* network credentials are lost

For this reason, dataset backups are considered critical infrastructure.
