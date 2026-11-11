Include (%AI, %occStatus)

/// An incident worklist the on-call agent builds up as it triages.
Class Workshop.Tools.Worklist Extends %AI.ToolSet
{

// ===========================================================================
// EXERCISE C1 — convert this ToolSet to instance state
//
// As supplied, AddItem and ListItems are ClassMethods. A ClassMethod cannot
// access instance properties, so they store items in a process-private
// global rather than in ..Items. That global is shared by every agent in
// the process, so the worklist is not per-agent.
//
// TASK: convert both methods to instance Methods backed by ..Items. The two
// TODO blocks below show the required shape.
//
// Only instance Methods can access instance properties. %AI.ToolSet derives
// the stateful flag from the method type, so no declaration is required.
//
// EXPECTED RESULT: %Discover() reports "stateful": true for both methods.
// Before the change it reports false.
// ===========================================================================

Property Name As %String [ InitialExpression = "Incident Worklist" ];

Property Description As %String(MAXLEN = "") [ InitialExpression = "Scratch worklist of incidents being triaged in this session" ];

/// Per-agent state. Newline-separated, one incident per line.
///
/// LIFETIME: a tool object is created when the agent is instantiated and
/// lives as long as the agent, not as long as the session. State therefore
/// persists across CreateSession(). Clearing it requires a new agent.
/// Exercise C step 3 demonstrates this.
Property Items As %String(MAXLEN = "") [ InitialExpression = "" ];

XData Definition [ MimeType = application/xml ]
{
  <ToolSet Name="IncidentWorklist">
    <Description>Keep a running worklist of incidents during a triage session.</Description>
    <Tool Name="AddItem" Method="AddItem">
      <Description>Add one incident to the worklist.</Description>
    </Tool>
    <Tool Name="ListItems" Method="ListItems">
      <Description>List every incident currently on the worklist.</Description>
    </Tool>
    <Tool Name="ClearItems" Method="ClearItems">
      <Description>Empty the worklist.</Description>
    </Tool>
  </ToolSet>
}

/// Add an incident to the worklist.
ClassMethod AddItem(item As %String(DESCRIPTION="One-line incident description")) As %DynamicObject
{
    // TODO (Exercise C.1a): change this to an instance Method using ..Items:
    //
    //   Method AddItem(item As %String(DESCRIPTION="...")) As %DynamicObject
    //   {
    //       Set ..Items = ..Items _ item _ $Char(10)
    //       Return {"added": (item), "count": (..Count())}
    //   }
    //
    // The implementation below uses a process-private global because a
    // ClassMethod cannot access ..Items.
    Set ^||WorklistFallback($Increment(^||WorklistFallback)) = item
    Return {"added": (item), "count": (+$Get(^||WorklistFallback)), "stateful": 0}
}

/// List the worklist.
ClassMethod ListItems() As %DynamicObject
{
    // TODO (Exercise C.1b): change this to an instance Method reading ..Items:
    //
    //   Method ListItems() As %DynamicObject
    //   {
    //       Set out = []
    //       For i = 1:1:$Length(..Items, $Char(10)) {
    //           Set line = $Piece(..Items, $Char(10), i)
    //           Continue:line=""
    //           Do out.%Push(line)
    //       }
    //       Return {"items": (out), "count": (out.%Size())}
    //   }
    Set out = []
    For i = 1:1:+$Get(^||WorklistFallback) {
        Do out.%Push($Get(^||WorklistFallback(i)))
    }
    Return {"items": (out), "count": (out.%Size()), "stateful": 0}
}

/// Empty the worklist.
Method ClearItems() As %DynamicObject
{
    // Already an instance Method, as a worked example of the shape the two
    // TODOs above should end up in.
    Set ..Items = ""
    Kill ^||WorklistFallback
    Return {"cleared": 1}
}

/// How many incidents are on the list. Not exposed to the LLM.
Method Count() As %Integer
{
    Set n = 0
    For i = 1:1:$Length(..Items, $Char(10)) {
        If $Piece(..Items, $Char(10), i) '= "" Set n = n + 1
    }
    Return n
}

}
