defmodule JidoPhx.ProductAgent.Actions.GenerateEstimateAction do
  @moduledoc """
  Handles `estimator.generate_estimate` on the EstimatorAgent.

  Receives the approved Tech Spec and produces a story-point breakdown
  covering all features and components. Emits `estimate.complete` to
  the parent CoordinatorAgent when done.
  """
  use Jido.Action,
    name: "generate_estimate",
    schema: [
      tech_spec: [type: :string, required: true]
    ]

  alias Jido.Agent.Directive

  @base_skill File.read!("priv/agent_skills/estimator.md")
  @generate_task File.read!("priv/agent_skills/tasks/generate_estimate.md")
  @system_prompt @base_skill <> "\n\n" <> @generate_task

  def run(%{tech_spec: tech_spec}, context) do
    ReqLLM.put_key(:openai_api_key, "lm-studio")

    model =
      ReqLLM.model!(%{
        id: Application.get_env(:jido_phx, :ai_model),
        base_url: "http://localhost:1234/v1",
        provider: "openai",
        max_tokens: 16_384
      })

    case ReqLLM.stream_text(model, tech_spec, system_prompt: @system_prompt) do
      {:ok, stream_response} ->
        estimate = ReqLLM.StreamResponse.text(stream_response) |> String.trim()

        result_signal =
          Jido.Signal.new!(
            "estimate.complete",
            %{estimate: estimate},
            source: "/estimator_agent"
          )

        emit = Directive.emit_to_parent(context.agent, result_signal)
        {:ok, %{estimate: estimate, status: :done}, List.wrap(emit)}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
