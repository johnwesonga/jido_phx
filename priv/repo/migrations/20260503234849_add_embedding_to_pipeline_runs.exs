defmodule JidoPhx.Repo.Migrations.AddEmbeddingToPipelineRuns do
  use Ecto.Migration

  def change do
    alter table(:pipeline_runs) do
      # 1536 dimensions = OpenAI text-embedding-3-small / LM Studio nomic-embed-text
      # Change to 768 if using a smaller local model
      add :embedding, :vector, size: 1536
    end

    # HNSW index for fast approximate nearest-neighbour search on cosine distance
    create index(:pipeline_runs, ["embedding vector_cosine_ops"],
             using: :hnsw,
             name: :pipeline_runs_embedding_hnsw_index
           )
  end
end
