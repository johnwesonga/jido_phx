defmodule JidoPhx.ProductAgent.Actions.GeneratePrdAction do
  @moduledoc """
  Handles `pm.generate_prd` and `pm.revise_prd` on the ProductManagerAgent.

  On first run, generates a PRD from requirements + optional Q&A history.
  On revision, incorporates user feedback into a revised draft.
  Either way, emits `prd.review_requested` to the parent coordinator.
  """
  use Jido.Action,
    name: "generate_prd",
    schema: [
      requirements: [type: {:or, [:string, nil]}, default: nil],
      qa_history: [type: {:or, [:string, nil]}, default: nil],
      current_prd: [type: {:or, [:string, nil]}, default: nil],
      feedback: [type: {:or, [:string, nil]}, default: nil]
    ]

  require Logger

  @generate_prompt """
  You are a senior Product Manager. Based on the requirements below, write a
  comprehensive Product Requirements Document (PRD) in the following markdown format:

  # Product Requirements Document: <Product Name>

  ## Overview
  Short paragraph describing the product and its purpose.

  ## Problem Statement
  What problem does this product solve?

  ## Target Users
  Who will use this product?

  ## Goals & Success Metrics
  Numbered list of measurable goals.

  ## Key Features
  Subsections (###) for each feature with a brief description and acceptance criteria.

  ## Out of Scope
  Explicit list of things NOT included in this version.

  ## Constraints & Assumptions
  Technical, time, budget, or other constraints.

  ## Open Questions
  Anything still unresolved that the team needs to decide.

  ---
  Requirements:
  """

  @revise_system """
  You are a senior Product Manager. You previously wrote a PRD which a reviewer
  has rejected with the following feedback. Revise the PRD to address the feedback.
  Return the complete revised PRD in the same markdown format.

  Reviewer feedback:
  """

  alias Jido.Agent.Directive

  @default_model "google/gemma-4-e2b"

  @impl true
  def run(%{requirements: requirements}, context) when not is_nil(requirements) do
    qa_history = context.state[:qa_history]
    user_message = build_generate_message(requirements, qa_history)
    call_and_emit(user_message, @generate_prompt, context)
  end

  def run(%{current_prd: current_prd, feedback: feedback}, context) do
    user_message = "Feedback: #{feedback}\n\nCurrent PRD:\n#{current_prd}"
    call_and_emit(user_message, @revise_system, context)
  end

  # ---------------------------------------------------------------------------
  # Private — LLM call via jido_ai / req_llm
  # ---------------------------------------------------------------------------

  defp call_and_emit(user_message, system_prompt, context) do
    case call_llm(user_message, system_prompt) do
      {:ok, prd} ->
        result_signal =
          Jido.Signal.new!(
            "prd.review_requested",
            %{prd: String.trim(prd)},
            source: "/pm_agent"
          )

        emit = Directive.emit_to_parent(context.agent, result_signal)

        {:ok, %{prd: String.trim(prd), status: :done}, List.wrap(emit)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call_llm(user_message, system_prompt) do
    # model = Application.get_env(:jido_phx, :ai_model, @default_model)
    ReqLLM.put_key(:openai_api_key, "lm-studio")

    model =
      ReqLLM.model!(%{
        id: Application.get_env(:jido_phx, :ai_model, @default_model),
        base_url: "http://localhost:1234/v1",
        provider: "openai",
        max_tokens: 16_384
      })

    case ReqLLM.stream_text(model, user_message, system_prompt: system_prompt) do
      {:ok, stream_response} ->
        text = ReqLLM.StreamResponse.text(stream_response)
        log_usage(stream_response)
        {:ok, text}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_generate_message(requirements, nil), do: requirements

  defp build_generate_message(requirements, qa_history) do
    """
    Requirements:
    #{requirements}

    Additional context from clarification Q&A:
    #{qa_history}
    """
  end

  defp call_llm_old(requirements) do
    model = Application.get_env(:jido_phx, :ai_model, @default_model)
    # ReqLLM.put_key(:openai_api_key, "lm-studio")

    # model =
    #   ReqLLM.model!(%{
    #    # must match exactly what LM Studio shows
    #     id: @default_model,
    #     temperature: 0.2,
    #    max_tokens: 64_000,
    #    base_url: "http://localhost:1234/v1"
    #  })

    case ReqLLM.stream_text(model, requirements,
           system_prompt: @generate_prompt,
           # lower = more factual, less creative
           # temperature: 0.2,
           max_tokens: 16_384,
           receive_timeout: :infinity
         ) do
      {:ok, response} ->
        text = ReqLLM.StreamResponse.text(response)
        log_usage(response)
        Logger.info("[GeneratePrdAction] #{byte_size(text)} bytes")
        {:ok, text}

      {:error, _} = err ->
        err
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
