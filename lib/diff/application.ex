defmodule Diff.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Task.Supervisor, name: Diff.Tasks},
      # Start the PubSub system
      {Phoenix.PubSub, name: Diff.PubSub},
      # Start the endpoint when the application starts
      DiffWeb.Endpoint,
      # Starts a worker by calling: Diff.Worker.start_link(arg)
      # {Diff.Worker, arg},
      Diff.Package.Supervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Diff.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    DiffWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
