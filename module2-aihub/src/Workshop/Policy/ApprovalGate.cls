Include (%AI, %occStatus)

/// Authorization policy for the On-Call Desk.
///
/// Read tools are permitted. Actions that change the production (restarting
/// a business host, resending a message) are refused unless a human approval
/// row exists. The agent may propose an action; only a human releases it.
///
/// COMPILE ORDER MATTERS: a ToolSet naming this class in <Policies> resolves
/// it at compile time via a method generator. Compile the policy BEFORE the
/// ToolSet or you get a bare <CLASS DOES NOT EXIST> from
/// %AI.ToolSet.Specification.Compiler.
Class Workshop.Policy.ApprovalGate Extends %AI.Policy.Authorization
{

/// Tools whose names match this pattern need an approval row.
Parameter GUARDED = "RestartHost,ResendMessage";

Method %CanExecute(toolref As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
{
    For i = 1:1:$Length(..#GUARDED, ",") {
        Set guarded = $Piece(..#GUARDED, ",", i)
        Continue:guarded=""
        If $Find(toolref, guarded) {
            // TODO (Exercise C.3): replace this unconditional refusal with a
            // check against the approval ledger.
            //
            // 1. Read the target host from `call`. The agent supplies it, so
            //    treat it as untrusted input: an approval for one host must
            //    not authorise an action on another host.
            // 2. Call Workshop.Data.Approval.IsApproved(configName, guarded).
            // 3. Return $$$OK when approved. Otherwise return an error that
            //    names the host.
            //
            // EXPECTED RESULT: RestartHost is refused until an APPROVED row
            // exists for that host, and stays refused for other hosts.
            Set msg = "DENIED: '"_guarded_"' requires a human approval row. Draft the change and ask the on-call engineer to approve it."
            Return $$$ERROR($$$GeneralError, msg)
        }
    }
    Return $$$OK
}

/// Guarded tools stay visible so the LLM knows they exist and can offer to
/// request approval. Hiding them makes the agent claim it cannot help.
Method %CanList(toolref As %String, metadata As %DynamicObject) As %Boolean
{
    Return 1
}

}
