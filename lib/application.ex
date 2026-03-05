defmodule InvoiceCreation.Application do
  @moduledoc """
  The InvoiceCreation Application supervisor.

  Starts the Repo supervision tree along with any other required services.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = children_for_env()

    opts = [strategy: :one_for_one, name: InvoiceCreation.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Only start Repo for dev/prod, not test
  # Tests handle database setup explicitly
  defp children_for_env do
    case Mix.env() do
      :test -> []
      _ -> [{InvoiceCreation.Repo, []}]
    end
  end
end
