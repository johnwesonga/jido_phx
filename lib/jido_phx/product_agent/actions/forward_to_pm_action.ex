defmodule JidoPhx.ProductAgent.Actions.ForwardToPmAction do
  use Jido.Action,
    name: "forward_to_pm",
    schema: [
      requirements: [type: :string, required: true],
      qa_history: [type: {:or, [:string, nil]}, default: nil]
    ]

  alias Jido.Agent.Directive

  @impl true
  def run(%{requirements: requirements, qa_history: qa_history}, context) do
    agent_id = "coordinator-#{context.state.run_id}/pm_agent"

    case Jido.AgentServer.whereis(JidoPhx.Jido.Registry, agent_id) do
      nil ->
        {:error, {:pm_agent_not_found, agent_id}}

      pm_pid ->
        signal =
          Jido.Signal.new!(
            "pm.generate_prd",
            %{requirements: requirements, qa_history: qa_history},
            source: "/coordinator"
          )

        {:ok, %{}, [Directive.emit_to_pid(signal, pm_pid)]}
    end
  end
end
