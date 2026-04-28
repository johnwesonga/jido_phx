defmodule JidoPhx.ProductAgent.Agents.ProductManagerAgent do
  @moduledoc """
  Product Manager specialist agent (plain `Jido.Agent`).

  Handles a single signal:

    pm.generate_prd  → GeneratePrdAction
      Calls the LLM, writes the PRD, emits `prd.complete` to parent.

  State shape:
    %{
      prd:    String.t() | nil,
      status: :idle | :done
    }

    Signal routes:
    pm.analyze_requirements → AnalyzeRequirementsAction (clarify or proceed)
    pm.generate_prd  → GeneratePrdAction  (initial generation)
    pm.revise_prd    → GeneratePrdAction  (revision after rejection)

  This agent is spawned as a child of the CoordinatorAgent. It does not
  know about the TechnicalLeadAgent and communicates only with its parent.
  """
  alias JidoPhx.ProductAgent.Actions.AnalyzeRequirementsAction
  alias JidoPhx.ProductAgent.Actions.GeneratePrdAction
  AnalyzeRequirementsAction

  use Jido.Agent,
    name: "product_manager_agent",
    schema: [
      prd: [type: :string, default: nil],
      status: [type: :atom, default: :idle]
    ]

  def signal_routes(_ctx) do
    [
      {"pm.analyze_requirements", AnalyzeRequirementsAction},
      {"pm.generate_prd", GeneratePrdAction},
      {"pm.revise_prd", GeneratePrdAction}
    ]
  end
end
