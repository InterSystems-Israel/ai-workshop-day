Include (%AI, %occStatus)

/// Persists every governed tool call to Workshop.Data.AuditEntry.
Class Workshop.Policy.AuditLog Extends %AI.Policy.Audit
{

// ===========================================================================
// EXERCISE D2 — implement %LogExecution
//
// %LogDenial below is complete and serves as a worked example. The task is
// the TODO block in %LogExecution.
//
// Method signatures on this build:
//   %LogExecution(call, metadata, result, duration, status)
//   %LogDenial(call, metadata, status)
//
// `duration` is already expressed in milliseconds.
//
// Scope: a tool invoked through ToolSet.%Invoke() does not reach the policy
// layer, so no audit row is produced for it. Module D step 6 demonstrates
// this.
//
// Do not use %AI.Policy.ConsoleAudit for a ToolSet exposed over MCP. It
// writes to the current device, which during an HTTP request is the response
// body, causing every tools/call to fail with a JSON deserialization error.
// Persisting to a table, as here, is safe on all transports.
// ===========================================================================

/// Shorten a value for storage. An audit row is evidence, not a data copy.
ClassMethod Clip(value As %String, max As %Integer = 2000) As %String
{
    Set text = $Select($IsObject(value): value.%ToJSON(), 1: value)
    If $Length(text) <= max Return text
    Return $Extract(text, 1, max - 3) _ "..."
}

/// Pull the tool name out of the call object, whatever shape it arrives in.
ClassMethod ToolNameOf(call As %DynamicObject) As %String
{
    If '$IsObject(call) Return "(unknown)"
    If call.%IsDefined("name") Return call.name
    If call.%IsDefined("tool") Return call.tool
    If call.%IsDefined("toolname") Return call.toolname
    Return "(unknown)"
}

Method %LogExecution(
    call As %DynamicObject,
    metadata As %DynamicObject,
    result As %DynamicObject,
    duration As %Integer,
    status As %Status) As %Status
{
    // TODO (Exercise D.2.1): create one Workshop.Data.AuditEntry row per call.
    //
    // 1. Instantiate Workshop.Data.AuditEntry.
    // 2. Set ToolName from ..ToolNameOf(call).
    // 3. Set Arguments and Result using ..Clip() to limit their length.
    // 4. Set Outcome to "EXECUTED" and DurationMs to `duration`.
    // 5. Set StatusText from `status` if it reports an error.
    // 6. Save the row. Follow the structure of %LogDenial below.
    //
    // EXPECTED RESULT: after a conversation in which the agent uses tools,
    //   SELECT * FROM Workshop_Data.AuditEntry
    // returns one row per tool call, each with a duration.

    Return $$$OK
}

/// COMPLETE — the worked example. A refusal is an audit event too; without
/// this you cannot tell "the agent never tried" from "the agent was stopped".
Method %LogDenial(
    call As %DynamicObject,
    metadata As %DynamicObject,
    status As %Status) As %Status
{
    Try {
        Set row = ##class(Workshop.Data.AuditEntry).%New()
        Set row.ToolName = ..ToolNameOf(call)
        Set row.Arguments = ..Clip(call, 4000)
        Set row.Outcome = "DENIED"
        Set row.Result = ""
        Set row.DurationMs = 0
        Set row.StatusText = ..Clip($System.Status.GetErrorText(status), 1000)
        Do row.%Save()
    } Catch ex {
        // Never let auditing break the call it is auditing. Swallow and move
        // on - but say so, so a silent failure is not invisible.
        Write "AUDIT WARNING: ", ex.DisplayString(), !
    }
    Return $$$OK
}

}
