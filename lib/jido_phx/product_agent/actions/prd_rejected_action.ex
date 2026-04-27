defmodule JidoPhx.ProductAgent.Actions.PrdRejectedAction do
  @moduledoc """
  Handles `prd.rejected` on the CoordinatorAgent.

  Fired by the LiveView when the user clicks Reject on the PRD review,
  optionally with written feedback. Re-emits `pm.revise_prd` to the
  existing PM child so it can produce a revised draft.
  """
  use Jido.Action,
    name: "prd_rejected",
    schema: [
      feedback: [type: :string, default: ""],
      pm_pid: [type: :any, required: true]
    ]

  alias Jido.Agent.Directive
  alias JidoPhx.PipelineBroadcaster

  @impl true
  def run(%{feedback: feedback, pm_pid: pm_pid}, context) do
    run_id = context.state.run_id
    prd = context.state.prd

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :awaiting_prd
    })

    signal =
      Jido.Signal.new!(
        "pm.revise_prd",
        %{current_prd: prd, feedback: feedback},
        source: "/coordinator"
      )

    {:ok, %{status: :awaiting_prd}, [Directive.emit_to_pid(signal, pm_pid)]}
  end
end
