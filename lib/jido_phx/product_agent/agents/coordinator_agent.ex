defmodule JidoPhx.ProductAgent.Agents.CoordinatorAgent do
  @moduledoc """
  Coordinator agent — orchestrates the full pipeline via signals.

  Status state machine:
    :idle
      → pipeline.start           → :awaiting_prd
    :awaiting_prd
      → prd.review_requested     → :awaiting_prd_review
    :awaiting_prd_review
      → prd.approved             → :awaiting_spec
      → prd.rejected             → :awaiting_prd  (back to PM for revision)
    :awaiting_spec
      → spec.review_requested    → :awaiting_spec_review
    :awaiting_spec_review
      → spec.approved            → :complete
      → spec.rejected            → :awaiting_spec (back to TL for revision)

  State shape:
    %{
      run_id:    String.t(),
      requirements: String.t(),
      prd:       String.t() | nil,
      tech_spec: String.t() | nil,
      status:    atom()
    }
  """

  use Jido.Agent,
    name: "coordinator_agent",
    schema: [
      run_id: [type: :string, default: nil],
      requirements: [type: :string, default: nil],
      prd: [type: :string, default: nil],
      tech_spec: [type: :string, default: nil],
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
    SpecRejectedAction
  }

  def signal_routes(_ctx) do
    [
      {"pipeline.start", StartPipelineAction},
      {"jido.agent.child.started", ChildStartedAction},
      {"prd.review_requested", PrdReviewRequestedAction},
      {"prd.approved", PrdApprovedAction},
      {"prd.rejected", PrdRejectedAction},
      {"spec.review_requested", SpecReviewRequestedAction},
      {"spec.approved", SpecApprovedAction},
      {"spec.rejected", SpecRejectedAction}
    ]
  end
end
