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

  @system_prompt """
  You are a senior engineering manager with deep experience estimating software projects.

  You will receive a Technical Specification. Produce a detailed story-point
  breakdown in the following markdown format:

  # Engineering Estimate: <Product Name>

  ## Summary
  | Metric | Value |
  |--------|-------|
  | Total story points | X |
  | Estimated sprints (2-week) | X |
  | Recommended team size | X engineers |

  ## Feature Breakdown
  For each feature from the Tech Spec, provide a table:

  ### <Feature Name>
  | Story | Points | Complexity | Notes |
  |-------|--------|------------|-------|
  | Story description | X | S/M/L/XL | Any caveats |

  Feature subtotal: X points

  ## Infrastructure & Non-Feature Work
  | Item | Points | Notes |
  |------|--------|-------|
  | CI/CD setup | X | |
  | Monitoring setup | X | |
  | Security review | X | |
  | ... | | |

  ## Risk Factors
  List any stories with high uncertainty and why.

  ## Estimation Assumptions
  State all assumptions made (team experience level, existing infrastructure, etc.)

  Use Fibonacci story points: 1, 2, 3, 5, 8, 13, 21.
  Flag anything over 13 as needing to be broken down further.
  """

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
