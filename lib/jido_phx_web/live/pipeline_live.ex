defmodule JidoPhxWeb.PipelineLive do
  @moduledoc """
  LiveView for the PM → TL → Estimator pipeline with clarifying questions,
  human-in-the-loop review steps, and side-by-side diff view on revision.
  """
  use JidoPhxWeb, :live_view

  alias JidoPhx.ProductAgent.{Pipeline, PipelineBroadcaster, PipelineRuns}

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
       estimate: nil,
       prd_filename: nil,
       tech_spec_filename: nil,
       estimate_filename: nil,
       error: nil,
       show_history: false,
       history_runs: []
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
    answers =
      socket.assigns.questions
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
    {:noreply, assign(socket, status: :awaiting_estimate, tech_spec_previous: nil)}
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
  # Events — history panel
  # ---------------------------------------------------------------------------

  def handle_event("toggle_history", _params, socket) do
    if socket.assigns.show_history do
      {:noreply, assign(socket, show_history: false, history_runs: [])}
    else
      runs = PipelineRuns.list()
      {:noreply, assign(socket, show_history: true, history_runs: runs)}
    end
  end

  def handle_event("close_history", _params, socket) do
    {:noreply, assign(socket, show_history: false, history_runs: [])}
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
       estimate: nil,
       prd_filename: nil,
       tech_spec_filename: nil,
       estimate_filename: nil,
       error: nil,
       show_history: false,
       history_runs: []
     )}
  end

  # ---------------------------------------------------------------------------
  # PubSub
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <header class="bg-white border-b border-gray-200 px-8 py-4 flex items-center justify-between">
        <h1 class="text-xl font-bold text-gray-900">Product Pipeline</h1>
        <div class="flex items-center gap-3">
          <button
            phx-click="toggle_history"
            class={"text-sm px-3 py-1.5 rounded-lg border #{if @show_history, do: "bg-gray-900 text-white border-gray-900", else: "bg-white text-gray-600 border-gray-300 hover:bg-gray-50"}"}
          >
            ≡ History
          </button>
          <%= if @status not in [:idle, :error] do %>
            <button
              phx-click="reset"
              class="text-sm px-3 py-1.5 bg-gray-100 text-gray-600 rounded-lg hover:bg-gray-200"
            >
              ↩ Start over
            </button>
          <% end %>
        </div>
      </header>

      <%!-- History slide-in panel --%>
      <%= if @show_history do %>
        <div class="fixed inset-0 z-40 flex justify-end" phx-click="close_history">
          <%!-- Backdrop --%>
          <div class="absolute inset-0 bg-black/30"></div>

          <%!-- Panel --%>
          <div
            class="relative z-50 w-[480px] h-full bg-white shadow-xl flex flex-col"
            phx-click-away="close_history"
          >
            <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
              <h2 class="text-lg font-semibold text-gray-900">Pipeline History</h2>
              <button
                phx-click="close_history"
                class="text-gray-400 hover:text-gray-600 text-xl leading-none"
              >
                ✕
              </button>
            </div>

            <div class="flex-1 overflow-y-auto px-6 py-4 space-y-3">
              <%= if @history_runs == [] do %>
                <p class="text-sm text-gray-400 text-center py-12">No pipeline runs yet.</p>
              <% else %>
                <%= for run <- @history_runs do %>
                  <.history_row run={run} />
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @status in [:idle, :error] do %>
        <div class="max-w-2xl mx-auto px-8 py-12">
          <form phx-submit="generate" class="space-y-4">
            <div>
              <label class="block font-semibold text-gray-700 mb-1">Product Requirements</label>
              <p class="text-sm text-gray-500 mb-2">
                The PM agent will ask clarifying questions before writing the PRD.
              </p>
              <textarea
                name="requirements"
                rows="10"
                placeholder="e.g. Product: TaskFlow – a team task manager&#10;Target users: small engineering teams&#10;Key features: Kanban board, GitHub integration, Slack notifications"
                class="w-full rounded-lg border text-gray-700 border-gray-300 p-3 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              ><%= @requirements %></textarea>
            </div>

            <%= if @error do %>
              <p class="text-red-500 text-sm">{@error}</p>
            <% end %>

            <button
              type="submit"
              class="w-full py-2.5 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700"
            >
              Start →
            </button>
          </form>
        </div>
      <% else %>
        <div class="flex h-[calc(100vh-57px)]">
          <%!-- LEFT: requirements + progress --%>
          <aside class="w-72 shrink-0 border-r border-gray-200 bg-white flex flex-col">
            <div class="px-5 py-4 border-b border-gray-100">
              <h2 class="text-xs font-semibold uppercase tracking-wide text-gray-500">
                Requirements
              </h2>
            </div>
            <div class="flex-1 overflow-y-auto px-5 py-4">
              <pre class="text-xs text-gray-700 whitespace-pre-wrap font-mono leading-relaxed"><%= @requirements %></pre>
            </div>

            <div class="border-t border-gray-100 px-5 py-4 space-y-1">
              <p class="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2">Progress</p>
              <.stage_row label="Requirements" done={true} />
              <.stage_row
                label="Clarifying questions"
                done={@status not in [:awaiting_clarification]}
                active={@status == :awaiting_clarification}
                review={true}
              />
              <.stage_row
                label="Writing PRD"
                done={@status not in [:awaiting_clarification, :awaiting_prd]}
                active={@status == :awaiting_prd}
              />
              <.stage_row
                label="PRD review"
                done={@status not in [:awaiting_clarification, :awaiting_prd, :awaiting_prd_review]}
                active={@status == :awaiting_prd_review}
                review={true}
              />
              <.stage_row
                label="Writing Tech Spec"
                done={@status in [:awaiting_spec_review, :awaiting_estimate, :complete]}
                active={@status == :awaiting_spec}
              />
              <.stage_row
                label="Tech Spec review"
                done={@status in [:awaiting_estimate, :complete]}
                active={@status == :awaiting_spec_review}
                review={true}
              />
              <.stage_row
                label="Generating estimate"
                done={@status == :complete}
                active={@status == :awaiting_estimate}
              />
            </div>
          </aside>

          <%!-- RIGHT: active step --%>
          <main class="flex-1 overflow-y-auto px-8 py-8 space-y-6">
            <%= if @status == :awaiting_clarification and @questions == [] do %>
              <.generating_indicator label="PM agent is analysing your requirements..." />
            <% end %>

            <%= if @status == :awaiting_clarification and @questions != [] do %>
              <.clarification_panel questions={@questions} />
            <% end %>

            <%= if @status == :awaiting_prd do %>
              <.generating_indicator label="PM agent is writing the PRD..." />
            <% end %>

            <%= if @status == :awaiting_spec do %>
              <.generating_indicator label="Technical Lead agent is writing the Tech Spec..." />
            <% end %>

            <%= if @status == :awaiting_estimate do %>
              <.generating_indicator label="Estimator agent is generating story points..." />
            <% end %>

            <%= if @status == :awaiting_prd_review and @prd do %>
              <.review_panel
                title="Review: Product Requirements Document"
                content={@prd}
                previous={@prd_previous}
                approve_event="approve_prd"
                reject_event="reject_prd"
              />
            <% end %>

            <%= if @status == :awaiting_spec_review and @tech_spec do %>
              <.review_panel
                title="Review: Technical Specification"
                content={@tech_spec}
                previous={@tech_spec_previous}
                approve_event="approve_spec"
                reject_event="reject_spec"
              />
            <% end %>

            <%= if @status == :complete do %>
              <div class="rounded-lg bg-green-50 border border-green-200 p-4 text-green-800 font-medium">
                ✓ Pipeline complete — all three documents saved.
              </div>
              <.doc_section
                title="Product Requirements Document"
                content={@prd}
                filename={@prd_filename}
              />
              <.doc_section
                title="Technical Specification"
                content={@tech_spec}
                filename={@tech_spec_filename}
              />
              <.doc_section
                title="Engineering Estimate"
                content={@estimate}
                filename={@estimate_filename}
              />
            <% end %>
          </main>
        </div>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  defp history_row(assigns) do
    ~H"""
    <div class="rounded-lg border border-gray-200 bg-gray-50 p-4 space-y-2">
      <div class="flex items-center justify-between gap-2">
        <.history_status_badge status={@run.status} />
        <span class="text-xs text-gray-400 shrink-0">{format_timestamp(@run.inserted_at)}</span>
      </div>

      <p class="text-sm text-gray-700 line-clamp-2">{@run.requirements_summary}</p>

      <div class="font-mono text-xs text-gray-400">{String.slice(@run.id, 0, 16)}…</div>

      <%= if @run.status == "complete" do %>
        <div class="flex gap-3 pt-1">
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
    """
  end

  defp history_status_badge(assigns) do
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
    <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{@bg} #{@text}"}>
      {@label}
    </span>
    """
  end

  defp format_timestamp(nil), do: ""

  defp format_timestamp(dt) do
    dt
    |> DateTime.from_naive!("Etc/UTC")
    |> Calendar.strftime("%d %b %Y, %H:%M")
  rescue
    _ -> ""
  end

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
          Answer these to help the PM agent write a better PRD. Leave blank if not applicable.
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
              class="w-full rounded-lg border text-gray-700 border-gray-300 p-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
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
            class="flex-1 rounded-lg border text-gray-700 border-gray-300 p-2 text-sm focus:outline-none focus:ring-2 focus:ring-amber-400"
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
