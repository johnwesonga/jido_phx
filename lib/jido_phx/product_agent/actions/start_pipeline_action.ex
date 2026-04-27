defmodule JidoPhx.ProductAgent.Actions.StartPipelineAction do
  @moduledoc """
  Handles the `pipeline.start` signal on the CoordinatorAgent.

  Records the user requirements in state and spawns a ProductManagerAgent
  child. The child's PID will arrive via `jido.agent.child.started` once
  the runtime has started it.
  """
  use Jido.Action,
    name: "start_pipeline",
    schema: [
      requirements: [type: :string, required: true],
      run_id: [type: :string, required: true]
    ]

  require Logger

  alias Jido.Agent.Directive
  alias JidoPhx.ProductAgent.Agents.ProductManagerAgent

  @impl true
  def run(%{requirements: requirements, run_id: run_id}, _context) do
    Logger.info("[StartPipelineAction]requirements #{requirements}")

    spawn =
      Directive.spawn_agent(
        ProductManagerAgent,
        :pm_agent,
        meta: %{requirements: requirements, run_id: run_id}
      )

    {:ok, %{requirements: requirements, run_id: run_id, status: :awaiting_prd}, [spawn]}
  end
end
