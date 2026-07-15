#!/usr/bin/env bash

configure_node_red() {
  echo
  echo "--- Node-RED wizard ---"
  ask_value NODE_RED_BIND_ADDR "Node-RED bind IP" "${NODE_RED_BIND_ADDR:-127.0.0.1}"
  ask_value NODE_RED_PORT "Node-RED port" "${NODE_RED_PORT:-1880}"
  require_port "NODE_RED_PORT" "$NODE_RED_PORT"
}
