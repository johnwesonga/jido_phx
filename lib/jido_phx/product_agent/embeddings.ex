defmodule JidoPhx.ProductAgent.Embeddings do
  @moduledoc """
  Generates text embeddings via an OpenAI-compatible API.

  Works with:
  - LM Studio (local testing) — set EMBEDDINGS_BASE_URL=http://localhost:1234/v1
    and load a model like nomic-embed-text or all-minilm in LM Studio.
  - OpenAI — set EMBEDDINGS_BASE_URL=https://api.openai.com/v1
    and EMBEDDINGS_API_KEY to your OpenAI key.

  Config in config/runtime.exs:
    config :jido_phx, :embeddings,
      base_url: System.get_env("EMBEDDINGS_BASE_URL", "http://localhost:1234/v1"),
      api_key:  System.get_env("EMBEDDINGS_API_KEY", "lm-studio"),
      model:    System.get_env("EMBEDDINGS_MODEL", "nomic-embed-text")

  The vector size (1536) must match the model output dimensions and the
  pgvector column size in the migration. Common sizes:
    - nomic-embed-text (LM Studio):        768  → change migration to size: 768
    - all-minilm (LM Studio):             384  → change migration to size: 384
    - text-embedding-3-small (OpenAI):    1536 → default
    - text-embedding-ada-002 (OpenAI):    1536 → default
  """

  require Logger

  @default_base_url "http://localhost:1234/v1"
  @default_model "nomic-embed-text"
  @default_api_key "lm-studio"

  @doc """
  Embed a text string. Returns `{:ok, [float]}` or `{:error, reason}`.
  """
  @spec embed(String.t()) :: {:ok, list(float())} | {:error, any()}
  def embed(text) when is_binary(text) do
    config = Application.get_env(:jido_phx, :embeddings, [])
    base_url = Keyword.get(config, :base_url, @default_base_url)
    model = Keyword.get(config, :model, @default_model)
    api_key = Keyword.get(config, :api_key, @default_api_key)
    url = "#{base_url}/embeddings"

    body =
      Jason.encode!(%{
        model: model,
        input: text
      })

    case Req.post(url,
           body: body,
           headers: [
             {"content-type", "application/json"},
             {"authorization", "Bearer #{api_key}"}
           ],
           receive_timeout: 30_000
         ) do
      {:ok, %{status: 200, body: %{"data" => [%{"embedding" => embedding} | _]}}} ->
        {:ok, embedding}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[Embeddings] unexpected response status=#{status} body=#{inspect(body)}")
        {:error, {:unexpected_response, status}}

      {:error, reason} ->
        Logger.error("[Embeddings] request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Embed text, raising on failure."
  @spec embed!(String.t()) :: list(float())
  def embed!(text) do
    case embed(text) do
      {:ok, embedding} -> embedding
      {:error, reason} -> raise "Embeddings.embed! failed: #{inspect(reason)}"
    end
  end
end
