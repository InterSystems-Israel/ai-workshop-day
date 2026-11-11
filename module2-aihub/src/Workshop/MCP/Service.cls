Include (%AI, %occStatus)

/// Publishes the On-Call Desk tools outward as an MCP server.
Class Workshop.MCP.Service Extends %AI.MCP.Service
{

// Three lines of real content - the dispatch class is deliberately trivial.
// The work is in the ToolSet named by SPECIFICATION and in the MCP Server
// application registered by Workshop.MCP.Setup.
//
// NEVER add %AI.Policy.ConsoleAudit or %AI.Policy.ConsoleAuth to a ToolSet
// exposed this way. They write to the current device, which during an HTTP
// request IS the response body, so every tools/call fails with
//   JSON serialization/deserialization error: expected value at line 2 column 1
// Workshop.Tools.OnCall uses neither.

Parameter SPECIFICATION As STRING = "Workshop.Tools.OnCall";

}
