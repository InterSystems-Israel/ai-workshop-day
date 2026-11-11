Include (%occStatus)

/// The on-call desk's verdict, plus the evidence to justify it.
Class Workshop.Interop.TriageResponse Extends Ens.Response
{

// THE FORCED OUTPUT CONTRACT. The agent may only ever propose:
//   ACK     - informational, no action needed
//   REVIEW  - a human must decide (this is what creates a Workflow task)
// There is deliberately NO "RESTART" value. The agent cannot express
// "I did it", only "someone should". Borrowed from the community insurance-
// audit assistant, where the schema forces decision = NEEDS_REVIEW.
Property Action As %String(DISPLAYLIST = ",Acknowledged,Needs review", VALUELIST = ",ACK,REVIEW") [ InitialExpression = "REVIEW" ];

Property Summary As %String(MAXLEN = 2000);

Property ConfigName As %String(MAXLEN = 128);

/// Confidence the model expressed, if any. Advisory only.
Property Confidence As %String(MAXLEN = 32);

// --- The three evidence layers, as returned to the message flow ----------
// Message layer is Ens.MessageHeader and comes for free. These two do not.

/// Id of the persisted %AI.Agent.Session, so the reasoning is replayable
/// afterwards with ##class(%AI.Agent.Session).%OpenId(id).
Property SessionId As %String(MAXLEN = 64);

Property PromptTokens As %Integer [ InitialExpression = 0 ];

Property CompletionTokens As %Integer [ InitialExpression = 0 ];

Property ToolCalls As %Integer [ InitialExpression = 0 ];

Property LlmDurationMs As %Integer [ InitialExpression = 0 ];

}
