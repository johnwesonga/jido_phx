defmodule JidoPhx.ProductAgent.PipelineRun do
  @moduledoc """
  Ecto schema representing a single pipeline execution.

  Created when the pipeline starts, updated at each status transition,
  finalised with file paths when :complete.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime]

  schema "pipeline_runs" do
    field :status, :string
    field :requirements, :string
    field :requirements_summary, :string
    field :prd_filename, :string
    field :tech_spec_filename, :string
    field :estimate_filename, :string

    timestamps()
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :id,
      :status,
      :requirements,
      :requirements_summary,
      :prd_filename,
      :tech_spec_filename,
      :estimate_filename
    ])
    |> validate_required([:id, :status, :requirements])
    |> validate_length(:requirements_summary, max: 200)
  end
end
