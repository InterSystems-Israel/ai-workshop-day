Include (%occStatus)

/// A human approval for one production-changing action.
///
/// This is the row Workshop.Policy.ApprovalGate looks for. The agent can
/// create a REQUESTED row; only a human moves it to APPROVED.
Class Workshop.Data.Approval Extends %Persistent
{

// Deliberately boring and synchronous. Module D.3 shows what production
// actually looks like: EnsLib.Workflow.TaskRequest into an
// EnsLib.Workflow.Operation, with this table's role played by the native
// Workflow Engine's task list.

/// Business host the action targets, e.g. "HL7Router".
Property ConfigName As %String(MAXLEN = 128) [ Required ];

/// Tool the approval is for, e.g. "RestartHost".
Property Action As %String(MAXLEN = 128) [ Required ];

Property Status As %String(DISPLAYLIST = ",Requested,Approved,Rejected", VALUELIST = ",REQUESTED,APPROVED,REJECTED") [ InitialExpression = "REQUESTED", Required ];

/// Why the agent thinks this is needed. Written by the agent.
Property Justification As %String(MAXLEN = 1000);

Property RequestedBy As %String(MAXLEN = 64) [ InitialExpression = {$Username} ];

Property RequestedAt As %TimeStamp [ InitialExpression = {$ZDateTime($ZTimeStamp, 3, 1)} ];

/// Set when a human decides. An APPROVED row with no ApprovedBy is a bug.
Property ApprovedBy As %String(MAXLEN = 64);

Property ApprovedAt As %TimeStamp;

Index ByTarget On (ConfigName, Action, Status);

/// Is there a live approval for this action on this host?
/// This is the single question the authorization policy needs answered.
ClassMethod IsApproved(configName As %String, action As %String) As %Boolean
{
    &sql(SELECT TOP 1 ID INTO :id
         FROM Workshop_Data.Approval
         WHERE ConfigName = :configName AND Action = :action AND Status = 'APPROVED')
    // SQLCODE 0 = a row was found; 100 = none. Written out in full rather
    // than as 'SQLCODE, because the terse form is one stray ' away from
    // meaning the exact opposite - which is how this shipped at first.
    Return (SQLCODE = 0)
}

/// Record that the agent asked. Returns the new row id.
ClassMethod Request(configName As %String, action As %String, justification As %String = "") As %Integer
{
    Set row = ..%New()
    Set row.ConfigName = configName
    Set row.Action = action
    Set row.Justification = justification
    Set row.Status = "REQUESTED"
    Set sc = row.%Save()
    If $$$ISERR(sc) Return 0
    Return row.%Id()
}

/// What a human does. Deliberately a separate, explicit call.
ClassMethod Approve(id As %Integer, approver As %String = {$Username}) As %Status
{
    Set row = ..%OpenId(id)
    If '$IsObject(row) Return $$$ERROR($$$GeneralError, "no approval row " _ id)
    Set row.Status = "APPROVED"
    Set row.ApprovedBy = approver
    Set row.ApprovedAt = $ZDateTime($ZTimeStamp, 3, 1)
    Return row.%Save()
}

/// Clear every approval — lets students re-run the exercise from scratch.
ClassMethod Reset() As %Status
{
    &sql(DELETE FROM Workshop_Data.Approval)
    Write "Approvals cleared. SQLCODE=", SQLCODE, !
    Return $$$OK
}

Storage Default
{
<Data name="ApprovalDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ConfigName</Value>
</Value>
<Value name="3">
<Value>Action</Value>
</Value>
<Value name="4">
<Value>Status</Value>
</Value>
<Value name="5">
<Value>Justification</Value>
</Value>
<Value name="6">
<Value>RequestedBy</Value>
</Value>
<Value name="7">
<Value>RequestedAt</Value>
</Value>
<Value name="8">
<Value>ApprovedBy</Value>
</Value>
<Value name="9">
<Value>ApprovedAt</Value>
</Value>
</Data>
<DataLocation>^Workshop.Data.ApprovalD</DataLocation>
<DefaultData>ApprovalDefaultData</DefaultData>
<IdLocation>^Workshop.Data.ApprovalD</IdLocation>
<IndexLocation>^Workshop.Data.ApprovalI</IndexLocation>
<StreamLocation>^Workshop.Data.ApprovalS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
