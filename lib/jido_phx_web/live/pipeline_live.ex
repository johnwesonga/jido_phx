defmodule JidoPhxWeb.PipelineLive do
  @moduledoc """
  LiveView for the PM → TL pipeline with human-in-the-loop review steps
  and side-by-side diff view on revision.

  Status state machine (mirrors CoordinatorAgent):
    :idle
    :awaiting_prd           — PM agent is generating
    :awaiting_prd_review    — PRD ready, waiting for user approve/reject
    :awaiting_spec          — TL agent is generating
    :awaiting_spec_review   — Spec ready, waiting for user approve/reject
    :complete
    :error

  Diff behaviour:
    - `prd_previous` is set to the current PRD just before a rejection
      replaces it with a revision. The review panel shows a diff tab
      when `prd_previous` is non-nil.
    - Same pattern for `tech_spec_previous`.
  """
  alias JidoPhx.PipelineBroadcaster
  use JidoPhxWeb, :live_view

  alias JidoPhx.Pipeline

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       requirements: "",
       run_id: nil,
       coordinator_pid: nil,
       status: :idle,
       questions: [],
       prd: nil,
       prd_previous: nil,
       tech_spec: nil,
       tech_spec_previous: nil,
       prd_filename: nil,
       tech_spec_filename: nil,
       estimate_filename: nil,
       error: nil
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
           status: :awaiting_clarification,
           requirements: requirements,
           error: nil,
           questions: [],
           prd: nil,
           prd_previous: nil,
           tech_spec: nil,
           tech_spec_previous: nil,
           estimate: nil
         )}

      {:error, reason} ->
        {:noreply, assign(socket, error: inspect(reason))}
    end
  end

  # ---------------------------------------------------------------------------
  # Events — clarifying questions
  # ---------------------------------------------------------------------------

  def handle_event("submit_clarifications", params, socket) do
    # params contains one key per question, keyed by question index string
    questions = socket.assigns.questions

    answers =
      questions
      |> Enum.with_index()
      |> Map.new(fn {question, idx} ->
        {question, Map.get(params, "q#{idx}", "")}
      end)

    Pipeline.provide_clarifications(socket.assigns.coordinator_pid, answers)

    {:noreply, assign(socket, status: :awaiting_prd, questions: [])}
  end

  # ---------------------------------------------------------------------------
  # Events — PRD review
  # ---------------------------------------------------------------------------

  def handle_event("approve_prd", _params, socket) do
    Pipeline.approve_prd(socket.assigns.coordinator_pid)
    {:noreply, assign(socket, status: :awaiting_spec, prd_previous: nil)}
  end

  def handle_event("reject_prd", %{"feedback" => feedback}, socket) do
    Pipeline.reject_prd(socket.assigns.coordinator_pid, feedback)

    {:noreply,
     assign(socket,
       status: :awaiting_prd,
       prd_previous: socket.assigns.prd,
       prd: nil
     )}
  end

  # ---------------------------------------------------------------------------
  # Events — Tech Spec review
  # ---------------------------------------------------------------------------

  def handle_event("approve_spec", _params, socket) do
    Pipeline.approve_spec(socket.assigns.coordinator_pid)
    {:noreply, assign(socket, status: :complete, tech_spec_previous: nil)}
  end

  def handle_event("reject_spec", %{"feedback" => feedback}, socket) do
    Pipeline.reject_spec(socket.assigns.coordinator_pid, feedback)

    {:noreply,
     assign(socket,
       status: :awaiting_spec,
       tech_spec_previous: socket.assigns.tech_spec,
       tech_spec: nil
     )}
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
       questions: [],
       prd: nil,
       prd_previous: nil,
       tech_spec: nil,
       tech_spec_previous: nil,
       prd_filename: nil,
       tech_spec_filename: nil,
       estimate_filename: nil,
       error: nil
     )}
  end

  # ---------------------------------------------------------------------------
  # PubSub — real-time updates from coordinator actions
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info(
        {:pipeline_update, %{status: :awaiting_clarification, questions: questions}},
        socket
      ) do
    {:noreply, assign(socket, status: :awaiting_clarification, questions: questions)}
  end

  def handle_info({:pipeline_update, %{status: :awaiting_prd}}, socket) do
    {:noreply, assign(socket, status: :awaiting_prd)}
  end

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

  def handle_info({:pipeline_update, %{status: :awaiting_estimate}}, socket) do
    {:noreply, assign(socket, status: :awaiting_estimate)}
  end

  def handle_info({:pipeline_update, %{status: :complete} = payload}, socket) do
    {:noreply,
     assign(socket,
       status: :complete,
       prd: payload.prd,
       tech_spec: payload.tech_spec,
       estimate: payload.estimate,
       prd_filename: payload.prd_filename,
       tech_spec_filename: payload.tech_spec_filename,
       estimate_filename: payload.estimate_filename
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

  defp clarification_panel(assigns) do
    ~H"""
    <div class="rounded-xl border border-blue-200 bg-blue-50 p-6 space-y-5">
      <div>
        <h2 class="text-xl font-semibold text-blue-900">Clarifying Questions</h2>
        <p class="text-sm text-blue-700 mt-1">
          Answer these questions to help the PM agent write a better PRD.
          You can leave fields blank if not applicable.
        </p>
      </div>

      <form phx-submit="submit_clarifications" class="space-y-5">
        <%= for {question, idx} <- Enum.with_index(@questions) do %>
          <div class="space-y-1.5">
            <label class="block text-sm font-medium text-gray-800">
              {idx + 1}. {question}
            </label>
            <textarea
              name={"q#{idx}"}
              rows="2"
              class="w-full rounded-lg border border-gray-300 p-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
              placeholder="Your answer..."
            ></textarea>
          </div>
        <% end %>

        <button
          type="submit"
          class="w-full py-2.5 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700"
        >
          Submit answers →
        </button>
      </form>
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
          <span class="text-xs text-gray-600">{@label}</span>
        <% @active and @review -> %>
          <span class="w-5 text-center text-amber-500">●</span>
          <span class="text-xs text-amber-600 font-medium">{@label}</span>
        <% @active -> %>
          <span class="w-5 text-center text-blue-500 animate-spin inline-block">⟳</span>
          <span class="text-xs text-blue-600 font-medium">{@label}</span>
        <% true -> %>
          <span class="w-5 text-center text-gray-300">○</span>
          <span class="text-xs text-gray-400">{@label}</span>
      <% end %>
    </div>
    """
  end

  defp review_panel(assigns) do
    assigns = assign(assigns, :has_diff, not is_nil(assigns.previous))

    ~H"""
    <div class="space-y-4 rounded-xl border border-amber-200 bg-amber-50 p-6">
      <h2 class="text-xl font-semibold text-amber-900">{@title}</h2>

      <%= if @has_diff do %>
        <div x-data="{ tab: 'document' }" class="space-y-4">
          <div class="flex gap-1 border-b border-amber-200">
            <button
              x-on:click="tab = 'document'"
              x-bind:class="tab === 'document' ? 'border-b-2 border-amber-600 text-amber-800 font-medium' : 'text-gray-500 hover:text-gray-700'"
              class="px-4 py-2 text-sm"
            >
              Document
            </button>
            <button
              x-on:click="tab = 'diff'"
              x-bind:class="tab === 'diff' ? 'border-b-2 border-amber-600 text-amber-800 font-medium' : 'text-gray-500 hover:text-gray-700'"
              class="px-4 py-2 text-sm"
            >
              What changed
            </button>
          </div>

          <div x-show="tab === 'document'">
            <pre class="rounded-lg bg-white border border-gray-200 p-4 text-sm text-gray-900 overflow-x-auto whitespace-pre-wrap max-h-[500px] overflow-y-auto"><%= @content %></pre>
          </div>

          <div x-show="tab === 'diff'">
            <div
              id={"diff-#{:erlang.phash2(@content)}"}
              phx-hook="DiffViewer"
              phx-update="ignore"
              data-old-content={@previous}
              data-new-content={@content}
              class="rounded-lg bg-white border border-gray-200 overflow-auto max-h-[500px] text-sm"
            >
            </div>
          </div>
        </div>
      <% else %>
        <pre class="rounded-lg bg-white border border-gray-200 p-4 text-sm text-gray-900 overflow-x-auto whitespace-pre-wrap max-h-[500px] overflow-y-auto"><%= @content %></pre>
      <% end %>

      <div class="flex gap-3 items-start pt-2">
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
