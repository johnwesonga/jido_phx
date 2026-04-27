defmodule JidoPhxWeb.PipelineLive do
  @moduledoc """
  LiveView for the PM → TL pipeline with human-in-the-loop review steps.

  Status state machine (mirrors CoordinatorAgent):
    :idle
    :awaiting_prd           — PM agent is generating
    :awaiting_prd_review    — PRD ready, waiting for user approve/reject
    :awaiting_spec          — TL agent is generating
    :awaiting_spec_review   — Spec ready, waiting for user approve/reject
    :complete
    :error
  """
  alias JidoPhx.PipelineBroadcaster
  use JidoPhxWeb, :live_view

  alias JidoPhx.ProductAgent.Pipeline

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       requirements: "",
       run_id: nil,
       coordinator_pid: nil,
       status: :idle,
       prd: nil,
       tech_spec: nil,
       prd_feedback: "",
       spec_feedback: "",
       error: nil,
       prd_filename: nil,
       tech_spec_filename: nil
     )}
  end

  # ---------------------------------------------------------------------------
  # Events — pipeline start
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("generate", %{"requirements" => requirements}, socket)
      when byte_size(requirements) < 10 do
    {:noreply, assign(socket, error: "Please enter more detail before generating.")}
  end

  def handle_event("generate", %{"requirements" => requirements}, socket) do
    run_id = Pipeline.generate_run_id()
    PipelineBroadcaster.subscribe(run_id)

    case Pipeline.start(requirements, run_id: run_id) do
      {:ok, coordinator_pid} ->
        {:noreply,
         assign(socket,
           run_id: run_id,
           coordinator_pid: coordinator_pid,
           status: :awaiting_prd,
           requirements: requirements,
           error: nil,
           prd: nil,
           tech_spec: nil
         )}

      {:error, reason} ->
        {:noreply, assign(socket, error: inspect(reason))}
    end
  end

  # ---------------------------------------------------------------------------
  # Events — PRD review
  # ---------------------------------------------------------------------------

  def handle_event("approve_prd", _params, socket) do
    Pipeline.approve_prd(socket.assigns.coordinator_pid)
    {:noreply, assign(socket, status: :awaiting_spec, prd_feedback: "")}
  end

  def handle_event("reject_prd", %{"feedback" => feedback}, socket) do
    Pipeline.reject_prd(socket.assigns.coordinator_pid, feedback)
    {:noreply, assign(socket, status: :awaiting_prd, prd_feedback: "", prd: nil)}
  end

  def handle_event("update_prd_feedback", %{"feedback" => value}, socket) do
    {:noreply, assign(socket, prd_feedback: value)}
  end

  # ---------------------------------------------------------------------------
  # Events — Tech Spec review
  # ---------------------------------------------------------------------------

  def handle_event("approve_spec", _params, socket) do
    Pipeline.approve_spec(socket.assigns.coordinator_pid)
    {:noreply, assign(socket, status: :complete, spec_feedback: "")}
  end

  def handle_event("reject_spec", %{"feedback" => feedback}, socket) do
    Pipeline.reject_spec(socket.assigns.coordinator_pid, feedback)
    {:noreply, assign(socket, status: :awaiting_spec, spec_feedback: "", tech_spec: nil)}
  end

  def handle_event("update_spec_feedback", %{"feedback" => value}, socket) do
    {:noreply, assign(socket, spec_feedback: value)}
  end

  # ---------------------------------------------------------------------------
  # Events — reset
  # ---------------------------------------------------------------------------

  def handle_event("reset", _params, socket) do
    {:noreply,
     assign(socket,
       requirements: "",
       run_id: nil,
       coordinator_pid: nil,
       status: :idle,
       prd: nil,
       tech_spec: nil,
       prd_feedback: "",
       spec_feedback: "",
       error: nil
     )}
  end

  # ---------------------------------------------------------------------------
  # PubSub — real-time updates from coordinator actions
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:pipeline_update, %{status: :awaiting_prd_review, prd: prd}}, socket) do
    {:noreply, assign(socket, status: :awaiting_prd_review, prd: prd)}
  end

  def handle_info({:pipeline_update, %{status: :awaiting_spec}}, socket) do
    {:noreply, assign(socket, status: :awaiting_spec)}
  end

  def handle_info(
        {:pipeline_update, %{status: :awaiting_spec_review, tech_spec: tech_spec}},
        socket
      ) do
    {:noreply, assign(socket, status: :awaiting_spec_review, tech_spec: tech_spec)}
  end

  def handle_info(
        {:pipeline_update,
         %{
           status: :complete,
           prd: prd,
           tech_spec: tech_spec,
           prd_filename: prd_filename,
           tech_spec_filename: tech_spec_filename
         }},
        socket
      ) do
    {:noreply,
     assign(socket,
       status: :complete,
       prd: prd,
       tech_spec: tech_spec,
       prd_filename: prd_filename,
       tech_spec_filename: tech_spec_filename
     )}
  end

  def handle_info({:pipeline_update, _}, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  defp generating_indicator(assigns) do
    ~H"""
    <div class="flex items-center gap-3 py-12 text-blue-600">
      <span class="text-2xl animate-spin inline-block">⟳</span>
      <span class="text-lg font-medium">{@label}</span>
    </div>
    """
  end

  defp stage_row(assigns) do
    assigns =
      assigns
      |> assign_new(:active, fn -> false end)
      |> assign_new(:review, fn -> false end)

    ~H"""
    <div class="flex items-center gap-3 py-1">
      <%= cond do %>
        <% @done -> %>
          <span class="w-5 text-center text-green-500">✓</span>
          <span class="text-gray-600">{@label}</span>
        <% @active and @review -> %>
          <span class="w-5 text-center text-amber-500">●</span>
          <span class="text-amber-600 font-medium">{@label}</span>
        <% @active -> %>
          <span class="w-5 text-center text-blue-500 animate-spin inline-block">⟳</span>
          <span class="text-blue-600 font-medium">{@label}</span>
        <% true -> %>
          <span class="w-5 text-center text-gray-300">○</span>
          <span class="text-gray-400">{@label}</span>
      <% end %>
    </div>
    """
  end

  defp review_panel(assigns) do
    ~H"""
    <div class="space-y-4 rounded-xl border border-amber-200 bg-amber-50 p-6">
      <h2 class="text-xl font-semibold text-amber-900">{@title}</h2>

      <pre class="rounded-lg bg-white border border-gray-200 p-4 text-sm text-gray-900 overflow-x-auto whitespace-pre-wrap max-h-[500px] overflow-y-auto"><%= @content %></pre>

      <div class="flex gap-3 items-start">
        <button
          phx-click={@approve_event}
          class="shrink-0 px-5 py-2 bg-green-600 text-white rounded-lg font-semibold hover:bg-green-700"
        >
          ✓ Approve
        </button>
        <form phx-submit={@reject_event} class="flex-1 flex gap-2 items-start">
          <textarea
            name="feedback"
            rows="2"
            placeholder="Feedback for revision (required if rejecting)..."
            class="flex-1 rounded-lg border border-gray-300 p-2 text-sm focus:outline-none focus:ring-2 focus:ring-amber-400"
          ></textarea>
          <button
            type="submit"
            class="shrink-0 px-5 py-2 bg-red-600 text-white rounded-lg font-semibold hover:bg-red-700"
          >
            ✗ Reject
          </button>
        </form>
      </div>
    </div>
    """
  end

  defp doc_section(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="flex items-center justify-between">
        <h2 class="text-xl font-semibold text-gray-900">{@title}</h2>
        <a
          href={"/pipeline_outputs/#{@filename}"}
          download
          class="text-sm text-blue-600 hover:underline"
        >
          Download
        </a>
      </div>
      <pre class="rounded-lg bg-gray-100 border border-gray-300 p-4 text-sm text-gray-900 overflow-x-auto whitespace-pre-wrap max-h-[600px] overflow-y-auto"><%= @content %></pre>
    </div>
    """
  end
end
