Include (%occStatus)

/// Entry point into the on-call production.
Class Workshop.Interop.TriageService Extends Ens.BusinessService
{

// Adapter-less on purpose. A file or REST inbound adapter would be more
// realistic and would also be one more thing to go wrong in a 3-minute
// demo. Students trigger it from the terminal:
//
//   do ##class(Workshop.Interop.Setup).Trigger("HL7Router")
//
// which is enough to make the Visual Trace light up.

Parameter ADAPTER = "Ens.InboundAdapter";

Property TargetConfigName As %String [ InitialExpression = "TriageDecision" ];

Parameter SETTINGS = "TargetConfigName:Basic";

Method OnProcessInput(pInput As Workshop.Interop.TriageRequest, Output pOutput As %RegisteredObject) As %Status
{
    Return ..SendRequestSync(..TargetConfigName, pInput, .pOutput)
}

}
