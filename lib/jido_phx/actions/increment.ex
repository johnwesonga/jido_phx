defmodule JidoPhx.Actions.Increment do
  use Jido.Action,
    name: "increment",
    schema: [amount: [type: :integer, default: 1]]

  def run(%{amount: amount}, context) do
    {:ok, %{count: (context.state[:count] || 0) + amount}}
  end
end
