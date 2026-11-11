Include (%AI, %occStatus)

/// Triage tools for an IRIS interoperability production: read the event log,
/// draft an incident note, and request a host restart.
Class Workshop.Tools.OnCall Extends %AI.ToolSet
{

// KEEP THE /// COMMENT ABOVE SHORT AND LLM-FACING. %AI.Catalog and the tool
// description the model sees are taken from it, so implementation notes there
// are tokens paid for on every single call. Notes like these belong in //
// comments, which are not published.
//
// REQUIRES an interoperability-enabled namespace. A <Query>'s SQL is prepared
// and syntax-checked AT COMPILE TIME, so without Ens_Util.Log this class does
// not merely fail at runtime, it fails to COMPILE:
//   ERROR #5540: SQLCODE: -30 Message: Table 'ENS_UTIL.LOG' not found
// Fix (belongs in iris.script, it does not survive a container recreate):
//   do ##class(%Library.EnsembleMgr).EnableNamespace("IRISAPP",1)


Property Name As %String [ InitialExpression = "On-Call Desk Tools" ];

Property Description As %String(MAXLEN = "") [ InitialExpression = "Triage tools over the interoperability production" ];

Parameter QUERYMAXROWS = 50;

XData Definition [ MimeType = application/xml ]
{
  <ToolSet Name="OnCallDesk">
    <Description>Triage the interoperability production: read errors, draft incident notes, request restarts.</Description>

    <Policies>
      <Authorization Class="Workshop.Policy.ApprovalGate"/>
      <!-- Attached here so Exercise D.2's %LogExecution takes effect the
           moment it is written. Writing the policy class is not enough: an
           unattached policy is never consulted, and the AuditEntry table
           stays empty.
           SAFE OVER MCP because it writes to a TABLE. %AI.Policy.ConsoleAudit
           writes to the current device, which during an HTTP request is the
           response body, and every tools/call then fails with a JSON
           serialization error. -->
      <Audit Class="Workshop.Policy.AuditLog"/>
    </Policies>

    <!-- Note: Arguments defaults must be a QUOTED string, a bare number or
         {expression}. The EAP guide's own example (= '') does NOT compile:
           <%AICore>QueryArgumentDefaultInvalid
         Inside an XML attribute that means &quot;&quot;. -->
    <!-- Ens.DataType.LogType maps 1=Assert 2=Error 3=Warning 4=Info
         5=Trace 6=Alert. Errors are Type 2, NOT 3 - filtering on 3 silently
         returns warnings and makes the agent report "no errors" during an
         outage, which is the worst possible failure for this scenario. -->
    <Query Name="RecentErrors" MaxRows="10"
           Description="List the most recent error and alert rows from the interoperability event log. Optionally filter to one business host by config name."
           Arguments="configName As %String = &quot;&quot;">
      <!-- COALESCE, not the OR guard the guide shows. An omitted or empty
           argument binds as NULL, so `:configName = ''` evaluates to NULL,
           the whole predicate is false and the query silently returns ZERO
           rows against a table that is full of them. -->
      <![CDATA[
        SELECT TOP 10 ID, ConfigName, Text, TimeLogged, Type
        FROM Ens_Util.Log
        WHERE Type IN (2, 6)
          AND (COALESCE(:configName, '') = '' OR ConfigName = :configName)
        ORDER BY ID DESC
      ]]>
    </Query>

    <Query Name="FailedMessages" MaxRows="10"
           Description="List recently failed message headers, newest first."
           Arguments="hours As %Integer = 24">
      <![CDATA[
        SELECT TOP 10 ID, SourceConfigName, TargetConfigName, Status, TimeCreated
        FROM Ens.MessageHeader
        WHERE Status = 'Error'
          AND TimeCreated > DATEADD('hour', -COALESCE(:hours, 24), CURRENT_TIMESTAMP)
        ORDER BY ID DESC
      ]]>
    </Query>

    <Tool Name="DraftIncidentNote" Method="DraftIncidentNote">
      <Description>Draft an incident note for the on-call engineer to review.</Description>
    </Tool>

    <Tool Name="RestartHost" Method="RestartHost">
      <Description>Restart a business host. Requires human approval and will be refused without it.</Description>
    </Tool>

    <!-- Helpers stay out of the LLM's tool list. Match is a POSIX regex;
         Tool= would match an exact name, and Rename= can relabel a tool. -->
    <Exclude Match="^Internal"/>
  </ToolSet>
}

/// Draft an incident note. Returns a structured draft, never a committed
/// record — the agent proposes, a human disposes.
///
/// TODO (Exercise B.1.2): add a DESCRIPTION type parameter to each of the three
/// arguments below, for example:
///
///     summary As %String(DESCRIPTION="One-line summary of the incident"),
///
/// The JSON schema sent to the model is inferred from this signature. An
/// argument without a DESCRIPTION is presented to the model without any
/// explanation of its purpose.
///
/// EXPECTED RESULT: %Discover() shows the descriptions under
/// parameters.properties for this tool.
Method DraftIncidentNote(
    summary As %String,
    configName As %String = "",
    severity As %String = "medium") As %DynamicObject
{
    Return {
        "draft":       1,
        "summary":     (summary),
        "config_name": (configName),
        "severity":    (severity),
        "drafted_by":  ($Username),
        "drafted_at":  ($ZDateTime($Horolog, 3)),
        "status":      "AWAITING_HUMAN_REVIEW"
    }
}

/// Restart a business host. Gated by Workshop.Policy.ApprovalGate, so in the
/// workshop this is reached only after a human approval row exists.
Method RestartHost(configName As %String(DESCRIPTION="Business host to restart")) As %DynamicObject
{
    // NOTE: left unimplemented on purpose - Module C gates it, and actually
    // restarting a host mid-workshop is nobody's idea of a good time.
    Return {"restarted": 0, "config_name": (configName), "note": "not implemented in the starter"}
}

Method InternalHelper() As %String
{
    Return "excluded from the tool list"
}

}
