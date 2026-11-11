Include (%occStatus)

/// Asks the on-call desk to triage a business host.
Class Workshop.Interop.TriageRequest Extends Ens.Request
{

/// Business host that is failing, e.g. "HL7Router". Empty means "look at
/// everything".
Property ConfigName As %String(MAXLEN = 128);

/// Free-text context from whatever noticed the problem.
Property Context As %String(MAXLEN = 1000);

}
