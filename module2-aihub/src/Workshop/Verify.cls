Include (%AI, %occStatus)

/// The Module 0 environment gate. A stop sign, not a suggestion.
///
///   do ##class(Workshop.Verify).Run()
Class Workshop.Verify Extends %RegisteredObject
{

// Every check here corresponds to a failure that ACTUALLY HAPPENED while
// building this workshop, not to a hypothetical. In particular:
//   - interop missing stops the Module B ToolSet COMPILING, not just running
//   - a provider constructs happily with a bogus key, so check 5 is not
//     enough on its own and check 6 is the one that matters
//   - the MCP app silently serves zero tools without MatchRoles
//   - a working Management Portal does NOT prove Atelier REST works

Parameter EXPECTEDNAMESPACE = "IRISAPP";

/// This image's own private web server, inside this container. A
/// non-community image has none, and would need a Web Gateway container here
/// instead ("webgateway", port 80) — see docs/APPENDIX-webgateway.md.
Parameter WEBHOST = "localhost";

Parameter WEBPORT = 52773;

/// Runs in two modes, because students set this up BEFORE they are given an
/// API key and need a meaningful answer then.
///
///   No provider key set  -> the three provider checks report WAIT, and the
///                           gate still passes. Everything that can be
///                           verified without a key is verified, including
///                           outbound HTTPS to the provider's real host.
///   Provider key set     -> those three are enforced as hard failures.
ClassMethod Run() As %Status
{
    Set pass = 0, fail = 0, wait = 0
    Set haveKey = ..HaveProviderKey(.keyvar, .which)

    Write !, "=================================================================", !
    Write "  AI Hub workshop - environment gate", !
    Write "=================================================================", !
    If 'haveKey {
        Write "  No ", keyvar, " set, so the three provider checks are", !
        Write "  reported as WAIT rather than failures. Everything else is", !
        Write "  checked, including that this container can reach ", which, ".", !
        Write "-----------------------------------------------------------------", !
    }

    Do ..Check(.pass, .fail, .wait, "namespace is " _ ..#EXPECTEDNAMESPACE, ..Namespace())
    Do ..Check(.pass, .fail, .wait, "interoperability enabled", ..Interop())
    Do ..Check(.pass, .fail, .wait, "AI Hub classes present", ..AIClasses())
    Do ..Check(.pass, .fail, .wait, "outbound HTTPS reaches " _ which, ..Egress())
    Do ..Check(.pass, .fail, .wait, "provider key configured", ..ProviderEnv())
    Do ..Check(.pass, .fail, .wait, "provider can be constructed", ..ProviderBuild())
    Do ..Check(.pass, .fail, .wait, "provider answers a real prompt", ..ProviderAnswers())
    Do ..Check(.pass, .fail, .wait, "demo event log seeded", ..Seeded())
    Do ..Check(.pass, .fail, .wait, "Atelier REST answers on 52773", ..Atelier())
    Do ..Check(.pass, .fail, .wait, "MCP Server /mcp/oncall registered", ..MCPApp())

    Write "-----------------------------------------------------------------", !
    Write "  ", pass, " OK"
    If wait > 0 Write "   ", wait, " WAIT"
    If fail > 0 Write "   ", fail, " FAIL"
    Write !

    If fail > 0 {
        Write !, "  STOP. Do not continue to Module A.", !
        Write "  Fix the FAIL lines above, then run this again.", !
        Write "  docs/TROUBLESHOOTING.md has one section per check.", !
        Write "=================================================================", !
        Return $$$ERROR($$$GeneralError, fail _ " environment check(s) failed")
    }
    If wait > 0 {
        Write !, "  Everything that can be checked without a key passed.", !
        Write "  The container, IRIS and the network are ready.", !
        Write "  On the day: put your key in .env, then", !
        Write "    docker compose up -d --force-recreate iris", !
        Write "  and run this again. You want ", pass + wait, " OK.", !
        Write "=================================================================", !
        Return $$$OK
    }
    Write !, "  Environment is good. Continue to Module A.", !
    Write "=================================================================", !
    Return $$$OK
}

/// Is a provider key configured at all? Also returns the variable we looked
/// for and the provider name, both of which the report needs.
ClassMethod HaveProviderKey(Output keyvar As %String, Output which As %String) As %Boolean
{
    Set which = $ZConvert($ZStrip($System.Util.GetEnviron("AI_PROVIDER"), "<>W"), "L")
    If which = "" Set which = "anthropic"
    Set keyvar = "AI_PROVIDER key"
    If ##class(%Dictionary.CompiledClass).%ExistsId("Workshop.Provider") {
        Set keyvar = ##class(Workshop.Provider).KeyVariable(which)
    }
    If $ZStrip($System.Util.GetEnviron(keyvar), "<>W") '= "" Return 1
    If $Get(^||ENV(keyvar)) '= "" Return 1
    Return 0
}

/// Each check returns "" for pass, "WAIT:<reason>" for not-yet, or a
/// human-readable reason for failure.
ClassMethod Check(ByRef pass As %Integer, ByRef fail As %Integer, ByRef wait As %Integer, label As %String, reason As %String)
{
    If reason = "" {
        Set pass = pass + 1
        Write "  OK    ", label, !
    } ElseIf $Extract(reason, 1, 5) = "WAIT:" {
        Set wait = wait + 1
        Write "  WAIT  ", label, !
        Write "          -> ", $Extract(reason, 6, *), !
    } Else {
        Set fail = fail + 1
        Write "  FAIL  ", label, !
        Write "          -> ", reason, !
    }
}

/// Can this container reach the LLM vendor over HTTPS? Checked WITHOUT a key,
/// so students can prove their network before the workshop.
///
/// Deliberately uses the %AI provider itself with a junk key rather than
/// %Net.HttpRequest. The provider goes through the same Rust HTTP client, TLS
/// stack, CA roots and proxy handling that the real calls will use, so this
/// tests the actual path. An IRIS-side HTTP request would need its own SSL
/// configuration and could pass or fail for reasons that never affect an
/// agent.
///
/// The vendor REJECTING our junk key is the success signal: an answer of any
/// kind means DNS, TCP and TLS all worked. Verified error texts:
///   network ok, key bad -> "Authentication failed: Incorrect API key provided"
///   network broken      -> "client error (Connect): dns error: ..."
ClassMethod Egress() As %String
{
    Set which = $ZConvert($ZStrip($System.Util.GetEnviron("AI_PROVIDER"), "<>W"), "L")
    If which = "" Set which = "anthropic"

    // Ollama is a local service, not an internet endpoint. Reaching it proves
    // something quite different, so say so rather than implying egress works.
    If which = "ollama" {
        Return "WAIT:provider is 'ollama', which is local. This check tests internet egress and does not apply."
    }

    Try {
        Set settings = {"api_key": "sk-workshop-egress-probe-not-a-real-key"}
        Set provider = ##class(%AI.Provider).Create(which, settings)
        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = ##class(Workshop.Provider).DefaultModel(which)
        Set session = agent.CreateSession({"max_tokens": 1})
        Do agent.Chat(session, "ping")
        // Someone's key is in the environment after all. Fine either way.
        Return ""
    } Catch ex {
        Set msg = ex.DisplayString()
        // Network-layer failures. These are the ones worth reporting.
        If $Find(msg, "dns error") || $Find(msg, "failed to lookup") {
            Return "DNS failure. This container cannot resolve the provider host, although your "
                _ "machine probably can - Docker's default resolvers are blocked on some networks. "
                _ "Set DNS_SERVER in .env to a resolver your network allows, then "
                _ "docker compose up -d --force-recreate iris"
        }
        If $Find(msg, "(Connect)") || $Find(msg, "Connection refused") || $Find(msg, "timed out") {
            Return "Cannot open a connection to the provider. DNS may be fine but the connection is "
                _ "blocked - check for a proxy or an outbound firewall rule. Detail: "
                _ $Extract(msg, 1, 160)
        }
        If $Find(msg, "certificate") || $Find(msg, "tls") || $Find(msg, "TLS") {
            Return "TLS failure reaching the provider, which usually means an intercepting proxy "
                _ "whose certificate this container does not trust. Detail: " _ $Extract(msg, 1, 160)
        }
        // Anything else means we reached the vendor and it talked back:
        // a rejected key, an unknown model, a rate limit. Network is fine.
        Return ""
    }
}

ClassMethod Namespace() As %String
{
    If $Namespace = ..#EXPECTEDNAMESPACE Return ""
    Return "you are in " _ $Namespace _ ". Run: zn """ _ ..#EXPECTEDNAMESPACE _ """"
}

ClassMethod Interop() As %String
{
    If ##class(%Dictionary.CompiledClass).%ExistsId("Ens.Util.Log") Return ""
    Return "Ens.Util.Log is missing, so Workshop.Tools.OnCall cannot COMPILE (SQLCODE -30). "
        _ "The namespace must be created with Interop=1 in merge.cpf - rebuild the image."
}

ClassMethod AIClasses() As %String
{
    Set missing = ""
    For c = "%AI.Agent", "%AI.ToolSet", "%AI.Provider", "%AI.MCP.Service", "%AI.Catalog" {
        If '##class(%Dictionary.CompiledClass).%ExistsId(c) Set missing = missing _ $Select(missing = "": "", 1: ", ") _ c
    }
    If missing = "" Return ""
    Return "missing: " _ missing _ " - is this an AI-enabled image?"
}

ClassMethod ProviderEnv() As %String
{
    If '##class(%Dictionary.CompiledClass).%ExistsId("Workshop.Provider") {
        Return "Workshop.Provider did not compile"
    }
    If ..HaveProviderKey(.keyvar, .which) Return ""
    // No key is the EXPECTED state before the workshop, so this is not a
    // failure. The instructor hands keys out on the day.
    Return "WAIT:" _ keyvar _ " is not set yet. Expected before the workshop. On the day, put it "
        _ "in .env and run: docker compose up -d --force-recreate iris"
}

ClassMethod ProviderBuild() As %String
{
    If '..HaveProviderKey() Return "WAIT:needs a provider key"
    Set sc = $$$OK
    Set provider = ##class(Workshop.Provider).Get(.model, .sc)
    If $$$ISERR(sc) Return $System.Status.GetErrorText(sc)
    If '$IsObject(provider) Return "no provider returned"
    Return ""
}

/// The check that actually proves the key. A provider constructs fine with a
/// bogus key, so this is the one that catches a wrong key, a blocked DNS
/// resolver, or no egress at all.
ClassMethod ProviderAnswers() As %String
{
    If '..HaveProviderKey() {
        Return "WAIT:needs a provider key. The egress check above already proved the network path."
    }
    Try {
        Set agent = ##class(Workshop.Agent.OnCall).%New()
        // The context object is passed ALWAYS, deliberately. Once a student
        // has done Exercise A4 the instructions contain {{siteName}}, and a
        // bare %Init() then fails with
        //   <%AICore>TemplateUnresolvedName: unresolved name '{{siteName}}'
        // which would make this gate report a false FAIL on a correct
        // solution. An unused template key is harmless, so the starter class
        // accepts the same call.
        Set sc = agent.%Init({"siteName": "Boston General"})
        If $$$ISERR(sc) Return $System.Status.GetErrorText(sc)
        Set session = agent.CreateSession()
        Set response = agent.Chat(session, "Reply with exactly: OK")
        If response.Content = "" Return "the model returned empty content"
        Return ""
    } Catch ex {
        Set msg = ex.DisplayString()
        If $Find(msg, "dns error") {
            Return "DNS failure reaching the provider. Docker's default resolvers may be blocked "
                _ "on this network - set DNS_SERVER in .env. Detail: " _ $Extract(msg, 1, 160)
        }
        Return $Extract(msg, 1, 220)
    }
}

ClassMethod Seeded() As %String
{
    If '##class(%Dictionary.CompiledClass).%ExistsId("Ens.Util.Log") Return "no Ens.Util.Log (see the interop check)"
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM Ens_Util.Log WHERE Type IN (2,6)")
    Do rs.%Next()
    If rs.%Get("N") > 0 Return ""
    Return "no error/alert rows to triage. Run: do ##class(Workshop.Demo.Seed).Run()"
}

/// This is what the VS Code ObjectScript extension needs. A working
/// Management Portal does NOT prove it - the portal is a .csp path and
/// /api/atelier/ is extensionless, and the two have failed independently.
///
/// Credentials ARE required. /api/atelier ships with AutheEnabled=32
/// (password), so an unauthenticated request correctly returns 401 - that is
/// not an environment fault, and an earlier version of this check reported a
/// false FAIL by omitting them.
///
/// RETRIES, deliberately. Immediately after `docker compose up -d` the web
/// server can answer before the instance has finished unexpiring the shipped
/// passwords, and the first request comes back 401 before settling. Without a
/// retry, students hit a phantom failure on the very first thing they run.
ClassMethod Atelier() As %String
{
    For attempt = 1:1:4 {
        Set reason = ..AtelierOnce()
        If reason = "" Return ""
        // Only a 401/transport blip is worth retrying; a 404 is a real
        // configuration fault and will not fix itself.
        If '$Find(reason, "401"), '$Find(reason, "cannot reach") Return reason
        Hang 3
    }
    Return reason _ "  (still failing after 4 attempts over ~12s, so this is not just a cold start)"
}

ClassMethod AtelierOnce() As %String [ Private ]
{
    Try {
        Set r = ##class(%Net.HttpRequest).%New()
        Set r.Server = ..#WEBHOST
        Set r.Port = ..#WEBPORT
        Set r.Timeout = 15
        Set r.Username = $System.Util.GetEnviron("IRISUSERNAME")
        Set r.Password = $System.Util.GetEnviron("IRISPASSWORD")
        If r.Username = "" Set r.Username = "_SYSTEM"
        If r.Password = "" Set r.Password = "SYS"
        Set sc = r.Get("/api/atelier/")
        If $$$ISERR(sc) Return $System.Status.GetErrorText(sc)
        If r.HttpResponse.StatusCode = 200 Return ""
        If r.HttpResponse.StatusCode = 401 {
            Return "HTTP 401 with credentials. The shipped passwords are expired until "
                _ "iris.script unexpires them - this check retries. If it persists: "
                _ "do ##class(Security.Users).Get(""_SYSTEM"",.p) zw p(""ChangePassword"") "
                _ "(1 means expired; fix with Security.Users.UnExpireUserPasswords(""*""))"
        }
        If r.HttpResponse.StatusCode = 404 {
            Return "HTTP 404 - /api/atelier is not served. Check the %Service_WebGateway and "
                _ "/api/atelier application are enabled in the Management Portal. If you swapped in "
                _ "a non-community image, see docs/APPENDIX-webgateway.md."
        }
        Return "HTTP " _ r.HttpResponse.StatusCode
    } Catch ex {
        Return "cannot reach the private web server on " _ ..#WEBHOST _ ":" _ ..#WEBPORT
            _ " - " _ $Extract(ex.DisplayString(), 1, 160)
    }
}

ClassMethod MCPApp() As %String
{
    New $Namespace
    Set $Namespace = "%SYS"
    If '##class(Security.Applications).Exists("/mcp/oncall") {
        Return "not registered. Run: do ##class(Workshop.MCP.Setup).Run(""IRISAPP"")"
    }
    Set sc = ##class(Security.Applications).Get("/mcp/oncall", .props)
    If $$$ISERR(sc) Return $System.Status.GetErrorText(sc)
    If $Get(props("Type")) '= 18 {
        Return "Type is " _ $Get(props("Type")) _ ", not 18 - it is not an MCP Server application"
    }
    If $Get(props("MatchRoles")) '[ "%All" {
        Return "MatchRoles is """ _ $Get(props("MatchRoles")) _ """. Without :%All the "
            _ "unauthenticated discovery probe gets HTTP 403 and tools/list silently returns "
            _ "only the iris_status meta tool."
    }
    Return ""
}

}
