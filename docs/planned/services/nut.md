# NUT / UPS (Planned)

Status: design only; LISA Edge does not currently deploy Network UPS Tools.

The likely model is one NUT server attached to the UPS over USB, with LISA Edge,
LISA Brain, NAS and other infrastructure nodes acting as clients where needed.
LISA Edge may eventually be either the server or a client, depending on which
host owns the USB connection.

Do not add `nut` to `LISA_COMPOSE_SERVICES`; it is not a registered selection
key. Implementation should wait until the supported UPS topology, shutdown
policy and recovery behavior are defined.
