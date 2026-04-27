defmodule JidoPhx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      JidoPhxWeb.Telemetry,
      JidoPhx.Repo,
      JidoPhx.Jido,
      {Jido.AgentServer,
       [
         agent: JidoPhx.Agents.CounterAgent,
         id: "counter",
         jido: JidoPhx.Jido
       ]},
      {DNSCluster, query: Application.get_env(:jido_phx, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: JidoPhx.PubSub},
      # Start a worker by calling: JidoPhx.Worker.start_link(arg)
      # {JidoPhx.Worker, arg},
      # Start to serve requests, typically the last entry
      JidoPhxWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JidoPhx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JidoPhxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
