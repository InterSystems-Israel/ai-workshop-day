Include (%occStatus)

/// Drives the D.3 demo: start the production, trigger a triage, inspect the
/// human task, and act on it.
///
///   do ##class(Workshop.Interop.Setup).Start()
///   do ##class(Workshop.Interop.Setup).Trigger("HL7Router")
///   do ##class(Workshop.Interop.Setup).Tasks()
///   do ##class(Workshop.Interop.Setup).Approve()
///   do ##class(Workshop.Interop.Setup).Stop()
Class Workshop.Interop.Setup Extends %RegisteredObject
{

Parameter PRODUCTION = "Workshop.Interop.Production";

/// MUST match the EnsLib.Workflow.Operation's config item name in the
/// production - that name is the role name.
Parameter APPROVERROLE = "OnCallApprovers";

/// The human who will own approval tasks in the demo.
Parameter APPROVER = "oncall";

/// Create the Workflow user and role, then start the production.
///
/// Workflow users are EnsLib.Workflow.UserDefinition records, which are
/// SEPARATE from IRIS security users - a workflow user with the same name as
/// a login is a convention, not a requirement.
ClassMethod Start() As %Status
{
    Write !, "=== starting the On-Call Desk production ===", !

    Do ..EnsureApprover()

    Set sc = ##class(Ens.Director).StartProduction(..#PRODUCTION)
    If $$$ISERR(sc) {
        // Already running is the common, harmless case.
        Set txt = $System.Status.GetErrorText(sc)
        If txt [ "already" {
            Write "  already running", !
        } Else {
            Write "  FAILED: ", txt, !
            Return sc
        }
    } Else {
        Write "  started", !
    }
    Do ..Status()
    Return $$$OK
}

ClassMethod EnsureApprover() As %Status
{
    Write "-- workflow role and user --", !
    Set sc = ##class(EnsLib.Workflow.RoleDefinition).CreateRole(..#APPROVERROLE)
    Write "  role ", ..#APPROVERROLE, ": ", $Select($$$ISOK(sc): "ok", 1: "already present or " _ $System.Status.GetErrorText(sc)), !

    Set sc = ##class(EnsLib.Workflow.UserDefinition).CreateUser(..#APPROVER, "On-call engineer")
    Write "  user ", ..#APPROVER, ": ", $Select($$$ISOK(sc): "ok", 1: "already present or " _ $System.Status.GetErrorText(sc)), !

    Set sc = ##class(EnsLib.Workflow.RoleDefinition).AddUserToRole(..#APPROVERROLE, ..#APPROVER, 1, "On-call")
    Write "  membership: ", $Select($$$ISOK(sc): "ok", 1: "already present or " _ $System.Status.GetErrorText(sc)), !
    Return $$$OK
}

ClassMethod Status() As %Status
{
    Set sc = ##class(Ens.Director).GetProductionStatus(.name, .state)
    Write "  production: ", $Get(name), "  state=", $Case($Get(state), 1: "Running", 2: "Stopped", 3: "Suspended", 4: "Troubled", : $Get(state)), !
    Return $$$OK
}

/// Send one triage request through the production.
ClassMethod Trigger(configName As %String = "HL7Router", context As %String = "Monitoring noticed repeated send failures") As %Status
{
    Write !, "=== triggering triage for ", $Select(configName '= "": configName, 1: "(all hosts)"), " ===", !

    Set sc = ##class(Ens.Director).CreateBusinessService("TriageIn", .service)
    If $$$ISERR(sc) {
        Write "  cannot create the service - is the production running? ", $System.Status.GetErrorText(sc), !
        Return sc
    }

    Set req = ##class(Workshop.Interop.TriageRequest).%New()
    Set req.ConfigName = configName
    Set req.Context = context

    Set sc = service.ProcessInput(req, .out)
    If $$$ISERR(sc) {
        Write "  FAILED: ", $System.Status.GetErrorText(sc), !
        Return sc
    }

    If $IsObject($Get(out)) {
        Write "  verdict    : ", out.Action, !
        Write "  summary    : ", $Extract(out.Summary, 1, 400), !
        Write "  confidence : ", out.Confidence, !
        Write "  tool calls : ", out.ToolCalls, !
        Write "  tokens     : ", out.PromptTokens, " prompt / ", out.CompletionTokens, " completion", !
        Write "  session id : ", out.SessionId, "   (replay with %AI.Agent.Session.%OpenId)", !
    }
    Write !, "  Visual Trace: Management Portal > Interoperability > View > Message Viewer", !
    Return $$$OK
}

/// List the human tasks waiting in the worklist.
ClassMethod Tasks() As %Status
{
    Write !, "=== approval tasks awaiting a human ===", !
    // Columns verified against the real table: a bare %TaskStatus_* guess
    // returned nothing at all and made it look like no tasks existed.
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, %Subject, %RoleName, %UserName, %Action FROM EnsLib_Workflow.TaskResponse ORDER BY ID DESC")
    Set n = 0
    While rs.%Next() {
        Set n = n + 1
        Set act = rs.%Get("%Action")
        Write "  task ", rs.%Get("ID"), "  role=", rs.%Get("%RoleName"),
              "  owner=", $Select(rs.%Get("%UserName") '= "": rs.%Get("%UserName"), 1: "(unassigned)"),
              "  ", $Select(act '= "": "COMPLETED: " _ act, 1: "PENDING"), !
        Write "        ", rs.%Get("%Subject"), !
    }
    If n = 0 {
        Write "  (none) - trigger a triage that returns REVIEW first", !
    } Else {
        Write !, "  In the portal: Interoperability > View > Workflow Tasks (or the Workflow Inbox).", !
        Write "  From here:     do ##class(Workshop.Interop.Setup).Approve()", !
    }
    Return $$$OK
}

/// Act on the newest task as the on-call engineer: assign it, then complete
/// it with an action. This is what the portal's Workflow Inbox does when a
/// human clicks a button.
ClassMethod Approve(action As %String = "Approve restart", taskId As %String = "") As %Status
{
    Write !, "=== completing an approval task ===", !
    If taskId = "" {
        &sql(SELECT TOP 1 ID INTO :taskId FROM EnsLib_Workflow.TaskResponse ORDER BY ID DESC)
        If SQLCODE '= 0 {
            Write "  no tasks found", !
            Return $$$OK
        }
    }

    Set task = ##class(EnsLib.Workflow.TaskResponse).%OpenId(taskId)
    If '$IsObject(task) {
        Write "  cannot open task ", taskId, !
        Return $$$ERROR($$$GeneralError, "no such task")
    }

    Set sc = ##class(EnsLib.Workflow.Engine).AssignTask(task, ..#APPROVER, .count)
    Write "  assigned to ", ..#APPROVER, ": ", $Select($$$ISOK(sc): "ok", 1: $System.Status.GetErrorText(sc)), !

    Set sc = ##class(EnsLib.Workflow.Engine).CompleteTask(task, action)
    Write "  completed with action '", action, "': ", $Select($$$ISOK(sc): "ok", 1: $System.Status.GetErrorText(sc)), !

    // A human decision on the task is also the decision the Module C policy
    // is waiting for. Approving in the portal and approving the ledger row
    // must agree, or the agent is still refused.
    If action [ "Approve" {
        &sql(SELECT TOP 1 ID INTO :approvalId FROM Workshop_Data.Approval WHERE Status = 'REQUESTED' ORDER BY ID DESC)
        If SQLCODE = 0 {
            Do ##class(Workshop.Data.Approval).Approve(approvalId, ..#APPROVER)
            Write "  approval ledger row ", approvalId, " marked APPROVED by ", ..#APPROVER, !
            Write "  -> Workshop.Policy.ApprovalGate will now allow RestartHost on that host", !
        }
    }
    Return $$$OK
}

ClassMethod Stop() As %Status
{
    Set sc = ##class(Ens.Director).StopProduction()
    Write "Stopped: ", $Select($$$ISOK(sc): "ok", 1: $System.Status.GetErrorText(sc)), !
    Return $$$OK
}

/// The whole Module D.3 sequence in one call: start, trigger, show the task.
ClassMethod Demo() As %Status
{
    Do ..Start()
    Hang 2
    Do ..Trigger("HL7Router")
    Hang 1
    Do ..Tasks()
    Do ..Approve()
    Do ..Tasks()
    Return $$$OK
}

}
