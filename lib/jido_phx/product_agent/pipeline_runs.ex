defmodule JidoPhx.ProductAgent.PipelineRuns do
  @moduledoc """
  Context for pipeline run persistence.

  Called from actions to record and update pipeline state.
  Called from the history LiveView to list past runs.
  """
  import Ecto.Query

  alias JidoPhx.Repo
  alias JidoPhx.ProductAgent.{PipelineRun, MemoryStore}

  @summary_length 200
  require Logger

  # ---------------------------------------------------------------------------
  # Write
  # ---------------------------------------------------------------------------

  @doc "Create a new pipeline run record when the pipeline starts."
  def create(run_id, requirements) do
    %PipelineRun{}
    |> PipelineRun.changeset(%{
      id: run_id,
      status: "awaiting_clarification",
      requirements: requirements,
      requirements_summary: summarise(requirements)
    })
    |> Repo.insert()
  end

  @doc "Update the status of an existing run."
  def update_status(run_id, status) when is_atom(status) do
    update_status(run_id, Atom.to_string(status))
  end

  def update_status(run_id, status) do
    case Repo.get(PipelineRun, run_id) do
      nil ->
        {:error, :not_found}

      run ->
        run
        |> PipelineRun.changeset(%{status: status})
        |> Repo.update()
    end
  end

  @doc "Mark a run complete with all output filenames."
  def complete(
        run_id,
        prd,
        tech_spec,
        estimate,
        prd_filename,
        tech_spec_filename,
        estimate_filename
      ) do
    case Repo.get(PipelineRun, run_id) do
      nil ->
        {:error, :not_found}

      run ->
        result =
          run
          |> PipelineRun.changeset(%{
            status: "complete",
            prd: prd,
            tech_spec: tech_spec,
            estimate: estimate,
            prd_filename: prd_filename,
            tech_spec_filename: tech_spec_filename,
            estimate_filename: estimate_filename
          })
          |> Repo.update()

        # Fire-and-forget embedding in a Task so it doesn't block the pipeline
        Task.start(fn ->
          Logger.info("[PipelineRuns] starting background embedding for #{run_id}")
          MemoryStore.store(run_id, run.requirements)
        end)

        result
    end
  end

  # ---------------------------------------------------------------------------
  # Read
  # ---------------------------------------------------------------------------

  @doc "List all pipeline runs, most recent first."
  def list(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    PipelineRun
    |> order_by([r], desc: r.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Get a single pipeline run by run_id."
  def get(run_id), do: Repo.get(PipelineRun, run_id)

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp summarise(requirements) do
    requirements
    |> String.trim()
    |> String.slice(0, @summary_length)
  end
end
