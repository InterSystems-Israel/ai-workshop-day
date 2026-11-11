Include (%AI, %occStatus)

/// Registers the /mcp/oncall MCP Server application.
Class Workshop.MCP.Setup Extends %RegisteredObject
{

// Type=18 is what makes a Security.Applications entry an MCP Server rather
// than a web or privileged-routine application. Without it the app is
// created but iris-mcp-server will not find it.
//
// CLASSROOM SHORTCUT: AutheEnabled=64 is unauthenticated access, paired with
// allow_anonymous=true in config_http.toml. In production use Password (32)
// or OAuth 2.0 and give iris-mcp-server real credentials.

Parameter APPNAME = "/mcp/oncall";

Parameter DISPATCHCLASS = "Workshop.MCP.Service";

/// 96 = 64 (unauthenticated) + 32 (password), and BOTH bits are required.
///
/// With 64 alone the MCP listener starts fine and tools/list returns only the
/// meta tool, because iris-mcp-server's discovery probe
///   GET /mcp/oncall/v1/services
/// comes back HTTP 403 Forbidden with an empty body. The failure is visible
/// only by calling the iris_status meta tool or reading the bridge log - the
/// MCP client just sees an endpoint with no tools.
Parameter AUTHEENABLED = 96;

ClassMethod Run(namespace As %String = {$Namespace}) As %Status
{
    New $Namespace
    Set $Namespace = "%SYS"

    If ##class(Security.Applications).Exists(..#APPNAME) {
        Write "MCP Server ", ..#APPNAME, " already exists - deleting first.", !
        Do ##class(Security.Applications).Delete(..#APPNAME)
    }

    Kill props
    Set props("NameSpace")     = namespace
    Set props("DispatchClass") = ..#DISPATCHCLASS
    Set props("Enabled")       = 1
    Set props("Type")          = 18
    Set props("AutheEnabled")  = ..#AUTHEENABLED
    // CLASSROOM SHORTCUT: grant every role to requests on this application.
    // Needed because iris-mcp-server's discovery probe arrives UNAUTHENTICATED
    // (the bridge logs auth_key=Anonymous), so it runs as UnknownUser, which
    // has no privilege on the namespace and gets a bare HTTP 403.
    // In production: authenticate the bridge and grant a single purpose-made
    // role with only the resources the ToolSet actually reads.
    Set props("MatchRoles")    = ":%All"
    Set props("Description")   = "AI Hub workshop - On-Call Desk tools over MCP"

    Set sc = ##class(Security.Applications).Create(..#APPNAME, .props)
    If $$$ISERR(sc) {
        Write "FAILED: ", $System.Status.GetErrorText(sc), !
        Return sc
    }
    Write "Created MCP Server ", ..#APPNAME, " -> ", ..#DISPATCHCLASS, " in ", namespace, !
    Return $$$OK
}

/// Show what was registered, as the Management Portal would.
ClassMethod Report()
{
    New $Namespace
    Set $Namespace = "%SYS"
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name, Type, Enabled, AutheEnabled, NameSpace, DispatchClass FROM Security.Applications WHERE Type = 18")
    Write "MCP Server applications (Type=18):", !
    Set n = 0
    While rs.%Next() {
        Set n = n + 1
        Write "  ", rs.%Get("Name"), "  ns=", rs.%Get("NameSpace"), "  dispatch=", rs.%Get("DispatchClass"), "  authe=", rs.%Get("AutheEnabled"), "  enabled=", rs.%Get("Enabled"), !
    }
    If n = 0 Write "  (none)", !
}

}
