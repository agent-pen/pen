#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

source "${PEN_HOME}/penctl/commands/lib/common.sh"

# --- Already running? ---

if pen_is_running; then
  echo "Pen already running."
  exit 0
fi

# --- Clean up from previous run ---

pen_teardown

# --- 1. Create network ---

max_subnet=$(container network ls | grep 192.168. | sed -r 's/.+192\.168\.([0-9]+).0\/24/\1/' | sort -r | head -1)
subnet="192.168.$((max_subnet + 1)).0/24"
echo "Creating network..."
container network create --subnet "${subnet}" "$network" > /dev/null

# --- 2. Start container ---

echo "Starting container..."
gateway="${subnet%.0/24}.1"
proxy_host="${gateway}"   # proxy binds to the gateway IP
dns_host="${gateway}"     # Apple containerization runs DNS on the gateway IP
container run \
  --network "$network" \
  --detach \
  --remove \
  --name "$target" \
  --cpus 4 \
  --memory 4G \
  --env "HTTP_PROXY=http://${proxy_host}:${proxy_port}" \
  --env "HTTPS_PROXY=http://${proxy_host}:${proxy_port}" \
  --env "http_proxy=http://${proxy_host}:${proxy_port}" \
  --env "https_proxy=http://${proxy_host}:${proxy_port}" \
  --volume "${PEN_PROJECT}:${PEN_PROJECT}" \
  "${container_name}" > /dev/null

# --- 3. Inspect container for pf rules ---

container_ip=$(container inspect "$target" | jq -r '.[0].networks[0].ipv4Address | split("/")[0]')
bridge_iface=$(route -n get "$container_ip" | awk '/interface:/ {print $2}')


# --- 4. Apply pf rules ---

pf_rules="pass in quick on ${bridge_iface} from ${container_ip} to ${subnet}
pass in quick on ${bridge_iface} proto { tcp udp } from ${container_ip} to ${dns_host} port 53
pass in quick on ${bridge_iface} proto tcp from ${container_ip} to ${proxy_host} port ${proxy_port}"

allowed_ips_file="${sandbox_config_dir}/network-allowlist.txt"
if [[ -f "$allowed_ips_file" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line// /}"
    [[ -z "$line" ]] && continue
    ip="${line%%:*}"
    port="${line##*:}"
    pf_rules="${pf_rules}
pass in quick on ${bridge_iface} proto { tcp udp } from ${container_ip} to ${ip} port ${port}"
  done < "$allowed_ips_file"
fi

pf_rules="${pf_rules}
block in quick on ${bridge_iface} from ${subnet} to any"

echo "$pf_rules" | sudo "$pfctl_wrapper" load "$pf_anchor"

# --- 5. Start proxy in background ---


export PEN_ALLOWLIST_PATH="${sandbox_config_dir}/http-allowlist.txt"
script -qF "$proxy_log_file" \
  mitmdump --mode regular --listen-host "${proxy_host}" --listen-port "${proxy_port}" \
  --set connection_strategy=lazy \
  -s "${PEN_HOME}/penctl/commands/lib/egress-proxy.py" \
  > /dev/null 2>&1 &
echo $! > "$proxy_pid_file"

for i in $(seq 1 30); do
  if nc -z "$proxy_host" "$proxy_port" 2>/dev/null; then
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "Proxy failed to start. Check ${proxy_log_file}"
    exit 1
  fi
  sleep 0.2
done

# --- 6. Configure SSH ---

container exec "$target" bash -c "
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  echo 'Host *
    ProxyCommand nc -X connect -x ${proxy_host}:${proxy_port} %h %p' > ~/.ssh/config
  chmod 600 ~/.ssh/config
"

# --- 7. Drop into shell ---

container exec -it --workdir "$PEN_PROJECT" "$target" bash
