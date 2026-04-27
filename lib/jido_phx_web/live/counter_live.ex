defmodule JidoPhxWeb.CounterLive do
  use JidoPhxWeb, :live_view
  alias Jido.Signal
  require Logger

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(JidoPhx.PubSub, "counter:#{id}")
    end

    {:ok, socket |> assign(:id, id) |> load_count(id)}
  end

  @agent_id "counter"

  defp load_count(socket, _id) do
    case JidoPhx.Jido.whereis(@agent_id) do
      nil ->
        assign(socket, count: 0)

      pid ->
        Logger.info("agent: [JidoPhx.Agents.CounterAgent] id: #{@agent_id} loaded")
        {:ok, state} = Jido.AgentServer.state(pid)
        assign(socket, count: state.agent.state.count)
    end
  end

  @impl true
  def handle_event("increment", %{"amount" => amount}, socket) do
    {:noreply,
     send_and_broadcast(socket, "counter.increment", %{amount: String.to_integer(amount)})}
  end

  def handle_event("decrement", _params, socket) do
    {:noreply, send_and_broadcast(socket, "counter.decrement", %{amount: 1})}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, send_and_broadcast(socket, "counter.reset", %{})}
  end

  defp send_and_broadcast(socket, type, data) do
    id = socket.assigns.id
    signal = Signal.new!(type, data, source: "/liveview")

    case JidoPhx.Jido.whereis(@agent_id) do
      nil ->
        socket

      pid ->
        {:ok, agent} = Jido.AgentServer.call(pid, signal)
        Phoenix.PubSub.broadcast(JidoPhx.PubSub, "counter:#{id}", {:counter_updated, agent.state})
        assign(socket, count: agent.state.count)
    end
  end

  @impl true
  def handle_info({:counter_updated, state}, socket) do
    {:noreply, assign(socket, count: state.count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-2xl font-bold mb-4">Counter: {@id}</h1>
      <p class="text-6xl font-mono mb-8">{@count}</p>

      <div class="flex gap-2">
        <button phx-click="decrement" class="px-4 py-2 bg-red-500 text-white rounded">-1</button>
        <button
          phx-click="increment"
          phx-value-amount="1"
          class="px-4 py-2 bg-green-500 text-white rounded"
        >
          +1
        </button>
        <button
          phx-click="increment"
          phx-value-amount="10"
          class="px-4 py-2 bg-green-700 text-white rounded"
        >
          +10
        </button>
        <button phx-click="reset" class="px-4 py-2 bg-gray-500 text-white rounded">Reset</button>
      </div>

      <p class="mt-4 text-gray-500">Open this page in multiple tabs to see real-time sync.</p>
    </div>
    """
  end
end
