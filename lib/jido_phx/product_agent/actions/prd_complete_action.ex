defmodule JidoPhx.ProductAgent.Actions.PrdCompleteAction do
  @moduledoc """
  Handles the `prd.complete` signal on the CoordinatorAgent.

  Emitted by the ProductManagerAgent when it has finished writing the PRD.
  This action stores the PRD in coordinator state and spawns a
  TechnicalLeadAgent child, passing the PRD via `meta`.
  """
  alias JidoPhx.PipelineBroadcaster

  use Jido.Action,
    name: "prd_complete",
    schema: [
      prd: [type: :string, required: true],
      run_id: [type: :string, required: true]
    ]

  alias Jido.Agent.Directive

  @impl true
  def run(%{prd: prd}, context) do
    run_id = context.state.run_id

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :awaiting_spec,
      prd: prd,
      tech_spec: nil
    })

    spawn =
      Directive.spawn_agent(
        JidoPhx.ProductAgent.Agents.TechnicalLeadAgent,
        :tl_agent,
        meta: %{prd: prd, run_id: run_id}
      )

    {:ok, %{prd: prd, status: :awaiting_spec}, [spawn]}
  end
end
