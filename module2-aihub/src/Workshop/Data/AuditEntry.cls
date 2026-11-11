Include (%occStatus)

/// One row per tool call. The audit trail Module D builds.
///
/// This is the "cost" evidence layer: tokens and latency per call, alongside
/// Ens.MessageHeader (message layer) and the persisted %AI.Agent.Session
/// (reasoning layer).
Class Workshop.Data.AuditEntry Extends %Persistent
{

// SCOPE: a tool invoked directly with ToolSet.%Invoke() does not reach the
// policy layer and therefore produces no row in this table. The audit trail
// covers the governed execution paths only. Module D step 6 demonstrates this.

Property ToolName As %String(MAXLEN = 256);

/// JSON of the arguments the model supplied.
Property Arguments As %String(MAXLEN = 4000);

/// "EXECUTED" or "DENIED". A denial is an audit event too.
Property Outcome As %String(DISPLAYLIST = ",Executed,Denied", VALUELIST = ",EXECUTED,DENIED") [ InitialExpression = "EXECUTED" ];

/// Truncated — an audit row is evidence that something ran, not a data copy.
Property Result As %String(MAXLEN = 2000);

Property DurationMs As %Integer;

Property StatusText As %String(MAXLEN = 1000);

Property Username As %String(MAXLEN = 64) [ InitialExpression = {$Username} ];

Property LoggedAt As %TimeStamp [ InitialExpression = {$ZDateTime($ZTimeStamp, 3, 1)} ];

Index ByTool On (ToolName, LoggedAt);

Index ByOutcome On Outcome;

/// Convenience for the exercise gate: what did the agent actually do?
ClassMethod Summary()
{
    Write !, "Tool calls recorded:", !
    // %EXACT() is needed on a grouped string column: IRIS SQL groups with
    // SQLUPPER collation, so a bare GROUP BY ToolName reports "RESTARTHOST"
    // rather than "RestartHost".
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(ToolName) AS ToolName, Outcome, COUNT(*) AS N, AVG(DurationMs) AS AvgMs FROM Workshop_Data.AuditEntry GROUP BY %EXACT(ToolName), Outcome ORDER BY 1")
    Set n = 0
    While rs.%Next() {
        Set n = n + 1
        Write "  ", $Justify(rs.%Get("ToolName"), 34), "  ", $Justify(rs.%Get("Outcome"), 9), "  n=", rs.%Get("N"), "  avg=", rs.%Get("AvgMs"), "ms", !
    }
    If n = 0 {
        Write "  (none) - either no tool has run, or it ran on an UNGOVERNED path.", !
    }
}

ClassMethod Reset() As %Status
{
    &sql(DELETE FROM Workshop_Data.AuditEntry)
    Write "Audit cleared. SQLCODE=", SQLCODE, !
    Return $$$OK
}

Storage Default
{
<Data name="AuditEntryDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ToolName</Value>
</Value>
<Value name="3">
<Value>Arguments</Value>
</Value>
<Value name="4">
<Value>Outcome</Value>
</Value>
<Value name="5">
<Value>Result</Value>
</Value>
<Value name="6">
<Value>DurationMs</Value>
</Value>
<Value name="7">
<Value>StatusText</Value>
</Value>
<Value name="8">
<Value>Username</Value>
</Value>
<Value name="9">
<Value>LoggedAt</Value>
</Value>
</Data>
<DataLocation>^Workshop.Data.AuditEntryD</DataLocation>
<DefaultData>AuditEntryDefaultData</DefaultData>
<IdLocation>^Workshop.Data.AuditEntryD</IdLocation>
<IndexLocation>^Workshop.Data.AuditEntryI</IndexLocation>
<StreamLocation>^Workshop.Data.AuditEntryS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
