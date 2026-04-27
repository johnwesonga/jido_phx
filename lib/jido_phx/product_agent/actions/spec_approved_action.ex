defmodule JidoPhx.ProductAgent.Actions.SpecApprovedAction do
  @moduledoc """
  Handles `spec.approved` on the CoordinatorAgent.

  Fired by the LiveView when the user clicks Approve on the Tech Spec review.
  Writes both documents to disk and broadcasts the final :complete status.
  """
  use Jido.Action,
    name: "spec_approved",
    schema: []

  alias JidoPhx.PipelineBroadcaster

  @output_dir "priv/static/pipeline_outputs"

  @impl true
  def run(_params, context) do
    %{run_id: run_id, prd: prd, tech_spec: tech_spec} = context.state
    ts = timestamp()

    dir = Path.join(@output_dir, run_id)
    File.mkdir_p!(dir)
    prd_filename = "prd_#{ts}.md"
    tech_spec_filename = "tech_spec_#{ts}.md"

    File.write!(Path.join(dir, prd_filename), prd)
    File.write!(Path.join(dir, tech_spec_filename), tech_spec)

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :complete,
      prd: prd,
      tech_spec: tech_spec,
      prd_filename: "#{run_id}/#{prd_filename}",
      tech_spec_filename: "#{run_id}/#{tech_spec_filename}"
    })

    {:ok, %{status: :complete}}
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.to_iso8601()
    # "2026-04-27T14:32:01"
    |> String.slice(0, 19)
    # "2026-04-27T14-32-01" — safe for filenames
    |> String.replace(":", "-")
  end
end
