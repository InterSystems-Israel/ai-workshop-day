Include (%AI, %occStatus)

/// Build-time setup for the AI Hub workshop. Called once from iris.script.
Class Workshop.Setup.Build Extends %RegisteredObject
{

// WHY THIS CLASS EXISTS: iris.script is piped into the IRIS terminal, where
// each line is executed as its own command, so a multi-line { } block fails
// with a bare <SYNTAX> error. Try/catch, multi-line loops and multi-line
// $listbuild all break. Keeping iris.script to single-line statements and
// putting the real logic in a compiled class avoids the whole class of
// problem - and makes this testable on its own.

Parameter DEVROOT = "/home/irisowner/dev/Workshop/";

/// Compile order is LOAD-BEARING: a ToolSet naming a policy class in
/// <Policies> resolves it at COMPILE time via a method generator, so the
/// policy must already be compiled or you get a bare
/// <CLASS DOES NOT EXIST> from %AI.ToolSet.Specification.Compiler.
/// A plain "compile everything" passes or fails on queue order.
Parameter COMPILEORDER = "Provider.cls,Lab.cls,Data/Approval.cls,Data/AuditEntry.cls,Policy/ApprovalGate.cls,Policy/AuditLog.cls,Tools/OnCall.cls,Tools/Worklist.cls,Agent/OnCall.cls,MCP/Service.cls,MCP/Setup.cls,Setup/ConfigStore.cls,Interop/TriageRequest.cls,Interop/TriageResponse.cls,Interop/AgentOperation.cls,Interop/DecisionProcess.cls,Interop/TriageService.cls,Interop/Production.cls,Interop/Setup.cls,Demo/Seed.cls,Probe/LLMCheck.cls,Verify.cls";

/// Pinned. The dev template fetches .../zpm/latest/installer, which drifts
/// between builds and needs build-time internet.
Parameter ZPMVERSION = "0.9.0";

ClassMethod Run() As %Status
{
    Write !, "=== AI Hub workshop build setup ===================", !
    Write "namespace: ", $Namespace, !
    Write "interop enabled (Ens.Util.Log): ", ##class(%Dictionary.CompiledClass).%ExistsId("Ens.Util.Log"), !

    Do ..InstallZPM()
    Do ..CompileWorkshop()
    Do ..RegisterMCP()
    Do ..RegisterDescriptors()
    Do ..Seed()

    Write !, "=== build setup complete ==========================", !
    Return $$$OK
}

/// ZPM is deliberately NOT load-bearing: the Workshop classes are compiled by
/// CompileWorkshop() below, so a failed download costs only the VS Code
/// per-namespace-settings nicety.
ClassMethod InstallZPM() As %Status
{
    Write !, "--- ZPM ", ..#ZPMVERSION, " (pinned) ---", !
    Try {
        Set r = ##class(%Net.HttpRequest).%New()
        Set r.Server = "pm.community.intersystems.com"
        Set r.SSLConfiguration = "ISC.FeatureTracker.SSL.Config"
        Set sc = r.Get("/packages/zpm/" _ ..#ZPMVERSION _ "/installer")
        If $$$ISERR(sc) {
            Write "  WARNING: ", $System.Status.GetErrorText(sc), " - continuing without ZPM.", !
            Return $$$OK
        }
        If r.HttpResponse.StatusCode '= 200 {
            Write "  WARNING: HTTP ", r.HttpResponse.StatusCode, " for ZPM ", ..#ZPMVERSION, " - continuing without ZPM.", !
            Return $$$OK
        }
        Do $System.OBJ.LoadStream(r.HttpResponse.Data, "c")
        Write "  installed", !
    } Catch ex {
        Write "  WARNING: ", ex.DisplayString(), " - continuing without ZPM.", !
    }
    Return $$$OK
}

/// `root` lets Workshop.Lab recompile from the pristine starters baked into
/// the image rather than from the student's edited src/ tree.
ClassMethod CompileWorkshop(root As %String = {..#DEVROOT}) As %Status
{
    Write !, "--- compiling Workshop package in dependency order ---", !
    Write "    from ", root, !
    Set failures = 0
    For i = 1:1:$Length(..#COMPILEORDER, ",") {
        Set item = $Piece(..#COMPILEORDER, ",", i)
        Continue:item=""
        Set file = root _ item
        If '##class(%File).Exists(file) {
            Write "  skip (not present)  ", item, !
            Continue
        }
        // /force=1: without it Load skips files it thinks are unchanged by
        // timestamp, so restoring a starter over a loaded solution, or
        // recompiling an edit whose file is older than the stored class,
        // silently does nothing and still reports success.
        Set sc = $System.OBJ.Load(file, "ck-d/force=1")
        Write "  ", $Select($$$ISOK(sc): "ok  ", 1: "FAIL"), "  ", item, !
        If $$$ISERR(sc) {
            Set failures = failures + 1
            Do $System.Status.DisplayError(sc)
        }
    }
    Write "  failures: ", failures, !
    Return $$$OK
}

/// Type=18 makes the application an MCP Server; MatchRoles=":%All" is what
/// stops iris-mcp-server's unauthenticated discovery probe getting a bare
/// HTTP 403. Both fail SILENTLY - tools/list just returns the iris_status
/// meta tool - so this must be part of the build, never a runtime step.
ClassMethod RegisterMCP() As %Status
{
    Write !, "--- MCP Server application ---", !
    If '##class(%Dictionary.CompiledClass).%ExistsId("Workshop.MCP.Setup") {
        Write "  SKIP: Workshop.MCP.Setup did not compile", !
        Return $$$OK
    }
    Do ##class(Workshop.MCP.Setup).Run($Namespace)
    Do ##class(Workshop.MCP.Setup).Report()
    Return $$$OK
}

/// The AI.LLM / AI.MCP Config Store descriptors are NOT registered on a
/// fresh instance, and without them Module D.1 fails at the first step with
///   ERROR #26414: No descriptor found for AI.LLM
/// even though %AI.ConfigStore.LLMDescriptor is compiled. One call fixes it;
/// doing it here means D.1 just works in class.
ClassMethod RegisterDescriptors() As %Status
{
    Write !, "--- Config Store descriptor registry ---", !
    Try {
        Set sc = ##class(%ConfigStore.DescriptorManager).GetDescriptorClass("AI", "LLM", "", .dc)
        If $$$ISOK(sc) {
            Write "  already registered: AI.LLM -> ", dc, !
            Return $$$OK
        }
        Set sc = ##class(%ConfigStore.DescriptorManager).RebuildRegistry()
        If $$$ISERR(sc) {
            Write "  WARNING: ", $System.Status.GetErrorText(sc), !
            Return $$$OK
        }
        Do ##class(%ConfigStore.DescriptorManager).GetDescriptorClass("AI", "LLM", "", .dc2)
        Write "  rebuilt: AI.LLM -> ", $Get(dc2), !
    } Catch ex {
        Write "  WARNING: ", ex.DisplayString(), !
    }
    Return $$$OK
}

/// Real Ens_Util.Log rows from minute one, instead of a production that has
/// to be started and broken on purpose.
ClassMethod Seed() As %Status
{
    Write !, "--- demo event log ---", !
    If '##class(%Dictionary.CompiledClass).%ExistsId("Workshop.Demo.Seed") {
        Write "  SKIP: Workshop.Demo.Seed did not compile", !
        Return $$$OK
    }
    Do ##class(Workshop.Demo.Seed).Run()
    Return $$$OK
}

}
