defmodule JidoPhx.ProductAgent.Actions.EstimateCompleteAction do
  @moduledoc """
  Handles `estimate.complete` on the CoordinatorAgent.

  Writes all three documents to disk and broadcasts :complete to PubSub.
  This is the terminal action in the pipeline.
  """
  use Jido.Action,
    name: "estimate_complete",
    schema: [
      estimate: [type: :string, required: true]
    ]

  @output_dir "priv/static/pipeline_outputs"

  alias JidoPhx.PipelineBroadcaster

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

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :complete,
      prd: prd,
      tech_spec: tech_spec,
      estimate: estimate,
      prd_filename: "#{run_id}/#{prd_filename}",
      tech_spec_filename: "#{run_id}/#{tech_spec_filename}",
      estimate_filename: "#{run_id}/#{estimate_filename}"
    })

    {:ok, %{estimate: estimate, estimate_filename: estimate_filename, status: :complete}}
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.to_iso8601()
    |> String.slice(0, 19)
    |> String.replace(":", "-")
  end
end
