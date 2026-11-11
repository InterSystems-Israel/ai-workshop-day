#!/usr/bin/env python3
"""A tool the agent can call that is NOT written in ObjectScript.

Exercise B.2.2. AI Hub launches this file as a child process and speaks MCP to
it over stdin/stdout, so the agent gets these tools alongside the ObjectScript
ones in Workshop.Tools.OnCall and cannot tell the difference.

The scenario: runbooks live outside IRIS. A real site would have them in a
wiki, a git repository or a knowledge base; here they are a dict, because the
exercise is about the transport and not about runbooks.

Run by the <MCP><Stdio> element in Workshop.Tools.OnCall's XData Definition:

    <MCP Name="OnCallPy">
      <Stdio Executable="/usr/irissys/bin/irispython"
             Args="/home/irisowner/dev/Python/oncall_mcp.py"/>
    </MCP>

MUST be run with irispython, not python3. fastmcp is installed in
/usr/irissys/mgr/python, which is on IRIS's embedded-Python path and not on
the system interpreter's.

NOTHING MAY BE WRITTEN TO STDOUT except MCP protocol frames. stdout *is* the
transport: a stray print() corrupts the stream and the tool silently
disappears from the agent's list. Diagnostics go to stderr.
"""

import sys

from fastmcp import FastMCP

mcp = FastMCP("oncall-runbooks")

# Keyed by the substring we look for in an IRIS error string. Ordered: the
# first match wins, so put the specific patterns first.
RUNBOOKS = {
    "connection refused": {
        "runbook": "RB-014  Downstream endpoint refusing connections",
        "checks": [
            "Confirm the target operation is running: Ens.Director.GetHostSettings",
            "Check the target host's IP and port settings in the production",
            "Verify the remote listener is up from the IRIS host, not your laptop",
        ],
        "escalate_after": "15 minutes",
    },
    "timed out": {
        "runbook": "RB-021  TCP connect timeout to a downstream system",
        "checks": [
            "Compare the configured timeout against the downstream SLA",
            "Look for a firewall change in the last 24 hours",
            "Check whether the queue has grown while retries accumulate",
        ],
        "escalate_after": "30 minutes",
    },
    "segment terminator": {
        "runbook": "RB-007  Malformed inbound document",
        "checks": [
            "Pull the raw message from the Message Viewer",
            "Identify the sending system from the message header",
            "Do not re-send until the sender has been corrected",
        ],
        "escalate_after": "none; route to the integration owner",
    },
    "queue depth": {
        "runbook": "RB-033  Queue depth alert",
        "checks": [
            "Identify whether the consumer is stopped or merely slow",
            "Check pool size on the consuming host",
            "Confirm no poison message is blocking the head of the queue",
        ],
        "escalate_after": "immediately if depth is still rising",
    },
}


@mcp.tool
def lookup_runbook(error_text: str) -> dict:
    """Find the on-call runbook for an interoperability error.

    Pass the error text exactly as it appears in the IRIS event log. Returns
    the runbook reference, the checks to perform in order, and when to
    escalate. Use this before proposing a remediation, so the proposal matches
    site procedure.
    """
    haystack = (error_text or "").lower()
    for needle, entry in RUNBOOKS.items():
        if needle in haystack:
            return {"matched_on": needle, "source": "oncall-runbooks (python)", **entry}
    return {
        "matched_on": None,
        "source": "oncall-runbooks (python)",
        "runbook": None,
        "note": "No runbook matches this error. Say so rather than inventing a procedure.",
        "known_patterns": sorted(RUNBOOKS),
    }


@mcp.tool
def list_runbooks() -> dict:
    """List every runbook this service knows about, with the error pattern each one covers."""
    return {
        "source": "oncall-runbooks (python)",
        "count": len(RUNBOOKS),
        "runbooks": [
            {"pattern": pattern, "runbook": entry["runbook"]}
            for pattern, entry in sorted(RUNBOOKS.items())
        ],
    }


if __name__ == "__main__":
    print("oncall-runbooks starting on stdio", file=sys.stderr)
    mcp.run()
