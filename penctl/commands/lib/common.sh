# Sourced by pen subcommands. PEN_HOME and PEN_PROJECT must be set by the pen dispatcher.

path_hash=$(printf '%s' "$PEN_PROJECT" | shasum | cut -c1-6)
container_name="pen-$(basename "$PEN_PROJECT")-${path_hash}"
target="${container_name}-container"
network="${container_name}-network"
proxy_port=8080
proxy_pid_file="${PEN_PROJECT}/.pen/proxy.pid"
proxy_log_file="${PEN_PROJECT}/.pen/proxy.log"
pfctl_wrapper="${PEN_HOME}/penctl/commands/lib/pfctl-wrapper.sh"
pf_anchor="com.apple/${container_name}"
sandbox_config_dir="${HOME}/.pen/sandboxes/${container_name}"

pen_is_running() {
  container inspect "$target" 2>/dev/null | jq -e '.[0].status == "running"' >/dev/null 2>&1
}

pen_teardown() {
  container delete --force "$target" > /dev/null 2>&1 || true
  if [[ -f "$proxy_pid_file" ]]; then
    kill "$(cat "$proxy_pid_file")" 2>/dev/null || true
    rm -f "$proxy_pid_file"
  fi
  sudo "$pfctl_wrapper" flush "$pf_anchor"
  if container network list | grep -q "$network"; then
    container network delete "$network" > /dev/null
  fi
}
