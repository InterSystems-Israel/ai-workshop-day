Include (%occStatus)

/// Routes a triage request to the agent, then escalates to a human if the
/// verdict says so.
Class Workshop.Interop.DecisionProcess Extends Ens.BusinessProcess
{

// THE ASYNCHRONOUS APPROVAL PATH, and the answer to "AI Hub has no review
// queue": you do not need one. The NATIVE IRIS Workflow Engine is the queue.
// A REVIEW verdict sends an EnsLib.Workflow.TaskRequest to an
// EnsLib.Workflow.Operation, which creates a task in a human's worklist in
// the Management Portal. Nobody waits on an open HTTP request.
//
// Module C builds the SYNCHRONOUS gate by hand (a policy that refuses until
// an approval row exists). This is the same idea, production-grade and
// entirely native.

Property AgentTarget As %String [ InitialExpression = "OnCallAgent" ];

/// The EnsLib.Workflow.Operation to send human tasks to.
///
/// THIS NAME IS ALSO THE WORKFLOW ROLE NAME. There is no separate role
/// setting, and no %RoleName on TaskRequest: the operation's config item
/// name is what AutoCreateRole creates and what every task is stamped with.
/// Approvers must be members of a workflow role of exactly this name.
Property WorkflowTarget As %String [ InitialExpression = "OnCallApprovers" ];

Parameter SETTINGS = "AgentTarget:Basic,WorkflowTarget:Basic";

Method OnRequest(pRequest As Workshop.Interop.TriageRequest, Output pResponse As Workshop.Interop.TriageResponse) As %Status
{
    // Synchronous to the agent: we need its verdict before we can decide
    // anything. This is the line that makes the Module D.3 point — talking
    // to the AI is an ordinary SendRequestSync to an ordinary operation.
    Set sc = ..SendRequestSync(..AgentTarget, pRequest, .pResponse)
    If $$$ISERR(sc) {
        $$$LOGERROR("Agent call failed: "_$System.Status.GetErrorText(sc))
        Return sc
    }

    If pResponse.Action = "ACK" {
        $$$LOGINFO("ACK - no human needed: "_$Extract(pResponse.Summary, 1, 200))
        Return $$$OK
    }

    // REVIEW: hand it to a person, asynchronously, and finish.
    Return ..RequestApproval(pRequest, pResponse)
}

/// Build the human task and send it without waiting.
Method RequestApproval(pRequest As Workshop.Interop.TriageRequest, pResponse As Workshop.Interop.TriageResponse) As %Status
{
    Set host = $Select(pRequest.ConfigName '= "": pRequest.ConfigName, 1: "(production-wide)")

    // Record the agent's ASK in our own ledger too, so the Module C policy
    // and the Workflow task agree about what was requested.
    Set approvalId = ##class(Workshop.Data.Approval).Request(host, "RestartHost", $Extract(pResponse.Summary, 1, 1000))

    Set task = ##class(EnsLib.Workflow.TaskRequest).%New()
    Set task.%Subject = "On-call: review " _ host
    Set task.%Title = "Triage verdict needs a human decision"
    Set task.%Priority = 2
    // The actions a human may take. Deliberately explicit; the agent cannot
    // add to this list.
    Set task.%Actions = "Approve restart,Reject,Need more detail"
    Set task.%Message = ..TaskMessage(host, pResponse, approvalId)

    // ASYNC. Nothing blocks on the human.
    Set sc = ..SendRequestAsync(..WorkflowTarget, task, 0)
    If $$$ISERR(sc) {
        $$$LOGERROR("Could not create the approval task: "_$System.Status.GetErrorText(sc))
        Return sc
    }
    $$$LOGINFO("Approval task raised for "_host_" (approval row "_approvalId_")")
    Return $$$OK
}

/// What the human reads in their worklist. Everything needed to decide,
/// including how to replay the agent's reasoning.
Method TaskMessage(host As %String, pResponse As Workshop.Interop.TriageResponse, approvalId As %Integer) As %String
{
    Set nl = $Char(13, 10)
    Set m = "The on-call agent reviewed " _ host _ " and asks for a human decision." _ nl _ nl
    Set m = m _ "Agent summary:" _ nl _ pResponse.Summary _ nl _ nl
    Set m = m _ "Confidence: " _ $Select(pResponse.Confidence '= "": pResponse.Confidence, 1: "not stated") _ nl
    Set m = m _ "Tool calls made: " _ pResponse.ToolCalls _ nl
    Set m = m _ "Tokens: " _ pResponse.PromptTokens _ " prompt / " _ pResponse.CompletionTokens _ " completion" _ nl
    Set m = m _ "Model time: " _ pResponse.LlmDurationMs _ " ms" _ nl _ nl
    If pResponse.SessionId '= "" {
        Set m = m _ "Replay the agent's full reasoning:" _ nl
        Set m = m _ "  set s = ##class(%AI.Agent.Session).%OpenId(" _ pResponse.SessionId _ ")" _ nl
        Set m = m _ "  zw s.GetContext()" _ nl _ nl
    }
    Set m = m _ "Approval ledger row: " _ approvalId _ nl
    Set m = m _ "Approving here does NOT restart anything by itself - it records the decision." _ nl
    Set m = m _ "The agent still has to be asked, and the policy still checks this row."
    Return m
}

}
