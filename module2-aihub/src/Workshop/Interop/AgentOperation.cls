Include (%AI, %occStatus)

/// Hosts the On-Call Desk agent as an ordinary business operation.
Class Workshop.Interop.AgentOperation Extends Ens.BusinessOperation
{

// MODULE D.3: this is an ordinary Ens.BusinessOperation. A business process
// calls the agent as it would call any other operation: queued, traced and
// retryable, with the Visual Trace available. There is no separate channel
// for AI.
//
// This class is supplied complete and is run rather than written. The
// learning objective is an observation about productions, not a build task.

Parameter ADAPTER = "Ens.InboundAdapter";

Parameter INVOCATION = "Queue";

/// Seconds to wait for the model before giving up and escalating to a human.
/// A hung model must degrade to a review item, never wedge the production.
Property ResponseTimeout As %Integer [ InitialExpression = 30 ];

/// Template context for the agent's instructions. Once Exercise A4 adds
/// {{siteName}} to XData INSTRUCTIONS, a bare %Init() fails with
/// <%AICore>TemplateUnresolvedName — so the production supplies the value,
/// and it is a Setting rather than a literal because which site this is
/// belongs to the deployment, not to the code.
Property SiteName As %String [ InitialExpression = "Boston General" ];

Parameter SETTINGS = "ResponseTimeout:Basic,SiteName:Basic";

Method OnMessage(pRequest As Workshop.Interop.TriageRequest, Output pResponse As Workshop.Interop.TriageResponse) As %Status
{
    Set pResponse = ##class(Workshop.Interop.TriageResponse).%New()
    Set pResponse.ConfigName = pRequest.ConfigName

    Try {
        Set agent = ##class(Workshop.Agent.OnCall).%New()
        // The context object is REQUIRED once A4 is done. Without it the
        // finale breaks for exactly the students who completed the exercise.
        Set sc = agent.%Init({"siteName": (..SiteName)})
        If $$$ISERR(sc) {
            // Cannot reach the model: escalate rather than fail the message.
            Set pResponse.Action = "REVIEW"
            Set pResponse.Summary = "Agent could not start: " _ $System.Status.GetErrorText(sc)
            Quit
        }

        Set session = agent.CreateSession({"max_iterations": 6})
        Set prompt = ..BuildPrompt(pRequest)
        Set response = agent.Chat(session, prompt)

        // Persist the reasoning layer, and record how to get back to it.
        Set pResponse.SessionId = ..SessionIdOf(session)

        Set stats = session.GetStats()
        If $IsObject(stats) {
            Set pResponse.PromptTokens     = +stats.%Get("total_prompt_tokens")
            Set pResponse.CompletionTokens = +stats.%Get("total_completion_tokens")
            Set pResponse.ToolCalls        = +stats.%Get("total_tool_calls")
            Set pResponse.LlmDurationMs    = +stats.%Get("total_llm_duration_ms")
        }

        Do ..Interpret(response.Content, .pResponse)

    } Catch ex {
        // Tolerant by design: anything unexpected becomes a human review
        // item, with the reason attached. Never let the agent break the pipe.
        Set pResponse.Action = "REVIEW"
        Set pResponse.Summary = "Agent error, escalating to a human: " _ $Extract(ex.DisplayString(), 1, 400)
    }

    // One line: a $$$macro cannot span lines any more than a statement can.
    Set host = $Select(pRequest.ConfigName '= "": pRequest.ConfigName, 1: "(all hosts)")
    Set note = "Triage verdict "_pResponse.Action_" for "_host_" - tools="_pResponse.ToolCalls_" tokens="_(pResponse.PromptTokens+pResponse.CompletionTokens)
    $$$LOGINFO(note)
    Return $$$OK
}

/// The output contract is asked for in the prompt AND enforced on parsing.
/// Asking politely is not enforcement — see Interpret().
Method BuildPrompt(pRequest As Workshop.Interop.TriageRequest) As %String
{
    Set target = $Select(pRequest.ConfigName '= "": "the business host '" _ pRequest.ConfigName _ "'", 1: "the production")
    Set p = "Triage " _ target _ ". Use your tools to read the real event log first."
    If pRequest.Context '= "" Set p = p _ " Context from the caller: " _ pRequest.Context _ "."
    Set p = p _ " Then reply with ONLY a JSON object, no prose and no code fence, shaped exactly:"
    Set p = p _ " {""action"":""ACK""|""REVIEW"",""summary"":""one or two sentences"",""confidence"":""low""|""medium""|""high""}."
    Set p = p _ " Use REVIEW whenever a human should look or act. Use ACK only when nothing needs doing."
    Return p
}

/// Parse the model's reply tolerantly: plain JSON, a fenced block, or JSON
/// embedded in prose. ANYTHING that fails to parse becomes REVIEW — a
/// malformed answer must never be read as "nothing to do here".
Method Interpret(content As %String, ByRef pResponse As Workshop.Interop.TriageResponse) As %Status
{
    Set pResponse.Action = "REVIEW"
    Set pResponse.Summary = $Extract(content, 1, 2000)

    Set json = ..ExtractJSON(content)
    If json = "" Return $$$OK

    Try {
        Set obj = ##class(%DynamicObject).%FromJSON(json)
        // Use %Get(), NOT $Get(obj.field). $Get is for locals and globals;
        // on a dynamic object property it yields "" without complaining, so
        // every field silently came back empty and the raw JSON was left as
        // the summary. The verdict still defaulted to REVIEW, which made the
        // bug look like correct behaviour.
        Set action = $ZConvert(obj.%Get("action"), "U")
        // Only ACK is accepted as a non-escalation. An unrecognised value,
        // including anything inventive like "RESTART", stays REVIEW.
        If action = "ACK" Set pResponse.Action = "ACK"
        If obj.%Get("summary") '= "" Set pResponse.Summary = $Extract(obj.%Get("summary"), 1, 2000)
        If obj.%Get("confidence") '= "" Set pResponse.Confidence = $Extract(obj.%Get("confidence"), 1, 32)
    } Catch parseEx {
        // Leave it as REVIEW with the raw text as the summary, but say so -
        // a silent catch here is how the bug above stayed hidden.
        $$$LOGWARNING("Could not parse the agent's JSON contract: "_$Extract(parseEx.DisplayString(), 1, 200))
    }
    Return $$$OK
}

/// Find a JSON object in the reply, fenced or not.
ClassMethod ExtractJSON(content As %String) As %String
{
    Set start = $Find(content, "{") - 1
    If start < 1 Return ""
    Set last = $Length(content)
    For i = last:-1:start { If $Extract(content, i) = "}" Return $Extract(content, start, i) }
    Return ""
}

/// %AI.Agent.Session is persistent, so it has an id once saved — that id is
/// what makes the reasoning replayable later.
ClassMethod SessionIdOf(session As %AI.Agent.Session) As %String
{
    Try {
        If '$IsObject(session) Return ""
        Do session.%Save()
        Return session.%Id()
    } Catch {
        Return ""
    }
}

}
