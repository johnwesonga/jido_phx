defmodule JidoPhx.Repo.Migrations.FixEmbeddingDimensions do
  use Ecto.Migration

  def up do
    # Drop the existing column and recreate with correct dimensions
    alter table(:pipeline_runs) do
      remove :embedding
    end

    alter table(:pipeline_runs) do
      add :embedding, :vector, size: 768
    end

    # Recreate the HNSW index with correct dimensions
    create index(:pipeline_runs, ["embedding vector_cosine_ops"],
             using: :hnsw,
             name: :pipeline_runs_embedding_hnsw_index
           )
  end

  def down do
    drop index(:pipeline_runs, [:embedding], name: :pipeline_runs_embedding_hnsw_index)

    alter table(:pipeline_runs) do
      remove :embedding
      add :embedding, :vector, size: 1536
    end
  end
end
