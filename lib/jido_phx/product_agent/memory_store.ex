defmodule JidoPhx.ProductAgent.MemoryStore do
  @moduledoc """
  Stores and retrieves pipeline run memory via pgvector similarity search.

  On pipeline completion, call `store/2` to embed and persist the requirements.
  At pipeline start, call `recall/2` to retrieve the most similar past runs
  so the PM agent can use them as context.
  """
  import Ecto.Query
  import Pgvector.Ecto.Query
  require Logger

  alias JidoPhx.Repo
  alias JidoPhx.ProductAgent.{PipelineRun, Embeddings}

  # cosine distance — lower = more similar
  @similarity_threshold 0.3
  @max_results 3

  # ---------------------------------------------------------------------------
  # Write
  # ---------------------------------------------------------------------------

  @doc """
  Embed the requirements for a completed pipeline run and store the vector.
  Call this from EstimateCompleteAction after the pipeline finishes.
  """
  @spec store(String.t(), String.t()) :: :ok
  def store(run_id, requirements) do
    Logger.info("[MemoryStore] embedding #{byte_size(requirements)} bytes for run #{run_id}")

    case Embeddings.embed(requirements) do
      {:ok, embedding} ->
        from(r in PipelineRun, where: r.id == ^run_id)
        |> Repo.update_all(set: [embedding: Pgvector.new(embedding)])

        Logger.info("[MemoryStore] stored embedding for run #{run_id}")
        :ok

      {:error, reason} ->
        Logger.warning("[MemoryStore] failed to embed run #{run_id}: #{inspect(reason)}")
        # non-fatal
        :ok
    end
  end

  @doc """
  Retrieve the top #{@max_results} most similar completed pipeline runs
  to the given requirements text.

  Returns a list of maps with :requirements_summary, :prd, :tech_spec keys.
  Returns [] if embeddings are unavailable or no similar runs exist.
  """
  @spec recall(String.t(), String.t()) :: list(map())
  def recall(current_run_id, requirements) do
    case Embeddings.embed(requirements) do
      {:ok, embedding} ->
        vec = Pgvector.new(embedding)

        Repo.all(
          from r in PipelineRun,
            where: r.status == "complete",
            where: r.id != ^current_run_id,
            where: not is_nil(r.embedding),
            where: cosine_distance(r.embedding, ^vec) < @similarity_threshold,
            order_by: cosine_distance(r.embedding, ^vec),
            limit: @max_results,
            select: %{
              requirements_summary: r.requirements_summary,
              prd: r.prd,
              tech_spec: r.tech_spec
            }
        )

      {:error, reason} ->
        Logger.warning("[MemoryStore] recall failed: #{inspect(reason)}")
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Format for prompt injection
  # ---------------------------------------------------------------------------

  @doc """
  Format recalled runs as a concise context block for injection into
  the PM agent's system prompt. Returns nil if no past runs found.
  """
  @spec format_context(list(map())) :: String.t() | nil
  def format_context([]), do: nil

  def format_context(runs) do
    entries =
      runs
      |> Enum.with_index(1)
      |> Enum.map(fn {run, idx} ->
        """
        ### Past Product #{idx}
        Requirements: #{run.requirements_summary}
        """
      end)
      |> Enum.join("\n")

    """
    ## Similar products your organisation has built before

    Use these as context for the current requirements — adopt consistent
    terminology and structure where appropriate, and avoid asking questions
    already addressed in similar past products.

    #{entries}
    """
  end
end
