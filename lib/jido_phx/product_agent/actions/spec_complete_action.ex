defmodule JidoPhx.ProductAgent.Actions.SpecCompleteAction do
  @moduledoc """
  Handles the `spec.complete` signal on the CoordinatorAgent.

  Emitted by the TechnicalLeadAgent when the Tech Spec is ready.
  Stores the spec in coordinator state and marks the pipeline as complete.
  """
  use Jido.Action,
    name: "spec_complete",
    schema: [
      tech_spec: [type: :string, required: true],
      run_id: [type: :string, required: true]
    ]

  @output_dir "priv/static/pipeline_outputs"

  alias JidoPhx.ProductAgent.PipelineBroadcaster

  @impl true
  def run(%{tech_spec: tech_spec, run_id: run_id}, context) do
    prd = context.state.prd

    # Write documents to disk
    dir = Path.join(@output_dir, run_id)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "prd.md"), prd)
    File.write!(Path.join(dir, "tech_spec.md"), tech_spec)

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :complete,
      prd: prd,
      tech_spec: tech_spec
    })

    {:ok, %{tech_spec: tech_spec, status: :complete}}
  end
end
