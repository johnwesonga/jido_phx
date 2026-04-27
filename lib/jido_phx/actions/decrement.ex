defmodule JidoPhx.Actions.Decrement do
  use Jido.Action,
    name: "decrement",
    schema: [amount: [type: :integer, default: 1]]

  def run(%{amount: amount}, context) do
    {:ok, %{count: (context.state[:count] || 0) - amount}}
  end
end
