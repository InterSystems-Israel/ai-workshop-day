Include (%occStatus)

/// Moves your namespace between exercise states: back to the student start,
/// or forward to a known-good solution.
///
///   do ##class(Workshop.Lab).Status()            // where am I?
///   do ##class(Workshop.Lab).Reset()             // back to the very beginning
///   do ##class(Workshop.Lab).Solve("C.1")         // load one solution
///   do ##class(Workshop.Lab).SolveThrough("C.3")  // catch up to the start of C.4
///
/// USE SolveThrough WHEN YOU ARE STUCK. Later exercises build on earlier ones,
/// so if you want to skip C1 and still do C4, you need C1's solution in place
/// first. SolveThrough does that in dependency order.
Class Workshop.Lab Extends %RegisteredObject
{

// WHERE THE FILES LIVE, and why it is not in your source tree:
//
//   /opt/workshop/starters/   pristine copies of every starter class
//   /opt/workshop/solutions/  one folder per exercise
//
// Both are baked into the IMAGE and are NOT bind-mounted, so they survive you
// editing src/, and `docker compose down` cannot lose them. Keeping the
// solutions out of the mounted tree also means a coding assistant pointed at
// your repo folder will not read the answers and quietly do the exercise for
// you, which is what the exercise is for.

Parameter STARTERROOT = "/opt/workshop/starters/Workshop/";

Parameter SOLUTIONROOT = "/opt/workshop/solutions/";

/// Exercises in DEPENDENCY ORDER. Fields:
///   id ^ class ^ solution folder ^ marker ^ description ^ optional setup
///
/// IDS MATCH THE WORKBOOK EXACTLY. A student who is stuck at step C.3 types
/// SolveThrough("C.3"), so that is what the ids are. IndexOf() ignores dots,
/// so "C3" works too.
///
/// Several exercises edit the SAME class and supersede each other:
///   Workshop.Agent.OnCall  A.1 -> A.4 -> D.1.2
///   Workshop.Tools.OnCall  B.1.2 -> B.2.2
/// so SolveThrough applying them in order is correct, not wasteful.
///
/// The `setup` field names a classmethod to run BEFORE loading the solution.
/// D.1.2 needs it: that class carries Parameter PROVIDERCONFIG, and %Init()
/// fails outright if the Config Store entry does not exist yet.
Parameter EXERCISES = "A.1^Workshop.Agent.OnCall^A1-instructions^TODO (Exercise A.1)^Write the XData INSTRUCTIONS triage brief;A.4^Workshop.Agent.OnCall^A4-templating^{{siteName}}^Add {{siteName}} templating to the instructions;B.1.2^Workshop.Tools.OnCall^B1-descriptions^TODO (Exercise B.1.2)^Document DraftIncidentNote's arguments;B.2.2^Workshop.Tools.OnCall^B22-nested-mcp^<MCP Name^Attach the Python MCP server as a nested ToolSet;C.1^Workshop.Tools.Worklist^C1-stateful^TODO (Exercise C.1a)^Convert the worklist to instance Methods;C.3^Workshop.Policy.ApprovalGate^C4-approvalgate^TODO (Exercise C.3)^Gate RestartHost on a persisted approval row;D.1.2^Workshop.Agent.OnCall^D12-providerconfig^PROVIDERCONFIG^Point the agent at the Config Store^Workshop.Setup.ConfigStore;D.2.1^Workshop.Policy.AuditLog^D2-audit^TODO (Exercise D.2.1)^Write %LogExecution";

Parameter INVERTEDMARKERS = "A.4,B.2.2,D.1.2";

ClassMethod Count() As %Integer
{
    Return $Length(..#EXERCISES, ";")
}

ClassMethod Row(n As %Integer) As %String
{
    Return $Piece(..#EXERCISES, ";", n)
}

/// Index of an exercise id, or 0.
/// Index of an exercise id, or 0. Dots are ignored, so "C.3" and "C3" both
/// find C.3 - students type both, and being pedantic about it would only
/// produce "unknown exercise" for a correct answer.
ClassMethod IndexOf(id As %String) As %Integer
{
    Set id = $ZConvert($Replace($ZStrip(id, "<>W"), ".", ""), "U")
    For i = 1:1:..Count() {
        If $ZConvert($Replace($Piece(..Row(i), "^", 1), ".", ""), "U") = id Return i
    }
    Return 0
}

/// The ordered exercise list.
ClassMethod List()
{
    Write !, "Exercises, in dependency order:", !, !
    For i = 1:1:..Count() {
        Set r = ..Row(i)
        Write "  ", $Justify($Piece(r, "^", 1), 5), "  ", $Justify($Piece(r, "^", 2), 30), "  ", $Piece(r, "^", 5), !
    }
    Write !, "  do ##class(Workshop.Lab).SolveThrough(""C.1"")  loads A.1, A.4, B.1.2, B.2.2 and C.1", !
}

/// Is this exercise currently solved in the live namespace?
/// Returns 1 solved, 0 starter, -1 the class is not compiled at all.
ClassMethod IsSolved(id As %String) As %Integer
{
    Set n = ..IndexOf(id)
    If 'n Return -1
    Set r = ..Row(n)
    Set cls = $Piece(r, "^", 2), marker = $Piece(r, "^", 4)
    If '##class(%Dictionary.CompiledClass).%ExistsId(cls) Return -1

    Set sc = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, cls, .txt)
    If $$$ISERR(sc) Return -1

    Set present = ($Get(txt) [ marker)
    // Most markers are TODO comments: present means NOT yet solved. A few are
    // the other way round (A4's {{siteName}} appears only once solved).
    If ..IsInverted(id) Return present
    Return 'present
}

/// Dot-insensitive, for the same reason IndexOf() is: the ids carry dots and
/// a mismatch here silently inverts the test, reporting every unsolved
/// inverted exercise as SOLVED.
ClassMethod IsInverted(id As %String) As %Boolean
{
    Set id = $ZConvert($Replace(id, ".", ""), "U")
    For i = 1:1:$Length(..#INVERTEDMARKERS, ",") {
        If $ZConvert($Replace($Piece(..#INVERTEDMARKERS, ",", i), ".", ""), "U") = id Return 1
    }
    Return 0
}

/// Where am I?
ClassMethod Status()
{
    Write !, "=================================================================", !
    Write "  Workshop lab state  (namespace ", $Namespace, ")", !
    Write "=================================================================", !
    Set solved = 0
    For i = 1:1:..Count() {
        Set r = ..Row(i)
        Set id = $Piece(r, "^", 1)
        Set st = ..IsSolved(id)
        Set word = $Case(st, 1: "SOLVED ", 0: "starter", : "MISSING")
        If st = 1 Set solved = solved + 1
        Write "  ", $Justify(id, 5), "  ", word, "   ", $Piece(r, "^", 5), !
    }
    Write "-----------------------------------------------------------------", !
    Write "  ", solved, " of ", ..Count(), " solved", !
    Write !, "  Reset()            everything back to the student start", !
    Write "  Solve(""C.3"")        load one solution", !
    Write "  SolveThrough(""C.3"") load every solution up to and including C.3", !
    Write "=================================================================", !
}

/// Run an exercise's prerequisite setup, if it declares one. Idempotent by
/// design: the setup classmethods are safe to re-run.
ClassMethod RunSetup(row As %String) As %Status
{
    Set cls = $Piece(row, "^", 6)
    If cls = "" Return $$$OK
    If '##class(%Dictionary.CompiledClass).%ExistsId(cls) {
        Write "  SKIP     prerequisite ", cls, " is not compiled", !
        Return $$$OK
    }
    Write "  prereq   ", cls, ".Run()", !
    Return $classmethod(cls, "Run")
}

/// Load one .cls file, reporting what happened.
ClassMethod LoadOne(file As %String, label As %String) As %Status
{
    If '##class(%File).Exists(file) {
        Write "  MISSING  ", label, "  (", file, ")", !
        Return $$$ERROR($$$GeneralError, "no such file: " _ file)
    }
    // /force=1 IS LOAD-BEARING. Without it $System.OBJ.Load compares the
    // file's timestamp against the stored class and SKIPS the import when it
    // thinks nothing changed - reporting success either way. The starter
    // files carry the image's build time, so once a solution has been loaded
    // the starter looks "older" and Reset() silently restores nothing.
    Set sc = $System.OBJ.Load(file, "ck-d/force=1")
    Write "  ", $Select($$$ISOK(sc): "ok      ", 1: "FAILED  "), label, !
    If $$$ISERR(sc) Do $System.Status.DisplayError(sc)
    Return sc
}

/// Load the solution for one exercise.
///
/// This REPLACES the class in your namespace. Your own edits to that class
/// are overwritten in IRIS — though the file in src/ on your host is
/// untouched, so nothing you typed is actually lost.
ClassMethod Solve(id As %String) As %Status
{
    Set n = ..IndexOf(id)
    If 'n {
        Write "No exercise called '", id, "'. Try: do ##class(Workshop.Lab).List()", !
        Return $$$ERROR($$$GeneralError, "unknown exercise")
    }
    Set r = ..Row(n)
    Set cls = $Piece(r, "^", 2), folder = $Piece(r, "^", 3)
    Set file = ..#SOLUTIONROOT _ folder _ "/" _ cls _ ".cls"
    Write !, "Loading the ", $Piece(r, "^", 1), " solution — ", $Piece(r, "^", 5), !
    Do ..RunSetup(r)
    Return ..LoadOne(file, cls)
}

/// Load every solution in dependency order, up to and including `id`.
/// This is the one to use when you are behind and want to start the next
/// exercise from a known-good base.
ClassMethod SolveThrough(id As %String) As %Status
{
    Set n = ..IndexOf(id)
    If 'n {
        Write "No exercise called '", id, "'. Try: do ##class(Workshop.Lab).List()", !
        Return $$$ERROR($$$GeneralError, "unknown exercise")
    }
    Write !, "Catching up to the end of ", $ZConvert(id, "U"), " — loading ", n, " solution(s) in order:", !
    For i = 1:1:n {
        Set r = ..Row(i)
        Set cls = $Piece(r, "^", 2), folder = $Piece(r, "^", 3)
        Do ..RunSetup(r)
        Do ..LoadOne(..#SOLUTIONROOT _ folder _ "/" _ cls _ ".cls", $Justify($Piece(r, "^", 1), 5) _ "  " _ cls)
    }
    Do ..Status()
    Return $$$OK
}

/// Back to the state a student starts the workshop in.
///
/// With no argument: every class, plus the exercise data (approvals and audit
/// cleared, demo event log reseeded). With an exercise id: just that class.
ClassMethod Reset(id As %String = "", data As %Boolean = 1) As %Status
{
    If id '= "" {
        Set n = ..IndexOf(id)
        If 'n {
            Write "No exercise called '", id, "'.", !
            Return $$$ERROR($$$GeneralError, "unknown exercise")
        }
        Set r = ..Row(n)
        Set cls = $Piece(r, "^", 2)
        Set rel = $Replace($Piece(cls, ".", 2, *), ".", "/") _ ".cls"
        Write !, "Resetting ", cls, " to its starter state", !
        Return ..LoadOne(..#STARTERROOT _ rel, cls)
    }

    Write !, "=== resetting to the student start state ===", !
    If '##class(%File).DirectoryExists(..#STARTERROOT) {
        Write "  The pristine starters are missing from this image (", ..#STARTERROOT, ").", !
        Write "  Rebuild it: docker compose build iris", !
        Return $$$ERROR($$$GeneralError, "no starters in image")
    }

    // Reuse the build's dependency order - policies before ToolSets, or a
    // ToolSet naming a policy fails to compile.
    Do ##class(Workshop.Setup.Build).CompileWorkshop(..#STARTERROOT)

    If data {
        Write !, "--- exercise data ---", !
        If ##class(%Dictionary.CompiledClass).%ExistsId("Workshop.Data.Approval") {
            Do ##class(Workshop.Data.Approval).Reset()
        }
        If ##class(%Dictionary.CompiledClass).%ExistsId("Workshop.Data.AuditEntry") {
            Do ##class(Workshop.Data.AuditEntry).Reset()
        }
        If ##class(%Dictionary.CompiledClass).%ExistsId("Workshop.Demo.Seed") {
            Do ##class(Workshop.Demo.Seed).Clear()
            Do ##class(Workshop.Demo.Seed).Run()
        }
    }
    Do ..Status()
    Return $$$OK
}

/// Everything solved. Useful for seeing the finished state of all six
/// exercises at once, or for getting back on your feet after a bad detour.
ClassMethod SolveAll() As %Status
{
    Return ..SolveThrough($Piece(..Row(..Count()), "^", 1))
}

}
