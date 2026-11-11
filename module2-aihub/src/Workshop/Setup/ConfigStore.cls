Include (%occStatus)

/// Module D.1 — resources, Wallet collection, secret, and an AI.LLM config.
///
///   do ##class(Workshop.Setup.ConfigStore).Run()        ; build it
///   do ##class(Workshop.Setup.ConfigStore).Show()       ; inspect it
///   do ##class(Workshop.Setup.ConfigStore).RevokeUse()  ; feel the failure
///   do ##class(Workshop.Setup.ConfigStore).GrantUse()   ; put it back
///
/// This one ships COMPLETE and is run, not written. The learning objective is
/// that a config read becomes an RBAC decision — which you feel by revoking
/// the resource, not by typing the setup out.
Class Workshop.Setup.ConfigStore Extends %RegisteredObject
{

// The point of all this: the agent ends up carrying only a NAME.
//   Parameter PROVIDERCONFIG = "@{config:AI.LLM.workshopllm}";
// The @{config:...} macro is required and the separator is a COLON. A bare
// name, a bare dotted name and @{config.name} all fail with
// <%AICore>ProviderConfigError, despite the first two being documented.
// The key lives in the Wallet behind a secret:// reference, and reading it
// is gated by a security resource. No key in source, no key in an env var.
//
// Config Store naming is <Area>.<Type>.<Subtype>.<Name>, created as four
// separate arguments but LOOKED UP as a dotted string. A name containing a
// dot is rejected.

Parameter COLLECTION = "WorkshopWallet";

Parameter SECRETNAME = "LLMKey";

Parameter USERESOURCE = "%Workshop_ConfigUse";

Parameter EDITRESOURCE = "%Workshop_ConfigEdit";

Parameter CONFIGNAME = "workshopllm";

/// Fully qualified Config Store key.
ClassMethod ConfigKey() As %String
{
    Return "AI.LLM." _ ..#CONFIGNAME
}

/// secret://Collection.Secret#field
ClassMethod SecretRef(field As %String = "key") As %String
{
    Return "secret://" _ ..#COLLECTION _ "." _ ..#SECRETNAME _ "#" _ field
}

ClassMethod Run(apiKey As %String = "") As %Status
{
    // Default to whatever the environment already has, so the student does
    // not have to paste a key a second time.
    If apiKey = "" {
        Set p = $ZConvert($ZStrip($System.Util.GetEnviron("AI_PROVIDER"), "<>W"), "L")
        If p = "" Set p = "anthropic"
        Set apiKey = ##class(Workshop.Provider).KeyVariable(p)
        Set apiKey = $System.Util.GetEnviron(apiKey)
        If apiKey = "" Set apiKey = $Get(^||ENV(##class(Workshop.Provider).KeyVariable(p)))
    }
    If apiKey = "" {
        Write "No API key available. Set it in .env, or pass one: ", !
        Write "  do ##class(Workshop.Setup.ConfigStore).Run(""sk-..."")", !
        Return $$$ERROR($$$GeneralError, "no API key to store")
    }

    Write !, "=== Module D.1 — Config Store + Wallet ===", !
    Do ..EnsureDescriptors()
    Do ..CreateResources()
    Do ..CreateCollection()
    Do ..StoreSecret(apiKey)
    Do ..CreateConfig()
    Do ..Show()
    Return $$$OK
}

/// The AI.LLM / AI.MCP descriptors must be REGISTERED before any config of
/// that type can be created. On a fresh instance they are not, and
/// %ConfigStore.Configuration.Create() fails with:
///   ERROR #26432: Configuration validation failed for 'AI.LLM.x':
///   ERROR #26414: No descriptor found for AI.LLM
/// even though %AI.ConfigStore.LLMDescriptor is compiled and present.
/// One call fixes it, and it belongs in the image build.
ClassMethod EnsureDescriptors() As %Status
{
    Write !, "-- descriptor registry --", !
    Set sc = ##class(%ConfigStore.DescriptorManager).GetDescriptorClass("AI", "LLM", "", .dc)
    If $$$ISOK(sc) {
        Write "  already registered: AI.LLM -> ", dc, !
        Return $$$OK
    }
    Write "  AI.LLM not registered; rebuilding...", !
    Set sc = ##class(%ConfigStore.DescriptorManager).RebuildRegistry()
    If $$$ISERR(sc) {
        Write "  FAILED: ", $System.Status.GetErrorText(sc), !
        Return sc
    }
    Do ##class(%ConfigStore.DescriptorManager).GetDescriptorClass("AI", "LLM", "", .dc2)
    Write "  rebuilt: AI.LLM -> ", $Get(dc2), !
    Return $$$OK
}

/// UseResource controls READ access to the secret; EditResource controls
/// write. Splitting them is what lets D.1 step 3 revoke read alone.
ClassMethod CreateResources() As %Status
{
    New $Namespace
    Set $Namespace = "%SYS"
    Write !, "-- security resources --", !
    For res = ..#USERESOURCE, ..#EDITRESOURCE {
        If ##class(Security.Resources).Exists(res) {
            Write "  exists  ", res, !
            Continue
        }
        Set sc = ##class(Security.Resources).Create(res, "AI Hub workshop Config Store resource")
        Write "  ", $Select($$$ISOK(sc): "created", 1: "FAILED "), " ", res, !
        If $$$ISERR(sc) Do $System.Status.DisplayError(sc)
    }
    Return $$$OK
}

ClassMethod CreateCollection() As %Status
{
    Write !, "-- wallet collection --", !
    Set perms = {"UseResource": (..#USERESOURCE), "EditResource": (..#EDITRESOURCE)}
    Try {
        Set sc = ##class(%Wallet.Collection).Create(..#COLLECTION, perms)
        If $$$ISOK(sc) {
            Write "  created  ", ..#COLLECTION, !
        } ElseIf ..IsAlreadyExists(sc) {
            // Re-running the exercise is normal; say so in one line rather
            // than dumping a raw #5805 "ID key not unique" at the student.
            Write "  exists   ", ..#COLLECTION, !
        } Else {
            Write "  FAILED: ", $System.Status.GetErrorText(sc), !
        }
    } Catch ex {
        Write "  FAILED: ", ex.DisplayString(), !
    }
    Return $$$OK
}

/// The Wallet has no method to list its contents — by design. Storing a
/// secret is therefore write-only from the workshop's point of view.
ClassMethod StoreSecret(apiKey As %String) As %Status
{
    Write !, "-- wallet secret --", !
    Set secret = {"Usage": "CUSTOM", "Secret": {"key": (apiKey)}}
    Try {
        Set sc = ##class(%Wallet.KeyValue).Create(..#COLLECTION _ "." _ ..#SECRETNAME, secret)
        If $$$ISOK(sc) {
            Write "  stored   ", ..#COLLECTION, ".", ..#SECRETNAME, " (", $Length(apiKey), " chars, never printed)", !
        } ElseIf ..IsAlreadyExists(sc) {
            Write "  exists   ", ..#COLLECTION, ".", ..#SECRETNAME, " (left as-is)", !
        } Else {
            Write "  FAILED: ", $System.Status.GetErrorText(sc), !
        }
    } Catch ex {
        Write "  FAILED: ", ex.DisplayString(), !
    }
    Return $$$OK
}

/// Note api_key holds a secret:// REFERENCE, not the key itself. That is the
/// whole point: this row is safe to read, back up and inspect.
ClassMethod CreateConfig() As %Status
{
    Write !, "-- config store entry --", !
    Set p = $ZConvert($ZStrip($System.Util.GetEnviron("AI_PROVIDER"), "<>W"), "L")
    If p = "" Set p = "anthropic"
    Set model = $ZStrip($System.Util.GetEnviron("AI_MODEL"), "<>W")
    If model = "" Set model = ##class(Workshop.Provider).DefaultModel(p)

    Set configData = {
        "model_provider": (p),
        "model":          (model),
        "api_key":        (..SecretRef("key"))
    }
    Try {
        Do ##class(%ConfigStore.Configuration).Delete(..ConfigKey())
    } Catch {
        // Not present. Fine.
    }
    Try {
        Set sc = ##class(%ConfigStore.Configuration).Create("AI", "LLM", "", ..#CONFIGNAME, configData)
        If $$$ISOK(sc) {
            Write "  created  ", ..ConfigKey(), !
            Write "           api_key -> ", ..SecretRef("key"), !
        } Else {
            Write "  FAILED: ", $System.Status.GetErrorText(sc), !
        }
    } Catch ex {
        Write "  FAILED: ", ex.DisplayString(), !
    }
    Return $$$OK
}

/// Is this status the harmless "it already exists" case?
/// %Wallet.Collection and %Wallet.KeyValue both report it as #5805
/// "ID key not unique for extent", which is alarming but expected on a
/// second run.
ClassMethod IsAlreadyExists(sc As %Status) As %Boolean
{
    Return $System.Status.GetErrorText(sc) [ "ID key not unique"
}

/// Field names whose values must never be printed.
Parameter SENSITIVE = "api_key,apikey,password,token,secret,bearer_token,client_secret";

/// Redact a config value unless the field name is known-harmless.
ClassMethod Redact(field As %String, value As %String) As %String
{
    Set f = $ZConvert(field, "L")
    For i = 1:1:$Length(..#SENSITIVE, ",") {
        If f = $Piece(..#SENSITIVE, ",", i) {
            If $Extract(value, 1, 9) = "secret://" Return value _ "   (unresolved reference)"
            Return "**** redacted, " _ $Length(value) _ " chars, ends " _ $Extract(value, *-3, *) _ " ****"
        }
    }
    Return value
}

ClassMethod Show() As %Status
{
    Write !, "-- read it back --", !
    Try {
        Set sc = ##class(%ConfigStore.Configuration).Get(..ConfigKey(), .config)
        If $$$ISERR(sc) {
            Write "  Get FAILED: ", $System.Status.GetErrorText(sc), !
            Write "  (if this is a <PROTECT> or privilege error, the Use resource is revoked", !
            Write "   - that is exactly what D.1 step 3 demonstrates)", !
            Return sc
        }
        Write "  Get ok: ", ..ConfigKey(), !
        If $IsObject($Get(config)) {
            Set sc2 = config.CopyDetails(.details)
            If $$$ISOK(sc2), $IsObject($Get(details)) {
                // DO NOT PRINT details.%ToJSON() HERE.
                //
                // CopyDetails() RESOLVES secret:// references and hands back
                // the real credential in plaintext. An earlier version of
                // this method printed the whole object and dumped a live API
                // key to the terminal. On a projector, in front of a room.
                //
                // So: field names always, values only when the field is not
                // sensitive.
                Write "  details (values redacted where sensitive):", !
                Set it = details.%GetIterator()
                While it.%GetNext(.field, .value) {
                    Write "    ", $Justify(field, 16), " = ", ..Redact(field, value), !
                }
            }
            Write "  validates: ", config.ValidateDetails(.err), $Select($Get(err) '= "": " (" _ err _ ")", 1: ""), !
        }
    } Catch ex {
        Write "  FAILED: ", ex.DisplayString(), !
    }
    Return $$$OK
}

/// --- D.1 step 3: make a config read fail -------------------------------
///
/// TWO THINGS THIS DESIGN WORKS AROUND, both learned the hard way:
///
/// 1. %All holds every resource, so revoking one is INVISIBLE to a %All
///    session. The failure can only be seen as a principal without it.
///
/// 2. $SYSTEM.Security.Login into a limited user is a ONE-WAY DOOR. The
///    limited user cannot log back in as _SYSTEM, so the terminal is stuck.
///    Never do it in the student's main session. The read therefore happens
///    in a CHILD PROCESS (JOB), which logs in, reads, records the result in
///    a global and exits. The parent session never changes identity.
///
/// Role names must NOT start with "%" - that prefix is reserved for system
/// roles and Security.Roles.Create rejects it with ERROR #887.
Parameter TESTROLE = "WorkshopConfigReader";

Parameter TESTUSER = "wsreader";

Parameter TESTPASSWORD = "SYS";

/// Where the child process reports back.
Parameter RESULTGLOBAL = "^WorkshopConfigDemo";

/// Baseline privileges the test user needs to get as far as the Config Store
/// at all. %Admin_ConfigStore is a SEPARATE gate from the Wallet's
/// UseResource: without it the read fails with
///   ERROR #790: Operation requires %Admin_ConfigStore:USE
/// before the secret is even considered. Granting it here is what lets the
/// exercise isolate the Wallet resource.
Parameter BASERESOURCES = "%Admin_ConfigStore:U";

ClassMethod CreateTestUser() As %Status
{
    New $Namespace
    Set $Namespace = "%SYS"
    Write !, "-- test role and user --", !

    If '##class(Security.Roles).Exists(..#TESTROLE) {
        Set sc = ##class(Security.Roles).Create(..#TESTROLE, "AI Hub workshop: may read the LLM config", ..#BASERESOURCES _ "," _ ..#USERESOURCE _ ":R")
        Write "  role  ", $Select($$$ISOK(sc): "created", 1: "FAILED "), " ", ..#TESTROLE, !
        If $$$ISERR(sc) Do $System.Status.DisplayError(sc)
    } Else {
        Write "  role  exists  ", ..#TESTROLE, !
    }

    If '##class(Security.Users).Exists(..#TESTUSER) {
        // CLASSROOM ONLY: a fixed password in source, and database resources
        // so the user can reach IRISAPP at all. The exercise is about the
        // CONFIG resource, not database access.
        Set roles = ..#TESTROLE _ ",%DB_IRISAPP_CODE,%DB_IRISAPP_DATA,%DB_IRISSYS"
        Set sc = ##class(Security.Users).Create(..#TESTUSER, roles, ..#TESTPASSWORD, "AI Hub workshop test reader", "IRISAPP")
        Write "  user  ", $Select($$$ISOK(sc): "created", 1: "FAILED "), " ", ..#TESTUSER, !
        If $$$ISERR(sc) Do $System.Status.DisplayError(sc)
    } Else {
        // Repair an existing user's roles rather than assuming they are
        // right - a half-created user from a failed first run is otherwise
        // invisible and the exercise silently reports the wrong failure.
        Set sc = ##class(Security.Users).Get(..#TESTUSER, .uprops)
        If $$$ISOK(sc) {
            Set uprops("Roles") = ..#TESTROLE _ ",%DB_IRISAPP_CODE,%DB_IRISAPP_DATA,%DB_IRISSYS"
            Set sc = ##class(Security.Users).Modify(..#TESTUSER, .uprops)
            Write "  user  exists  ", ..#TESTUSER, " (roles reset: ", $Select($$$ISOK(sc): "ok", 1: $System.Status.GetErrorText(sc)), ")", !
        }
    }
    Do ##class(Security.Users).UnExpireUserPasswords("*")
    Return $$$OK
}

/// NOTE THE PERMISSION: ":R" (READ), not ":U" (USE).
///
/// %Wallet.Collection stores its own permission requirement, and it is
/// READ - inspect it with:
///   write ##class(%Wallet.Collection).%OpenId("WorkshopWallet").UseResource
///   -> %Workshop_ConfigUse:READ
///
/// Granting ":U" instead leaves $SYSTEM.Security.Check(res,"USE") returning
/// 1 while every secret resolution still fails with
///   ERROR #26220: Error using secret ... > ERROR #822: Access Denied
/// which is a thoroughly misleading pair of signals. Check "READ".
ClassMethod GrantUse() As %Status
{
    Return ..SetRoleResources(..#BASERESOURCES _ "," _ ..#USERESOURCE _ ":R", "granted")
}

ClassMethod RevokeUse() As %Status
{
    // Keep %Admin_ConfigStore, drop only the Wallet Use resource, so the
    // failure is attributable to the secret and not to Config Store access.
    Return ..SetRoleResources(..#BASERESOURCES, "revoked")
}

ClassMethod SetRoleResources(resources As %String, verb As %String) As %Status
{
    New $Namespace
    Set $Namespace = "%SYS"
    If '##class(Security.Roles).Exists(..#TESTROLE) {
        Write "Run CreateTestUser() first.", !
        Return $$$ERROR($$$GeneralError, "no test role")
    }
    Set sc = ##class(Security.Roles).Get(..#TESTROLE, .props)
    If $$$ISERR(sc) Return sc
    Set props("Resources") = resources
    Set sc = ##class(Security.Roles).Modify(..#TESTROLE, .props)
    Write "  ", verb, " ", ..#USERESOURCE, " on ", ..#TESTROLE, ": ", $Select($$$ISOK(sc): "ok", 1: $System.Status.GetErrorText(sc)), !
    Return sc
}

/// Runs in a CHILD process. Logs in as the test user, tries the read, and
/// records what happened. Never call this in the student's own session.
ClassMethod ChildRead() As %Status
{
    Set g = ..#RESULTGLOBAL
    Try {
        If '$System.Security.Login(..#TESTUSER, ..#TESTPASSWORD) {
            Set @g@("login") = 0
            Quit
        }
        Set @g@("login")    = 1
        Set @g@("username") = $Username
        Set @g@("roles")    = $Roles
        Set @g@("check")    = $System.Security.Check(..#USERESOURCE, "READ")

        Set sc = ##class(%ConfigStore.Configuration).Get(..ConfigKey(), .config)
        Set @g@("get") = $Select($$$ISOK(sc): "OK", 1: $System.Status.GetErrorText(sc))
        If $$$ISERR(sc) Quit

        // Get() succeeding does not mean the SECRET resolved. CopyDetails()
        // is what dereferences secret://, so that is the real test.
        Set sc2 = config.CopyDetails(.details)
        Set @g@("details") = $Select($$$ISOK(sc2): "OK", 1: $System.Status.GetErrorText(sc2))
        If $$$ISOK(sc2), $IsObject($Get(details)) {
            Set key = details.%Get("api_key")
            Set @g@("apikeyform") = $Select(
                key = "": "empty",
                $Extract(key, 1, 9) = "secret://": "still a secret:// reference (NOT resolved)",
                1: "RESOLVED to a live credential (" _ $Length(key) _ " chars)")
        }
    } Catch ex {
        Set @g@("exception") = $Extract(ex.DisplayString(), 1, 200)
    }
    Quit $$$OK
}

/// Read the config as the test user, in a child process.
ClassMethod ReadAsTestUser() As %String
{
    Set g = ..#RESULTGLOBAL
    Kill @g
    Job ##class(Workshop.Setup.ConfigStore).ChildRead()::10
    If '$Test {
        Write "  could not JOB the child process", !
        Return "jobfailed"
    }
    // Wait for the child to report.
    For i = 1:1:50 {
        Quit:$Data(@g@("get"))||$Data(@g@("exception"))||($Get(@g@("login")) = 0)
        Hang 0.2
    }
    Write "  as ", $Get(@g@("username"), "(no login)"), "  Check(", ..#USERESOURCE, ",READ)=", $Get(@g@("check"), "?"), !
    Write "  Get()         : ", $Get(@g@("get"), "(no result)"), !
    If $Data(@g@("details")) {
        Write "  CopyDetails() : ", $Get(@g@("details")), !
        Write "  api_key       : ", $Get(@g@("apikeyform"), "?"), !
    }
    If $Data(@g@("exception")) Write "  exception     : ", $Get(@g@("exception")), !
    Return $Get(@g@("get"), "")
}

/// The whole of D.1 step 3, in one call. The student's session identity is
/// never changed.
ClassMethod Demo() As %Status
{
    Do ..CreateTestUser()
    Write !, "-- WITH the Use resource --", !
    Do ..GrantUse()
    Do ..ReadAsTestUser()
    Write !, "-- WITHOUT the Use resource --", !
    Do ..RevokeUse()
    Do ..ReadAsTestUser()
    Write !, "-- restoring --", !
    Do ..GrantUse()
    Write !, "Session identity is still: ", $Username, " (unchanged, by design)", !
    Return $$$OK
}

}
