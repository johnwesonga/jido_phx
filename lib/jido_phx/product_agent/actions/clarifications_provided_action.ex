defmodule JidoPhx.ProductAgent.Actions.ClarificationsProvidedAction do
  @moduledoc """
  Handles `pipeline.clarifications_provided` on the CoordinatorAgent.

  Receives the user's answers (a map of question → answer), appends
  them to the running Q&A history, then re-emits `pm.analyze_requirements`
  so the PM agent can decide whether more questions are needed or whether
  it has enough to write the PRD.

  The PM agent's `AnalyzeRequirementsAction` receives the full qa_history
  so it can generate targeted follow-ups or, once satisfied, emit
  `pm.generate_prd` instead.
  """
  alias JidoPhx.ProductAgent.{PipelineBroadcaster, Actions.PersistStatus}

  use Jido.Action,
    name: "clarifications_provided",
    schema: [
      answers: [type: :any, required: true],
      pm_pid: [type: :any, required: true]
    ]

  alias Jido.Agent.Directive

  @impl true
  def run(%{answers: answers, pm_pid: pm_pid}, context) do
    %{
      run_id: run_id,
      requirements: requirements,
      questions: questions,
      past_context: past_context
    } = context.state

    # Build a human-readable Q&A block to append to history
    new_qa_block =
      questions
      |> Enum.map(fn q ->
        answer = Map.get(answers, q, "(no answer provided)")
        "Q: #{q}\nA: #{answer}"
      end)
      |> Enum.join("\n\n")

    # Append to running history
    qa_history =
      case context.state[:qa_history] do
        nil -> new_qa_block
        existing -> existing <> "\n\n---\n\n" <> new_qa_block
      end

    PersistStatus.call(run_id, :awaiting_prd)

    PipelineBroadcaster.broadcast(run_id, %{
      run_id: run_id,
      status: :awaiting_prd
    })

    # Re-send to PM agent for another round of analysis or PRD generation
    signal =
      Jido.Signal.new!(
        "pm.analyze_requirements",
        # ← thread through
        %{
          requirements: requirements,
          qa_history: qa_history,
          past_context: past_context,
          round: 1
        },
        source: "/coordinator"
      )

    {:ok, %{qa_history: qa_history, status: :awaiting_prd},
     [Directive.emit_to_pid(signal, pm_pid)]}
  end
end
