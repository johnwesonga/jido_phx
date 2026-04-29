defmodule JidoPhx.Repo.Migrations.CreatePipelineRuns do
  use Ecto.Migration

  def change do
    create table(:pipeline_runs, primary_key: false) do
      # run_id
      add :id, :string, primary_key: true
      add :status, :string, null: false, default: "awaiting_clarification"
      add :requirements, :text, null: false
      # first 200 chars
      add :requirements_summary, :string
      add :prd_filename, :string
      add :tech_spec_filename, :string
      add :estimate_filename, :string

      timestamps()
    end

    create index(:pipeline_runs, [:inserted_at])
    create index(:pipeline_runs, [:status])
  end
end
