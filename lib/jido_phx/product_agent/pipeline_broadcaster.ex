defmodule JidoPhx.ProductAgent.PipelineBroadcaster do
  @moduledoc """
  Broadcasts pipeline stage updates over Phoenix.PubSub.

  Called from coordinator actions so any subscribed LiveView receives
  real-time status updates as the pipeline progresses.

  Topic convention:
    "pipeline:{run_id}"

  Message shape:
    {:pipeline_update, %{run_id: String.t(), status: atom(), ...}}

  Statuses and their extra fields:
    :awaiting_prd          — no extra fields (LLM generating)
    :awaiting_prd_review   — prd: String.t()
    :awaiting_spec         — no extra fields (LLM generating)
    :awaiting_spec_review  — tech_spec: String.t()
    :awaiting_estimate       — no extra fields
    :complete              — prd: String.t(), tech_spec: String.t()
  """

  @pubsub JidoPhx.PubSub

  def topic(run_id), do: "pipeline:#{run_id}"

  def broadcast(run_id, payload) do
    Phoenix.PubSub.broadcast(@pubsub, topic(run_id), {:pipeline_update, payload})
  end

  def subscribe(run_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(run_id))
  end
end
