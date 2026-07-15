# Service Catalog

LISA Edge is a collection of lightweight infrastructure services.

No single service should dominate the project. OTBR is important for Matter-over-Thread, but it is only one part of the stack.

The purpose of this catalog is to clarify which services belong on LISA Edge and which services should usually run elsewhere.

---

## LISA Edge Services

These services are good fits for LISA Edge.

### Infrastructure Services
| Service         | Default  | Role                                   |
|-----------------|:--------:|----------------------------------------|
| DNS helpers     | Optional | Local resolution and service discovery |
| NTP / Chrony    |   Yes    | Local time synchronization             |
| MQTT            |   Yes    | Local event and messaging backbone     |
| VPN / Tailscale | Optional | Secure remote administration           |
| Reverse proxy   | Optional | Internal HTTPS and service routing     |
| NUT             | Optional | UPS monitoring and graceful shutdown   |
| Uptime Kuma     |   Yes    | Lightweight health monitoring          |
| Backup timer    |   Yes    | Host-level backup workflow             |

### Connectivity Services
| Service        | Default  | Role                                     |
|----------------|:--------:|------------------------------------------|
| OTBR           | Optional | Thread Border Router                     |
| Zigbee2MQTT    | Optional | Zigbee-to-MQTT bridge                    |
| Matter bridges | Optional | Connects non-Matter ecosystems to Matter |
| mDNS           | Optional | Local multicast service discovery        |

---

## Conditional Edge Services

These may run on LISA Edge in small deployments but should be evaluated carefully.

| Service          | When Acceptable                      | Notes                               |
|------------------|--------------------------------------|-------------------------------------|
| Small PostgreSQL | Small metadata/config workloads only | Avoid large or high-write databases |
| Small MariaDB    | Small local service dependency only  | Avoid heavy writes to eMMC          |
| Lightweight APIs | Infrastructure support only          | Keep resource usage low             |
| Small dashboards | Operational dashboards only          | Avoid large observability stacks    |

---

## Smart Home / Automation Services

These services may be related to the LISA ecosystem, but they are not core LISA Edge infrastructure.

They should usually run on LISA Brain, a home automation host, or a separate automation layer.

| Service        | Preferred Placement                     | Reason                                           |
|----------------|-----------------------------------------|--------------------------------------------------|
| Homey          | Dedicated controller / automation layer | Device orchestration, not edge infrastructure    |
| Home Assistant | LISA Brain / automation host            | Automation logic and integrations can grow heavy |
| Node-RED       | LISA Brain / automation host            | Workflow logic belongs above Edge                |

---

## External / Dedicated Services

These should generally not run on LISA Edge.

| Service                 | Preferred Placement       |
|-------------------------|---------------------------|
| LLM inference           | LISA Brain / AI compute   |
| ASR / TTS               | LISA Brain / AI compute   |
| Frigate                 | Vision server             |
| Object detection        | Vision server             |
| NAS workloads           | NAS                       |
| Media storage           | NAS                       |
| Large databases         | Database server           |
| Heavy monitoring stacks | Dedicated monitoring host |

---

## Service Placement Rule

Run lightweight infrastructure services on LISA Edge.

Move heavy compute, large databases, video analytics, long-term storage, and complex automation logic to dedicated systems.

Every service should answer:

- Does this improve local availability?
- Does this improve reliability?
- Does this improve security?
- Is the complexity justified?
- Can it be backed up and restored cleanly?
