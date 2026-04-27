defmodule JidoPhx.Actions.Reset do
  use Jido.Action,
    name: "reset",
    schema: []

  def run(_params, _context) do
    {:ok, %{count: 0}}
  end
end
