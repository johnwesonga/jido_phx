defmodule JidoPhx.Agents.CounterAgent do
  use Jido.Agent,
    name: "counter",
    description: "A counter with PubSub broadcasting",
    schema: [
      count: [type: :integer, default: 0]
    ],
    signal_routes: [
      {"counter.increment", JidoPhx.Actions.Increment},
      {"counter.decrement", JidoPhx.Actions.Decrement},
      {"counter.reset", JidoPhx.Actions.Reset}
    ]
end
