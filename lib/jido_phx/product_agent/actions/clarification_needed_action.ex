defmodule JidoPhx.ProductAgent.Actions.ClarificationNeededAction do
  @moduledoc """
  Handles `requirements.clarification_needed` on the CoordinatorAgent.

  Stores the questions in coordinator state and broadcasts to PubSub
  so the LiveView can render the Q&A form. The pipeline pauses here
  until the user submits answers via `pipeline.clarifications_provided`.
  """
  alias JidoPhx.PipelineBroadcaster

  use Jido.Action,
    name: "clarification_needed",
    schema: [
      questions: [type: {:list, :string}, required: true]
    ]

  alias JidoPhx.PipelineBroadcaster

  @impl true
  def run(%{questions: questions}, context) do
    run_id = context.state.run_id

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :awaiting_clarification,
      questions: questions
    })

    {:ok, %{questions: questions, status: :awaiting_clarification}}
  end
end
