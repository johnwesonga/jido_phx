defmodule JidoPhx.ProductAgent.Pipeline do
  @moduledoc """
  Public entry point for the signal-based PM → TL pipeline.

  The pipeline is driven by human decisions at each pause point:
  - Clarifying questions
  - PRD review (approve / reject with feedback)
  - Tech Spec review (approve / reject with feedback)
  """

  alias JidoPhx.ProductAgent.Agents.CoordinatorAgent

  # ---------------------------------------------------------------------------
  # Start
  # ---------------------------------------------------------------------------

  @doc """
  Start the coordinator and fire the initial `pipeline.start` signal.
  Returns `{:ok, coordinator_pid}` which the LiveView holds.
  """
  @spec start(String.t(), keyword()) :: {:ok, pid()} | {:error, any()}
  def start(requirements, opts \\ []) do
    run_id = Keyword.get(opts, :run_id, generate_run_id())

    with {:ok, pid} <- start_coordinator(run_id),
         :ok <- send_signal(pid, "pipeline.start", %{requirements: requirements, run_id: run_id}) do
      {:ok, pid}
    end
  end

  # ---------------------------------------------------------------------------
  # Clarifications
  # ---------------------------------------------------------------------------

  @doc """
  Submit answers to the current round of clarifying questions.
  `answers` is a map of %{question_string => answer_string}.
  """
  @spec provide_clarifications(pid(), map()) :: :ok | {:error, any()}
  def provide_clarifications(coordinator_pid, answers) do
    with {:ok, pm_pid} <- get_child_pid(coordinator_pid, :pm_agent) do
      send_signal(coordinator_pid, "pipeline.clarifications_provided", %{
        answers: answers,
        pm_pid: pm_pid
      })
    end
  end

  # ---------------------------------------------------------------------------
  # PRD review
  # ---------------------------------------------------------------------------

  @doc "Approve the PRD — spawns the TL child to begin spec generation."
  @spec approve_prd(pid()) :: :ok | {:error, any()}
  def approve_prd(coordinator_pid) do
    send_signal(coordinator_pid, "prd.approved", %{})
  end

  @doc "Reject the PRD with feedback — re-dispatches to PM for revision."
  @spec reject_prd(pid(), String.t()) :: :ok | {:error, any()}
  def reject_prd(coordinator_pid, feedback \\ "") do
    with {:ok, pm_pid} <- get_child_pid(coordinator_pid, :pm_agent) do
      send_signal(coordinator_pid, "prd.rejected", %{feedback: feedback, pm_pid: pm_pid})
    end
  end

  # ---------------------------------------------------------------------------
  # Tech Spec review
  # ---------------------------------------------------------------------------

  @doc "Approve the Tech Spec — writes files and marks pipeline complete."
  @spec approve_spec(pid()) :: :ok | {:error, any()}
  def approve_spec(coordinator_pid) do
    send_signal(coordinator_pid, "spec.approved", %{})
  end

  @doc "Reject the Tech Spec with feedback — re-dispatches to TL for revision."
  @spec reject_spec(pid(), String.t()) :: :ok | {:error, any()}
  def reject_spec(coordinator_pid, feedback \\ "") do
    with {:ok, tl_pid} <- get_child_pid(coordinator_pid, :tl_agent) do
      send_signal(coordinator_pid, "spec.rejected", %{feedback: feedback, tl_pid: tl_pid})
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @doc false
  def start_coordinator(run_id) do
    Jido.start_agent(JidoPhx.Jido, CoordinatorAgent, id: "coordinator-#{run_id}")
  end

  @doc false
  def generate_run_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp send_signal(pid, type, data) do
    signal = Jido.Signal.new!(type, data, source: "/pipeline")

    case Jido.AgentServer.call(pid, signal) do
      {:ok, _} -> :ok
      err -> err
    end
  end

  defp get_child_pid(coordinator_pid, child_tag) do
    case Jido.AgentServer.state(coordinator_pid) do
      {:ok, %{children: children}} ->
        case Map.fetch(children, child_tag) do
          {:ok, %{pid: pid}} -> {:ok, pid}
          :error -> {:error, {:child_not_found, child_tag}}
        end

      _ ->
        {:error, :coordinator_state_unavailable}
    end
  end
end
