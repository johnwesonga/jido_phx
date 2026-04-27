defmodule JidoPhx.ProductAgent.Agents.TechnicalLeadAgent do
  @moduledoc """
  Technical Lead specialist agent (plain `Jido.Agent`).

  Handles a single signal:

    tl.generate_spec → GenerateSpecAction
      Calls the LLM, writes the Tech Spec, emits `spec.complete` to parent.

  State shape:
    %{
      tech_spec: String.t() | nil,
      status:    :idle | :done
    }

  Spawned as a child of the CoordinatorAgent after the PRD is complete.
  Knows nothing about the ProductManagerAgent.
  """
  alias JidoPhx.ProductAgent.Actions.GenerateSpecAction

  use Jido.Agent,
    name: "technical_lead_agent",
    schema: [
      tech_spec: [type: :string, default: nil],
      status: [type: :atom, default: :idle]
    ]

  def signal_routes(_ctx) do
    [
      {"tl.generate_spec", GenerateSpecAction},
      {"tl.revise_spec", GenerateSpecAction}
    ]
  end
end
