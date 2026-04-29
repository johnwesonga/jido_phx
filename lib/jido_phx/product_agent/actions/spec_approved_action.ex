defmodule JidoPhx.ProductAgent.Actions.SpecApprovedAction do
  @moduledoc """
  Handles `spec.approved` on the CoordinatorAgent.

  Fired by the LiveView when the user clicks Approve on the Tech Spec review.
  Writes both documents to disk and broadcasts the final :complete status.
  """
  use Jido.Action,
    name: "spec_approved",
    schema: []

  alias JidoPhx.ProductAgent.PipelineBroadcaster
  alias Jido.Agent.Directive

  @impl true
  def run(_params, context) do
    %{run_id: run_id, tech_spec: tech_spec} = context.state

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :awaiting_estimate
    })

    spawn =
      Directive.spawn_agent(
        JidoPhx.ProductAgent.Agents.EstimatorAgent,
        :estimator_agent,
        meta: %{tech_spec: tech_spec, run_id: run_id}
      )

    {:ok, %{status: :awaiting_estimate}, [spawn]}
  end
end
