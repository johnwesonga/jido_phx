defmodule JidoPhx.ProductAgent.Actions.AnalyzeRequirementsAction do
  @moduledoc """
  Handles `pm.analyze_requirements` on the ProductManagerAgent.

  Always asks clarifying questions before writing the PRD. The LLM
  analyses the requirements + any Q&A history and decides:

  - If more clarification is needed → emits `requirements.clarification_needed`
    with a JSON list of questions.
  - If enough information exists → emits `pm.generate_prd` directly so the
    flow proceeds to PRD generation without another round of questions.

  This is the mechanism that allows multi-round follow-up: after each answer
  round, `ClarificationsProvidedAction` re-emits `pm.analyze_requirements`,
  and this action decides whether to ask again or proceed.
  """

  use Jido.Action,
    name: "analyze_requirements",
    schema: [
      requirements: [type: :string, required: true],
      qa_history: [type: {:or, [:string, nil]}, default: nil]
    ]

  alias Jido.Agent.Directive

  @system_prompt """
  You are a senior Product Manager conducting a requirements discovery session.

  You will receive product requirements and optionally a Q&A history from
  previous clarification rounds.

  Rules:
  - Ask questions ONLY if critical information is genuinely missing.
  - Ask questions that would materially improve the PRD.
  - If you have been given ANY answers in the Q&A history, you MUST respond
    with {"action": "generate"} unless there is a BLOCKING gap (e.g. no target
    user defined at all, or no problem statement whatsoever).
  - After TWO rounds of Q&A, ALWAYS respond with {"action": "generate"}.
  - Never ask more than 3 questions in a single round.
  - Never ask about things already answered.
  - Never ask about nice-to-have details — only blockers.


  Respond ONLY with one of:
  {"action": "ask", "questions": ["question 1", "question 2",...]}
  {"action": "generate"}

  Respond ONLY with the JSON object. No preamble, no markdown fences.
  """

  @impl true
  def run(%{requirements: requirements, qa_history: qa_history}, context) do
    user_message = build_user_message(requirements, qa_history)

    model =
      ReqLLM.model!(%{
        id: Application.get_env(:jido_phx, :ai_model),
        base_url: "http://localhost:1234/v1",
        provider: "openai",
        max_tokens: 1024
      })

    case ReqLLM.stream_text(model, user_message, system_prompt: @system_prompt) do
      {:ok, stream_response} ->
        raw = ReqLLM.StreamResponse.text(stream_response) |> String.trim()

        case Jason.decode(raw) do
          {:ok, %{"action" => "ask", "questions" => questions}} ->
            signal =
              Jido.Signal.new!(
                "requirements.clarification_needed",
                %{questions: questions},
                source: "/pm_agent"
              )

            emit = Directive.emit_to_parent(context.agent, signal)
            {:ok, %{status: :awaiting_clarification}, List.wrap(emit)}

          {:ok, %{"action" => "generate"}} ->
            signal =
              Jido.Signal.new!(
                "pm.generate_prd",
                %{requirements: requirements, qa_history: qa_history},
                source: "/pm_agent"
              )

            # emit to self by re-routing via parent signal dispatch
            emit = Directive.emit_to_parent(context.agent, signal)
            {:ok, %{status: :generating}, List.wrap(emit)}

          _ ->
            {:error, {:invalid_response, raw}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_user_message(requirements, nil) do
    "Requirements:\n#{requirements}"
  end

  defp build_user_message(requirements, qa_history) do
    """
    Requirements:
    #{requirements}

    Q&A History:
    #{qa_history}
    """
  end
end
