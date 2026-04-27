defmodule JidoPhx.ProductAgent.Actions.GenerateSpecAction do
  @moduledoc """
  Handles `tl.generate_spec` and `tl.revise_spec` on the TechnicalLeadAgent.

  On first run, generates a Tech Spec from the approved PRD.
  On revision, incorporates user feedback into a revised draft.
  Either way, emits `spec.review_requested` to the parent.
  """
  use Jido.Action,
    name: "generate_spec",
    schema: [
      prd: [type: {:or, [:string, nil]}, default: nil],
      current_spec: [type: {:or, [:string, nil]}, default: nil],
      feedback: [type: {:or, [:string, nil]}, default: nil]
    ]

  alias Jido.Agent.Directive
  require Logger

  @model "anthropic:claude-sonnet-4-20250514"

  @generate_system """
  You are a senior Technical Lead. Based on the PRD the user provides, write a
  detailed Technical Specification in the following markdown format:

  # Technical Specification: <Product Name>

  ## 1. Architecture Overview
  ## 2. Technology Stack
  ## 3. Data Models
  ## 4. API Design
  ## 5. Component Breakdown
  ## 6. Implementation Plan
  ## 7. Security & Compliance
  ## 8. Observability
  ## 9. Open Technical Questions
  ## 10. Out of Scope (Technical)
  """

  @revise_system """
  You are a senior Technical Lead. The user will provide a Tech Spec you previously
  wrote along with reviewer feedback. Revise the spec to address the feedback and
  return the complete revised Tech Spec in the same markdown format.
  """

  @impl true
  def run(%{prd: prd}, context) when not is_nil(prd) do
    call_and_emit(prd, @generate_system, context)
  end

  def run(%{current_spec: current_spec, feedback: feedback}, context) do
    user_message = "Feedback: #{feedback}\n\nCurrent Tech Spec:\n#{current_spec}"
    call_and_emit(user_message, @revise_system, context)
  end

  defp call_and_emit(user_message, system_prompt, context) do
    # model = Application.get_env(:jido_phx, :ai_model, @model)
    ReqLLM.put_key(:openai_api_key, "lm-studio")

    model =
      ReqLLM.model!(%{
        id: Application.get_env(:jido_phx, :ai_model, @model),
        base_url: "http://localhost:1234/v1",
        provider: "openai",
        max_tokens: 16_384,
        receive_timeout: :infinity
      })

    case ReqLLM.stream_text(model, user_message, system_prompt: system_prompt) do
      {:ok, stream_response} ->
        log_usage(stream_response)
        spec = stream_response |> ReqLLM.StreamResponse.text() |> String.trim()

        result_signal =
          Jido.Signal.new!(
            "spec.review_requested",
            %{tech_spec: spec},
            source: "/tl_agent"
          )

        emit = Directive.emit_to_parent(context.agent, result_signal)
        {:ok, %{tech_spec: spec, status: :done}, List.wrap(emit)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp log_usage(response) do
    case ReqLLM.StreamResponse.usage(response) do
      nil ->
        :ok

      usage ->
        Logger.debug(
          "[GenerateSpecAction] tokens in=#{usage.input_tokens} out=#{usage.output_tokens}" <>
            if(usage[:total_cost], do: " cost=$#{usage.total_cost}", else: "")
        )
    end
  end
end
