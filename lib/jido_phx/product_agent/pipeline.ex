defmodule JidoPhx.ProductAgent.Pipeline do
  @moduledoc """
  Public entry point for the signal-based PM → TL pipeline.

  The pipeline is driven by human review decisions — it does not run
  to completion automatically. Call `start/2` to kick things off, then
  drive it forward with `approve_prd/1`, `reject_prd/2`,
  `approve_spec/1`, and `reject_spec/2` in response to user actions.
  """
  alias JidoPhx.ProductAgent.Agents.CoordinatorAgent
  # ---------------------------------------------------------------------------
  # Start
  # ---------------------------------------------------------------------------

  @doc """
  Start the coordinator and fire the initial `pipeline.start` signal.
  Returns `{:ok, coordinator_pid}` which the LiveView holds and passes
  to the approve/reject helpers below.
  """
  @spec start(String.t(), keyword()) :: {:ok, pid()} | {:error, any()}
  def start(requirements, opts \\ []) do
    run_id = Keyword.get(opts, :run_id, generate_run_id())

    with {:ok, pid} <- start_coordinator(run_id),
         :ok <- send_signal(pid, "pipeline.start", %{requirements: requirements, run_id: run_id}) do
      {:ok, pid}
    end
  end

  def start_coordinator(run_id) do
    Jido.start_agent(JidoPhx.Jido, CoordinatorAgent, id: "coordinator-#{run_id}")
  end

  def send_pipeline_start(pid, requirements, run_id) do
    signal =
      Jido.Signal.new!(
        "pipeline.start",
        %{requirements: requirements, run_id: run_id},
        source: "/pipeline"
      )

    case Jido.AgentServer.call(pid, signal) do
      {:ok, _} -> :ok
      err -> err
    end
  end

  def generate_run_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  # ---------------------------------------------------------------------------
  # Review decisions
  # ---------------------------------------------------------------------------

  @doc "Approve the PRD — coordinator will spawn the TL child and proceed to spec generation."
  @spec approve_prd(pid()) :: :ok | {:error, any()}
  def approve_prd(coordinator_pid) do
    send_signal(coordinator_pid, "prd.approved", %{})
  end

  @doc "Reject the PRD with feedback — coordinator re-dispatches to the PM child for revision."
  @spec reject_prd(pid(), String.t()) :: :ok | {:error, any()}
  def reject_prd(coordinator_pid, feedback \\ "") do
    with {:ok, pm_pid} <- get_child_pid(coordinator_pid, :pm_agent) do
      send_signal(coordinator_pid, "prd.rejected", %{feedback: feedback, pm_pid: pm_pid})
    end
  end

  @doc "Approve the Tech Spec — coordinator writes files and marks the pipeline complete."
  @spec approve_spec(pid()) :: :ok | {:error, any()}
  def approve_spec(coordinator_pid) do
    send_signal(coordinator_pid, "spec.approved", %{})
  end

  @doc "Reject the Tech Spec with feedback — coordinator re-dispatches to the TL child for revision."
  @spec reject_spec(pid(), String.t()) :: :ok | {:error, any()}
  def reject_spec(coordinator_pid, feedback \\ "") do
    with {:ok, tl_pid} <- get_child_pid(coordinator_pid, :tl_agent) do
      send_signal(coordinator_pid, "spec.rejected", %{feedback: feedback, tl_pid: tl_pid})
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

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

  @poll_interval_ms 500

  defp wait_for_completion(pid, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    poll(pid, deadline)
  end

  defp poll(pid, deadline) do
    if System.monotonic_time(:millisecond) > deadline do
      {:error, :timeout}
    else
      case Jido.AgentServer.state(pid) do
        {:ok, %{agent: %{state: %{status: :complete} = state}}} ->
          {:ok, state}

        _ ->
          Process.sleep(@poll_interval_ms)
          poll(pid, deadline)
      end
    end
  end
end
