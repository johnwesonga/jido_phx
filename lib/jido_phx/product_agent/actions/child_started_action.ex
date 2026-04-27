defmodule JidoPhx.ProductAgent.Actions.ChildStartedAction do
  @moduledoc """
  Handles `jido.agent.child.started` on the CoordinatorAgent.

  The runtime delivers this signal whenever a child agent starts, passing
  the child's PID and the `meta` map supplied to `Directive.spawn_agent/3`.

  Behaviour:
  - If the child is a ProductManagerAgent → emit `pm.generate_prd` with requirements.
  - If the child is a TechnicalLeadAgent  → emit `tl.generate_spec` with the PRD.
  """

  # Ignore child.started for any other child module

  use Jido.Action,
    name: "child_started",
    schema: [
      parent_id: [type: :string, required: true],
      child_id: [type: :string, required: true],
      child_module: [type: :any, required: true],
      tag: [type: :any, required: true],
      pid: [type: :any, required: true],
      meta: [type: :map, default: %{}]
    ]

  alias Jido.Agent.Directive
  alias JidoPhx.ProductAgent.Agents.{ProductManagerAgent, TechnicalLeadAgent}

  require Logger

  @impl true
  def run(%{child_module: ProductManagerAgent, pid: pid, meta: meta}, _context) do
    Logger.info("child_module: ProductManagerAgent")

    signal =
      Jido.Signal.new!(
        "pm.generate_prd",
        %{requirements: meta.requirements, run_id: meta.run_id},
        source: "/coordinator"
      )

    {:ok, %{}, [Directive.emit_to_pid(signal, pid)]}
  end

  def run(%{child_module: TechnicalLeadAgent, pid: pid, meta: meta}, _context) do
    signal =
      Jido.Signal.new!(
        "tl.generate_spec",
        %{prd: meta.prd, run_id: meta.run_id},
        source: "/coordinator"
      )

    {:ok, %{}, [Directive.emit_to_pid(signal, pid)]}
  end

  def run(_params, _context), do: {:ok, %{}}
end
