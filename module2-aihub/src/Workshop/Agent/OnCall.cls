Include (%AI, %occStatus)

/// Triages errors in an IRIS interoperability production for a human on-call
/// engineer. Proposes remediation; never performs it without approval.
Class Workshop.Agent.OnCall Extends %AI.Agent
{

// The /// comment above is published to %AI.Catalog, so keep it short.
// Implementation notes go here instead.
//
// Declarative: the persona lives in XData INSTRUCTIONS, tools are attached by
// Parameter TOOLSETS, and %OnInit() resolves the provider from the
// environment so this class never names a model or a key.
//
// The agent parameter is TOOLSETS (plural). `Parameter TOOLS` is the SKILL
// parameter - put it on an %AI.Agent and the class still compiles but
// silently attaches nothing.
//
// %Init() IS MANDATORY after %New(). Verified on 2026.3.0AI.154.0: it fails at
// CreateSession(), one call EARLIER than Chat(), with
//   <%AICore>IncompleteInitialization: Initialization incomplete for Provider
// Module A has students trigger this deliberately.

Parameter TOOLSETS = "Workshop.Tools.OnCall";

XData INSTRUCTIONS [ MimeType = "text/markdown" ]
{
You are a helpful assistant.

<!-- TODO (Exercise A.1): replace the line above with a triage brief.

     This block is the agent's system prompt.

     STEP 1. Before changing anything, run the triage question:

       set a = ##class(Workshop.Agent.OnCall).%New()  do a.%Init()
       set s = a.CreateSession()
       write a.Chat(s, "What is going wrong in the production right now?").Content

     The agent returns a usable answer even with the stub prompt above,
     because the tools are attached by Parameter TOOLSETS regardless of what
     this block contains. The reply is a list of event-log rows restated. It
     does not relate the failures to each other, does not state confidence,
     and does not reflect any restriction on what the agent may do.

     Keep that reply for comparison.

     STEP 2. Write the brief. Cover four points:

       1. Evidence. Call a tool before offering an opinion. Do not speculate
          about an error that has not been read.
       2. Grouping. Relate failures to each other rather than listing rows.
       3. Confidence. State how certain the diagnosis is.
       4. Permitted actions. The agent may propose any remediation. It may
          perform read operations only. Restarting a host requires human
          approval.

     The wording is yours. There is no single correct answer.

     STEP 3. Run the same question again and compare the two replies.

     EXPECTED RESULT: the second reply groups related failures - for example,
     HL7Router failing because LabOperation is refusing connections - and
     states a confidence level.
-->
}

/// Resolve the provider from AI_PROVIDER / AI_MODEL / <PROVIDER>_API_KEY.
/// Called by %Init().
Method %OnInit() As %Status
{
    Set sc = $$$OK
    Set provider = ##class(Workshop.Provider).Get(.model, .sc)
    If $$$ISERR(sc) Return sc
    Set ..Provider = provider
    Set ..Model = model
    Return $$$OK
}

}
