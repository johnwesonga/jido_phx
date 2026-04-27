defmodule JidoPhx.ProductAgent.Actions.PrdApprovedAction do
  @moduledoc """
  Handles `prd.approved` on the CoordinatorAgent.

  Fired by the LiveView when the user clicks Approve on the PRD review.
  Spawns the TechnicalLeadAgent child to begin writing the Tech Spec.
  """
  alias JidoPhx.PipelineBroadcaster
  alias JidoPhx.ProductAgent.Agents.TechnicalLeadAgent

  use Jido.Action,
    name: "prd_approved",
    schema: []

  alias Jido.Agent.Directive

  @impl true
  def run(_params, context) do
    run_id = context.state.run_id
    prd = context.state.prd

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :awaiting_spec
    })

    spawn =
      Directive.spawn_agent(
        TechnicalLeadAgent,
        :tl_agent,
        meta: %{prd: prd, run_id: run_id}
      )

    {:ok, %{status: :awaiting_spec}, [spawn]}
  end
end
