import os
from pathlib import Path
from mitmproxy import http, tls, ctx

ALLOWED_HOSTS_PATH = Path(os.environ["PEN_PROJECT"]) / ".pen" / "http-allowlist.txt"

def load_allowed_hosts(path: Path) -> set[tuple[str, int]]:
    allowed = set()
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        host, port = line.rsplit(":", 1)
        allowed.add((host, int(port)))
    return allowed

ALLOWED = load_allowed_hosts(ALLOWED_HOSTS_PATH)
ctx.log.info(f"Loaded {len(ALLOWED)} allowed hosts from {ALLOWED_HOSTS_PATH}")

def is_allowed(flow: http.HTTPFlow) -> bool:
    return (flow.request.pretty_host, flow.request.port) in ALLOWED

class EgressFilter:
    def tls_clienthello(self, data: tls.ClientHelloData):
        # Let TLS connections pass through without termination to avoid requiring a self-signed certificate.
        # We will still block requests in http_connect if they are not allowed.
        data.ignore_connection = True

    def http_connect(self, flow: http.HTTPFlow):
        if not is_allowed(flow):
            flow.response = http.Response.make(403, b"Blocked by egress filter")
            ctx.log.warn(f"BLOCKED CONNECT: {flow.request.pretty_host}:{flow.request.port}")

    def request(self, flow: http.HTTPFlow):
        if not is_allowed(flow):
            flow.response = http.Response.make(403, b"Blocked by egress filter")
            ctx.log.warn(f"BLOCKED: {flow.request.pretty_host}:{flow.request.port}")

addons = [EgressFilter()]
