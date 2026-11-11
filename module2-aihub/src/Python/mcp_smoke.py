#!/usr/bin/env python3
"""Smoke-test the IRIS MCP bridge over HTTP from the host.

    python mcp_smoke.py                      # list tools
    python mcp_smoke.py RecentErrors         # list, then call one

Deliberately uses only the standard library, so students need no pip install
on conference wifi. Speaks MCP "streamable HTTP": a JSON-RPC POST to /mcp
whose response may come back as either application/json or an SSE stream.

Note the URL path is /mcp, NOT /mcp/oncall. The endpoint path configured in
config_http.toml identifies the IRIS application; it does not appear in the
HTTP URL. It does, however, prefix every tool NAME.
"""

import json
import sys
import urllib.error
import urllib.request

URL = "http://localhost:48080/mcp"
PROTOCOL_VERSION = "2025-06-18"

_session_id = None


def rpc(method, params=None, notify=False):
    """One JSON-RPC call. Returns the parsed result, or None for a notification."""
    global _session_id

    body = {"jsonrpc": "2.0", "method": method}
    if params is not None:
        body["params"] = params
    if not notify:
        body["id"] = 1

    req = urllib.request.Request(
        URL,
        data=json.dumps(body).encode(),
        method="POST",
        headers={
            "Content-Type": "application/json",
            # Both must be offered: the server picks per response.
            "Accept": "application/json, text/event-stream",
            **({"Mcp-Session-Id": _session_id} if _session_id else {}),
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            # The session id arrives on the initialize response and must be
            # echoed on every later request.
            if not _session_id:
                _session_id = r.headers.get("Mcp-Session-Id")
            raw = r.read().decode()
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code} on {method}: {e.read().decode()[:400]}")
        raise

    if notify or not raw.strip():
        return None

    # This server always answers with text/event-stream, and the FIRST
    # "data:" line is EMPTY (a stream-open event) followed by "id:"/"retry:".
    # Taking the first data line therefore yields "" and a JSON error - the
    # payload is in a later one. Scan for the first line that actually parses.
    msg = None
    if "data:" in raw:
        for line in raw.splitlines():
            if not line.startswith("data:"):
                continue
            payload = line[5:].strip()
            if not payload:
                continue
            try:
                msg = json.loads(payload)
                break
            except json.JSONDecodeError:
                continue
    if msg is None:
        msg = json.loads(raw)
    if "error" in msg:
        raise RuntimeError(f"{method} -> {msg['error']}")
    return msg.get("result")


def main():
    info = rpc(
        "initialize",
        {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {},
            "clientInfo": {"name": "workshop-smoke", "version": "1.0"},
        },
    )
    srv = info.get("serverInfo", {})
    print(f"connected: {srv.get('name')} {srv.get('version')}"
          f"  protocol={info.get('protocolVersion')}  session={_session_id}")

    rpc("notifications/initialized", {}, notify=True)

    tools = rpc("tools/list").get("tools", [])
    print(f"\ntools/list -> {len(tools)} tools")
    for t in tools:
        required = t.get("inputSchema", {}).get("required", [])
        print(f"  {t['name']}")
        print(f"      {(t.get('description') or '').splitlines()[0][:90]}")
        if required:
            print(f"      required: {required}")

    if len(sys.argv) < 2:
        print("\n(pass a tool name to call one)")
        return

    want = sys.argv[1]
    args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}

    match = next((t["name"] for t in tools if want in t["name"]), None)
    if not match:
        print(f"\nno tool matching {want!r}")
        return

    print(f"\ntools/call -> {match}  args={args}")
    out = rpc("tools/call", {"name": match, "arguments": args})
    print(f"  isError: {out.get('isError')}")
    for item in out.get("content", []):
        text = item.get("text", "")
        print(f"  {text[:600]}")


if __name__ == "__main__":
    main()
