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
      qa_history: [type: {:or, [:string, nil]}, default: nil],
      past_context: [type: {:or, [:string, nil]}, default: nil],
      round: [type: :integer, default: 0]
    ]

  alias Jido.Agent.Directive
  @max_rounds 1
  @base_skill File.read!("priv/agent_skills/product_manager.md")
  @task_skill File.read!("priv/agent_skills/tasks/analyze_requirements.md")

  @impl true
  def run(
        %{
          requirements: requirements,
          qa_history: qa_history,
          past_context: past_context,
          round: round
        },
        context
      ) do
    if round >= @max_rounds and not is_nil(qa_history) do
      generate(requirements, qa_history, context)
    else
      system_prompt = build_system_prompt(past_context)
      user_message = build_user_message(requirements, qa_history)

      model =
        ReqLLM.model!(%{
          id: Application.get_env(:jido_phx, :ai_model),
          base_url: "http://localhost:1234/v1",
          provider: "openai",
          max_tokens: 1024
        })

      case ReqLLM.stream_text(model, user_message, system_prompt: system_prompt) do
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
  end

  defp generate(requirements, qa_history, context) do
    signal =
      Jido.Signal.new!(
        "pm.generate_prd",
        %{requirements: requirements, qa_history: qa_history},
        source: "/pm_agent"
      )

    emit = Directive.emit_to_parent(context.agent, signal)
    {:ok, %{status: :generating}, List.wrap(emit)}
  end

  defp build_system_prompt(nil) do
    @base_skill <> "\n\n" <> @task_skill
  end

  defp build_system_prompt(past_context) do
    @base_skill <> "\n\n" <> past_context <> "\n\n" <> @task_skill
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
