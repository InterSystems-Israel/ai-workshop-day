Include (%occStatus)

/// The On-Call Desk production.
Class Workshop.Interop.Production Extends Ens.Production
{

// Four items, and the shape is the lesson:
//
//   TriageIn        service    - entry point
//   TriageDecision  process    - decides, and escalates
//   OnCallAgent     operation  - HOSTS THE AGENT, like any other operation
//   OnCallApprovers operation  - EnsLib.Workflow.Operation, the human queue
//                                (its NAME is the workflow role name)
//
// Nothing here is AI-specific except the class name of one operation. That
// is the entire point of Module D.3.

XData ProductionDefinition
{
<Production Name="Workshop.Interop.Production" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description>AI Hub workshop - the Integration On-Call Desk</Description>
  <ActorPoolSize>2</ActorPoolSize>

  <Item Name="TriageIn" Category="OnCall" ClassName="Workshop.Interop.TriageService" PoolSize="0" Enabled="true" Foreground="false" InactivityTimeout="0" Schedule="">
    <Setting Target="Host" Name="TargetConfigName">TriageDecision</Setting>
  </Item>

  <Item Name="TriageDecision" Category="OnCall" ClassName="Workshop.Interop.DecisionProcess" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Schedule="">
    <Setting Target="Host" Name="AgentTarget">OnCallAgent</Setting>
    <Setting Target="Host" Name="WorkflowTarget">OnCallApprovers</Setting>
  </Item>

  <Item Name="OnCallAgent" Category="OnCall" ClassName="Workshop.Interop.AgentOperation" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Schedule="">
    <Setting Target="Host" Name="ResponseTimeout">30</Setting>
  </Item>

  <!-- The native Workflow Engine as the human review queue.
       THE ITEM NAME IS THE WORKFLOW ROLE NAME. That is the convention, and
       it is not obvious: AutoCreateRole creates a role called exactly this,
       and every task raised here gets %RoleName="OnCallApprovers". Name it
       "ApprovalDesk" and your approvers must be in a role called
       "ApprovalDesk" - otherwise tasks are created but cannot be delivered,
       and the only clue is
         ERROR <EnsWf>ErrNoUsersFound: No Users found to assign Task to
       in the event log. -->
  <Item Name="OnCallApprovers" Category="OnCall" ClassName="EnsLib.Workflow.Operation" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Schedule="">
    <Setting Target="Host" Name="AutoCreateRole">1</Setting>
  </Item>

</Production>
}

}
