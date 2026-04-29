defmodule JidoPhx.ProductAgent.Agents.EstimatorAgent do
  @moduledoc """
  Engineering Estimator specialist agent.

  Signal routes:
    estimator.generate_estimate → GenerateEstimateAction
    estimator.revise_estimate   → GenerateEstimateAction (not used currently)
  """
  alias JidoPhx.ProductAgent.Actions.GenerateEstimateAction

  use Jido.Agent,
    name: "estimator_agent",
    schema: [
      estimate: [type: {:or, [:string, nil]}, default: nil],
      status: [type: :atom, default: :idle]
    ]

  def signal_routes(_ctx) do
    [
      {"estimator.generate_estimate", GenerateEstimateAction}
    ]
  end
end
