defmodule JidoPhx.ProductAgent.Actions.SpecRejectedAction do
  @moduledoc """
  Handles `spec.rejected` on the CoordinatorAgent.

  Fired by the LiveView when the user clicks Reject on the Tech Spec review,
  optionally with written feedback. Re-emits `tl.revise_spec` to the
  existing TL child so it can produce a revised draft.
  """
  use Jido.Action,
    name: "spec_rejected",
    schema: [
      feedback: [type: :string, default: ""],
      tl_pid: [type: :any, required: true]
    ]

  alias Jido.Agent.Directive
  alias JidoPhx.PipelineBroadcaster

  @impl true
  def run(%{feedback: feedback, tl_pid: tl_pid}, context) do
    run_id = context.state.run_id
    tech_spec = context.state.tech_spec

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :awaiting_spec
    })

    signal =
      Jido.Signal.new!(
        "tl.revise_spec",
        %{current_spec: tech_spec, feedback: feedback},
        source: "/coordinator"
      )

    {:ok, %{status: :awaiting_spec}, [Directive.emit_to_pid(signal, tl_pid)]}
  end
end
