defmodule JidoPhx.ProductAgent.Actions.StartPipelineAction do
  @moduledoc """
  Handles `pipeline.start` on the CoordinatorAgent.

  Creates a PipelineRun record then spawns the PM child.
  """
  use Jido.Action,
    name: "start_pipeline",
    schema: [
      requirements: [type: :string, required: true],
      run_id: [type: :string, required: true]
    ]

  require Logger

  alias Jido.Agent.Directive
  alias JidoPhx.ProductAgent.{PipelineBroadcaster, PipelineRuns, MemoryStore}

  @impl true
  def run(%{requirements: requirements, run_id: run_id}, _context) do
    case PipelineRuns.create(run_id, requirements) do
      {:ok, _} ->
        Logger.info("[StartPipelineAction] created run #{run_id}")

      {:error, reason} ->
        Logger.warning(
          "[StartPipelineAction] failed to persist run #{run_id}: #{inspect(reason)}"
        )
    end

    # Query memory for similar past runs (non-blocking — returns [] on failure)
    past_runs = MemoryStore.recall(run_id, requirements)
    past_context = MemoryStore.format_context(past_runs)

    if past_context do
      Logger.info(
        "[StartPipelineAction] found #{length(past_runs)} similar past run(s) for context"
      )
    end

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :awaiting_clarification
    })

    spawn =
      Directive.spawn_agent(
        JidoPhx.ProductAgent.Agents.ProductManagerAgent,
        :pm_agent,
        meta: %{requirements: requirements, run_id: run_id}
      )

    {:ok,
     %{
       requirements: requirements,
       run_id: run_id,
       past_context: past_context,
       status: :awaiting_clarification,
       qa_history: nil,
       questions: []
     }, [spawn]}
  end
end
