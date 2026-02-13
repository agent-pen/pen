import asyncio
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

class EgressFilter:
    def __init__(self):
        self._allowed = set()
        self._mtime = None
        self._watch_task = None

    def _load(self):
        try:
            mtime = ALLOWED_HOSTS_PATH.stat().st_mtime
            if mtime == self._mtime:
                return
            self._allowed = load_allowed_hosts(ALLOWED_HOSTS_PATH)
            self._mtime = mtime
            ctx.log.info(f"Loaded {len(self._allowed)} allowed hosts from {ALLOWED_HOSTS_PATH}")
        except FileNotFoundError:
            if self._mtime is not None:
                self._allowed = set()
                self._mtime = None
                ctx.log.warn(f"Allowlist not found: {ALLOWED_HOSTS_PATH}")

    def running(self):
        self._watch_task = asyncio.ensure_future(self._watch())

    def done(self):
        if self._watch_task:
            self._watch_task.cancel()

    async def _watch(self):
        while True:
            self._load()
            await asyncio.sleep(1)

    def _block_if_denied(self, flow: http.HTTPFlow, label: str):
        if (flow.request.pretty_host, flow.request.port) not in self._allowed:
            flow.response = http.Response.make(403, b"Blocked by egress filter")
            ctx.log.warn(f"BLOCKED {label}: {flow.request.pretty_host}:{flow.request.port}")

    def tls_clienthello(self, data: tls.ClientHelloData):
        # Let TLS connections pass through without termination to avoid requiring a self-signed certificate.
        # We will still block requests in http_connect if they are not allowed.
        data.ignore_connection = True

    def http_connect(self, flow: http.HTTPFlow):
        self._block_if_denied(flow, "CONNECT")

    def request(self, flow: http.HTTPFlow):
        self._block_if_denied(flow, "REQUEST")

addons = [EgressFilter()]
