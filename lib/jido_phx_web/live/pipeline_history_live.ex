defmodule JidoPhxWeb.PipelineHistoryLive do
  @moduledoc """
  Lists all past pipeline runs sourced from Postgres, most recent first.

  Each row shows:
  - Run ID (truncated)
  - Status badge
  - Started at timestamp
  - Requirements summary
  - Download links for completed documents

  Subscribes to PubSub so in-progress runs update in real time
  without a page refresh.
  """
  use JidoPhxWeb, :live_view

  alias JidoPhx.ProductAgent.{PipelineRuns, PipelineBroadcaster}

  @impl true
  def mount(_params, _session, socket) do
    runs = PipelineRuns.list()

    # Subscribe to all active run topics so in-progress rows update live
    runs
    |> Enum.filter(&(&1.status != "complete"))
    |> Enum.each(&PipelineBroadcaster.subscribe(&1.id))

    {:ok, assign(socket, runs: runs)}
  end

  # ---------------------------------------------------------------------------
  # PubSub — update individual rows as status changes
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:pipeline_update, %{run_id: run_id, status: _status}}, socket) do
    runs =
      Enum.map(socket.assigns.runs, fn run ->
        if run.id == run_id do
          # Re-fetch from DB to get latest filenames if complete
          PipelineRuns.get(run_id) || run
        else
          run
        end
      end)

    {:noreply, assign(socket, runs: runs)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <header class="bg-white border-b border-gray-200 px-8 py-4 flex items-center justify-between">
        <h1 class="text-xl font-bold text-gray-900">Pipeline History</h1>
        <.link
          navigate={~p"/pipeline"}
          class="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg font-semibold hover:bg-blue-700"
        >
          + New pipeline
        </.link>
      </header>

      <div class="max-w-6xl mx-auto px-8 py-8">
        <%= if @runs == [] do %>
          <div class="text-center py-24 text-gray-400">
            <p class="text-lg">No pipeline runs yet.</p>
            <.link
              navigate={~p"/pipeline"}
              class="text-blue-500 hover:underline text-sm mt-2 inline-block"
            >
              Start your first one →
            </.link>
          </div>
        <% else %>
          <div class="space-y-3">
            <%= for run <- @runs do %>
              <.run_row run={run} />
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  defp run_row(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-gray-200 p-5 flex items-start gap-5">
      <%!-- Status badge --%>
      <div class="shrink-0 pt-0.5">
        <.status_badge status={@run.status} />
      </div>

      <%!-- Main content --%>
      <div class="flex-1 min-w-0 space-y-1">
        <div class="flex items-center gap-3">
          <span class="font-mono text-xs text-gray-400">{String.slice(@run.id, 0, 16)}…</span>
          <span class="text-xs text-gray-400">{format_timestamp(@run.inserted_at)}</span>
        </div>

        <p class="text-sm text-gray-700 line-clamp-2">{@run.requirements_summary}</p>

        <%!-- Download links — only shown when complete --%>
        <%= if @run.status == "complete" do %>
          <div class="flex gap-4 pt-1">
            <%= if @run.prd_filename do %>
              <a
                href={"/pipeline_outputs/#{@run.prd_filename}"}
                download
                class="text-xs text-blue-600 hover:underline"
              >
                ↓ PRD
              </a>
            <% end %>
            <%= if @run.tech_spec_filename do %>
              <a
                href={"/pipeline_outputs/#{@run.tech_spec_filename}"}
                download
                class="text-xs text-blue-600 hover:underline"
              >
                ↓ Tech Spec
              </a>
            <% end %>
            <%= if @run.estimate_filename do %>
              <a
                href={"/pipeline_outputs/#{@run.estimate_filename}"}
                download
                class="text-xs text-blue-600 hover:underline"
              >
                ↓ Estimate
              </a>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp status_badge(assigns) do
    {bg, text, label} =
      case assigns.status do
        "complete" -> {"bg-green-100", "text-green-700", "Complete"}
        "awaiting_prd_review" -> {"bg-amber-100", "text-amber-700", "PRD review"}
        "awaiting_spec_review" -> {"bg-amber-100", "text-amber-700", "Spec review"}
        "awaiting_clarification" -> {"bg-blue-100", "text-blue-700", "Clarifying"}
        "awaiting_prd" -> {"bg-blue-100", "text-blue-700", "Writing PRD"}
        "awaiting_spec" -> {"bg-blue-100", "text-blue-700", "Writing Spec"}
        "awaiting_estimate" -> {"bg-blue-100", "text-blue-700", "Estimating"}
        _ -> {"bg-gray-100", "text-gray-600", assigns.status}
      end

    assigns = assign(assigns, bg: bg, text: text, label: label)

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@bg} #{@text}"}>
      {@label}
    </span>
    """
  end

  defp format_timestamp(nil), do: ""

  defp format_timestamp(dt) do
    dt
    |> DateTime.from_naive!("Etc/UTC")
    |> Calendar.strftime("%d %b %Y, %H:%M UTC")
  rescue
    _ -> ""
  end
end
