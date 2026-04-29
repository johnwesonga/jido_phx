defmodule JidoPhx.ProductAgent.Agents.CoordinatorAgent do
  @moduledoc """
  Coordinator agent — orchestrates the full pipeline via signals.

  Status state machine:
    :idle
      → pipeline.start                    → :awaiting_clarification
    :awaiting_clarification
      → requirements.clarification_needed → :awaiting_clarification (stores questions)
      → pipeline.clarifications_provided  → :awaiting_prd (merges answers, re-analyzes)
    :awaiting_prd
      → prd.review_requested              → :awaiting_prd_review
    :awaiting_prd_review
      → prd.approved                      → :awaiting_spec
      → prd.rejected                      → :awaiting_prd
    :awaiting_spec
      → spec.review_requested             → :awaiting_spec_review
    :awaiting_spec_review
      → spec.approved                     → :complete
      → spec.rejected                     → :awaiting_spec
  """

  alias JidoPhx.ProductAgent.Actions.EstimateCompleteAction

  use Jido.Agent,
    name: "coordinator_agent",
    schema: [
      run_id: [type: {:or, [:string, nil]}, default: nil],
      requirements: [type: {:or, [:string, nil]}, default: nil],
      qa_history: [type: {:or, [:string, nil]}, default: nil],
      questions: [type: {:list, :string}, default: []],
      prd: [type: {:or, [:string, nil]}, default: nil],
      tech_spec: [type: {:or, [:string, nil]}, default: nil],
      status: [type: :atom, default: :idle]
    ]

  alias JidoPhx.ProductAgent.Actions.{
    StartPipelineAction,
    ChildStartedAction,
    PrdReviewRequestedAction,
    PrdApprovedAction,
    PrdRejectedAction,
    SpecReviewRequestedAction,
    SpecApprovedAction,
    SpecRejectedAction,
    ClarificationNeededAction,
    ClarificationsProvidedAction,
    ForwardToPmAction
  }

  require Logger

  @spec handle_signal(any(), any()) :: {:ok, any(), any()}
  def handle_signal(signal, state) do
    Logger.info("[Coordinator] routing signal: #{signal.type}")
    {:ok, signal, state}
  end

  def signal_routes(_ctx) do
    [
      {"pipeline.start", StartPipelineAction},
      {"jido.agent.child.started", ChildStartedAction},
      {"requirements.clarification_needed", ClarificationNeededAction},
      {"pm.generate_prd", ForwardToPmAction},
      {"pipeline.clarifications_provided", ClarificationsProvidedAction},
      {"prd.review_requested", PrdReviewRequestedAction},
      {"prd.approved", PrdApprovedAction},
      {"prd.rejected", PrdRejectedAction},
      {"spec.review_requested", SpecReviewRequestedAction},
      {"spec.approved", SpecApprovedAction},
      {"spec.rejected", SpecRejectedAction},
      {"estimate.complete", EstimateCompleteAction}
    ]
  end
end
