defmodule JidoPhx.Repo do
  use Ecto.Repo,
    otp_app: :jido_phx,
    adapter: Ecto.Adapters.Postgres
end
