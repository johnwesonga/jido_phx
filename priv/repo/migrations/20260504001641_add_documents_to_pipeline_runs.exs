defmodule JidoPhx.Repo.Migrations.AddDocumentsToPipelineRuns do
  use Ecto.Migration

  def change do
    alter table(:pipeline_runs) do
      add :prd, :text
      add :tech_spec, :text
      add :estimate, :text
    end
  end
end
