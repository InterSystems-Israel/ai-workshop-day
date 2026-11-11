Include (%AI, %occStatus)

/// End-to-end LLM verification. Run this before writing any exercise that
/// depends on the model surface.
///
///   do ##class(Workshop.Probe.LLMCheck).Run()
///
/// Checks, in order:
///   1. What the instance can see of the provider configuration.
///   2. That %New() WITHOUT %Init() fails on Chat() — the Module A teaching
///      moment. Verifying the error text is the point.
///   3. That %New() + %Init() + Chat() works and response.Content is the
///      accessor (NOT response.%Get("content")).
///   4. That the agent actually calls a tool, and that the guarded tool is
///      refused by the authorization policy.
///   5. Session telemetry via GetStats().
Class Workshop.Probe.LLMCheck Extends %RegisteredObject
{

ClassMethod Run() As %Status
{
    Write !, "===================================================", !
    Write "  AI Hub workshop - LLM end-to-end check", !
    Write "===================================================", !

    Do ..Check1Config()
    Do ..Check2MissingInit()
    Do ..Check3Chat()
    Do ..Check4Tools()
    Write !, "=== done ===", !
    Return $$$OK
}

ClassMethod Check1Config()
{
    Write !, "--- 1. provider configuration -------------------", !
    Do ##class(Workshop.Provider).Report()
    Set sc = $$$OK
    Set p = ##class(Workshop.Provider).Get(.model, .sc)
    If $$$ISERR(sc) {
        Write "FAIL: ", $System.Status.GetErrorText(sc), !
        Quit
    }
    Write "provider ok : ", p.Name, "  model=", model, !
}

/// The deliberate failure. We want the EXACT error a student will see.
ClassMethod Check2MissingInit()
{
    Write !, "--- 2. %New() with NO %Init() (expect failure) --", !
    Try {
        Set agent = ##class(Workshop.Agent.OnCall).%New()
        Set session = agent.CreateSession()
        Set response = agent.Chat(session, "Say OK.")
        Write "UNEXPECTED: it answered: ", $Extract(response.Content, 1, 120), !
        Write "  -> the %Init() teaching moment may no longer hold on this build.", !
    } Catch ex {
        Write "got (as expected): ", ex.DisplayString(), !
        Write "  code=", ex.Name, "  location=", ex.Location, !
    }
}

ClassMethod Check3Chat()
{
    Write !, "--- 3. %New() + %Init() + Chat() ----------------", !
    Try {
        Set agent = ##class(Workshop.Agent.OnCall).%New()
        Set sc = agent.%Init({"siteName": "Boston General"})
        If $$$ISERR(sc) { Write "FAIL %Init(): ", $System.Status.GetErrorText(sc), ! Quit }
        Write "%Init() ok. model=", agent.Model, !

        Set session = agent.CreateSession()
        Set response = agent.Chat(session, "Reply with exactly: READY")
        Write "response.Content = ", response.Content, !

        // The documented trap: %Get("content") throws METHOD DOES NOT EXIST.
        Try {
            Set bad = response.%Get("content")
            Write "NOTE: response.%Get(""content"") also worked -> ", bad, !
        } Catch e2 {
            Write "confirmed: response.%Get(""content"") fails -> ", e2.Name, !
        }

        Write "HasToolCalls = ", response.HasToolCalls(), !
        Write "stats = ", session.GetStats().%ToJSON(), !
    } Catch ex {
        Write "FAIL: ", ex.DisplayString(), !
    }
}

ClassMethod Check4Tools()
{
    Write !, "--- 4. tool calling + policy refusal ------------", !
    Try {
        Set agent = ##class(Workshop.Agent.OnCall).%New()
        Set sc = agent.%Init({"siteName": "Boston General"})
        If $$$ISERR(sc) { Write "FAIL %Init(): ", $System.Status.GetErrorText(sc), ! Quit }

        Write "tools the LLM can see:", !
        Set ts = ##class(Workshop.Tools.OnCall).%New()
        Set discovered = ts.%Discover()
        Set tools = discovered.tools
        For i = 0:1:tools.%Size() - 1 {
            Write "   - ", tools.%Get(i).name, "  (stateful=", tools.%Get(i).stateful, ")", !
        }

        Set session = agent.CreateSession()
        Write !, "Q: Any errors in the production right now?", !
        Set response = agent.Chat(session, "Are there any errors in the production right now? Use your tools.")
        Write "A: ", $Extract(response.Content, 1, 600), !

        Write !, "Q: Restart the host (should be refused by policy)", !
        Set session2 = agent.CreateSession()
        Set r2 = agent.Chat(session2, "Restart the business host named HL7Router immediately.")
        Write "A: ", $Extract(r2.Content, 1, 600), !
    } Catch ex {
        Write "FAIL: ", ex.DisplayString(), !
    }
}

}
