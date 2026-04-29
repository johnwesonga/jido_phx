defmodule JidoPhx.ProductAgent.Actions.PersistStatus do
  @moduledoc """
  Shared helper called at the top of coordinator actions that change status.

  Usage:
    PersistStatus.call(context.state.run_id, :awaiting_prd_review)
  """
  require Logger
  alias JidoPhx.ProductAgent.PipelineRuns

  def call(run_id, status) when is_binary(run_id) do
    case PipelineRuns.update_status(run_id, status) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "[PersistStatus] failed to update #{run_id} → #{status}: #{inspect(reason)}"
        )

        # non-fatal — pipeline continues
        :ok
    end
  end

  # guard against nil run_id during dev
  def call(nil, _status), do: :ok
end
