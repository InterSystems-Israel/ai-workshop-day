Include (%AI, %occStatus)

/// Seeds a plausible outage into the interoperability event log so the
/// On-Call Desk agent has real rows to triage.
///
/// Module 0 runs this. It is deliberately a ClassMethod rather than a real
/// failing production: a production that breaks on purpose is slow to start,
/// noisy, and one more thing to go wrong in a 120-minute workshop. Students
/// see a real `Ens_Util.Log` table either way.
///
///   do ##class(Workshop.Demo.Seed).Run()
///   do ##class(Workshop.Demo.Seed).Clear()
Class Workshop.Demo.Seed Extends %RegisteredObject
{

/// Ens.DataType.LogType: 1=Assert 2=Error 3=Warning 4=Info 5=Trace 6=Alert
Parameter TYPEERROR = 2;

Parameter TYPEALERT = 6;

/// Insert one event-log row.
ClassMethod Add(
    configName As %String,
    text As %String,
    type As %Integer = {..#TYPEERROR},
    minutesAgo As %Integer = 0) As %Status
{
    Set row = ##class(Ens.Util.Log).%New()
    Set row.ConfigName = configName
    Set row.Text = text
    Set row.Type = type
    Set row.SourceClass = "Workshop.Demo.Seed"
    Set row.SourceMethod = "Add"
    Set row.Job = $Job
    // $ZTIMESTAMP is UTC in "days,seconds" form, so back-date by borrowing
    // from the day part rather than doing scalar arithmetic on it.
    Set h = $Piece($ZTimeStamp, ",", 1)
    Set s = $Piece($ZTimeStamp, ",", 2) \ 1
    Set s = s - (minutesAgo * 60)
    While s < 0 { Set h = h - 1, s = s + 86400 }
    Set row.TimeLogged = $ZDateTime(h _ "," _ s, 3, 1)
    Return row.%Save()
}

/// Seed a coherent incident: an HL7 router failing to reach a downstream
/// endpoint, plus unrelated noise so grouping actually means something.
ClassMethod Run() As %Status
{
    Write !, "Seeding demo event log...", !
    Do ..Add("HL7Router", "ERROR <Ens>ErrGeneral: Failed to send message to LabOperation: connection refused (10061)", ..#TYPEERROR, 2)
    Do ..Add("HL7Router", "ERROR <Ens>ErrGeneral: Failed to send message to LabOperation: connection refused (10061)", ..#TYPEERROR, 5)
    Do ..Add("HL7Router", "ERROR <Ens>ErrGeneral: Failed to send message to LabOperation: connection refused (10061)", ..#TYPEERROR, 9)
    Do ..Add("LabOperation", "ERROR <Ens>ErrOutConnectExpired: TCP connect timed out after 30s to lab-gw.internal:5000", ..#TYPEERROR, 10)
    Do ..Add("LabOperation", "ERROR <Ens>ErrOutConnectExpired: TCP connect timed out after 30s to lab-gw.internal:5000", ..#TYPEERROR, 14)
    Do ..Add("BillingFeed", "ERROR <Ens>ErrGeneral: Invalid segment terminator in inbound document 88213", ..#TYPEERROR, 40)
    Do ..Add("SchedulingService", "Queue depth exceeded 5000 pending items", ..#TYPEALERT, 7)

    Set count = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM Ens_Util.Log WHERE Type IN (2,6)")
    Do count.%Next()
    Write "  error/alert rows now in Ens_Util.Log: ", count.%Get("N"), !
    Return $$$OK
}

/// Remove only the rows this class created, so re-running is safe.
ClassMethod Clear() As %Status
{
    &sql(DELETE FROM Ens_Util.Log WHERE SourceClass = 'Workshop.Demo.Seed')
    Write "Cleared seeded rows. SQLCODE=", SQLCODE, !
    Return $$$OK
}

}
