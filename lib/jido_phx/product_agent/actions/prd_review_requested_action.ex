defmodule JidoPhx.ProductAgent.Actions.PrdReviewRequestedAction do
  @moduledoc """
  Handles `prd.review_requested` on the CoordinatorAgent.

  Emitted by GeneratePrdAction when the LLM has produced a PRD draft.
  Stores the draft and broadcasts to PubSub so the LiveView can render
  the review UI. The pipeline pauses here until the user approves or rejects.
  """
  alias JidoPhx.PipelineBroadcaster

  use Jido.Action,
    name: "prd_review_requested",
    schema: [
      prd: [type: :string, required: true]
    ]

  @impl true
  def run(%{prd: prd}, context) do
    run_id = context.state.run_id

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :awaiting_prd_review,
      prd: prd
    })

    {:ok, %{prd: prd, status: :awaiting_prd_review}}
  end
end
