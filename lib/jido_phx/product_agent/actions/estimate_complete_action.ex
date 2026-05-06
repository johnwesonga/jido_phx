defmodule JidoPhx.ProductAgent.Actions.EstimateCompleteAction do
  @moduledoc """
  Handles `estimate.complete` on the CoordinatorAgent.

  Writes all three documents to disk, updates the PipelineRun record
  to :complete, and broadcasts the final status to PubSub.
  """
  use Jido.Action,
    name: "estimate_complete",
    schema: [
      estimate: [type: :string, required: true]
    ]

  require Logger

  alias JidoPhx.ProductAgent.{PipelineBroadcaster, PipelineRuns}

  @output_dir "priv/static/pipeline_outputs"

  @impl true
  def run(%{estimate: estimate}, context) do
    %{run_id: run_id, prd: prd, tech_spec: tech_spec} = context.state
    ts = timestamp()

    dir = Path.join(@output_dir, run_id)
    File.mkdir_p!(dir)

    prd_filename = "prd_#{ts}.md"
    tech_spec_filename = "tech_spec_#{ts}.md"
    estimate_filename = "estimate_#{ts}.md"

    File.write!(Path.join(dir, prd_filename), prd)
    File.write!(Path.join(dir, tech_spec_filename), tech_spec)
    File.write!(Path.join(dir, estimate_filename), estimate)

    full_prd_path = "#{run_id}/#{prd_filename}"
    full_spec_path = "#{run_id}/#{tech_spec_filename}"
    full_estimate_path = "#{run_id}/#{estimate_filename}"

    case PipelineRuns.complete(
           run_id,
           prd,
           tech_spec,
           estimate,
           full_prd_path,
           full_spec_path,
           full_estimate_path
         ) do
      {:ok, _} ->
        Logger.info("[EstimateCompleteAction] run #{run_id} marked complete")

      {:error, reason} ->
        Logger.warning(
          "[EstimateCompleteAction] failed to update run #{run_id}: #{inspect(reason)}"
        )
    end

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :complete,
      prd: prd,
      tech_spec: tech_spec,
      estimate: estimate,
      prd_filename: full_prd_path,
      tech_spec_filename: full_spec_path,
      estimate_filename: full_estimate_path
    })

    {:ok, %{estimate: estimate, status: :complete}}
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.to_iso8601()
    |> String.slice(0, 19)
    |> String.replace(":", "-")
  end
end
