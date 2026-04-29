defmodule JidoPhx.ProductAgent.Actions.SpecReviewRequestedAction do
  @moduledoc """
  Handles `spec.review_requested` on the CoordinatorAgent.

  Emitted by GenerateSpecAction when the LLM has produced a Tech Spec draft.
  Stores the draft and broadcasts to PubSub so the LiveView can render
  the review UI. The pipeline pauses until the user approves or rejects.
  """
  alias JidoPhx.ProductAgent.PipelineBroadcaster
  alias JidoPhx.ProductAgent.Actions.PersistStatus

  use Jido.Action,
    name: "spec_review_requested",
    schema: [
      tech_spec: [type: :string, required: true]
    ]

  @impl true
  def run(%{tech_spec: tech_spec}, context) do
    run_id = context.state.run_id
    PersistStatus.call(run_id, :awaiting_spec_review)

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :awaiting_spec_review,
      tech_spec: tech_spec
    })

    {:ok, %{tech_spec: tech_spec, status: :awaiting_spec_review}}
  end
end
