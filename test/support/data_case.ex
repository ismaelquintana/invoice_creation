defmodule InvoiceCreation.DataCase do
  @moduledoc """
  This module provides test helpers for tests that interact with the database.

  It defines a test setup that can be used by any test that needs access to
  a clean database. The database is configured to use SQLite in-memory for tests,
  ensuring fast, isolated test execution.

  ## Usage

  Include this module in your test file:

      defmodule MyTest do
        use InvoiceCreation.DataCase

        test "example test" do
          # Database is ready for use
        end
      end

  ## Database Isolation

  Each test runs in a transaction that is rolled back after the test completes.
  This ensures:
  - Fast test execution (in-memory SQLite)
  - Complete isolation between tests (no shared state)
  - Clean database for each test
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias InvoiceCreation.Repo

      import Ecto
      import Ecto.Query
      import InvoiceCreation.DataCase
    end
  end

  setup tags do
    # Start the repository in a transaction if running in async mode
    # For tests that need database access
    if tags[:async] do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(InvoiceCreation.Repo)
    else
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(InvoiceCreation.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(InvoiceCreation.Repo, {:shared, self()})
    end

    :ok
  end

  @doc """
  A helper that transforms map(s) with atom keys into idempotent data.

  Used for converting params to formats accepted by schema changesets.
  """
  def stringify_keys(nil), do: nil

  def stringify_keys(params) when is_map(params) do
    Enum.into(params, %{}, fn {key, value} ->
      {to_string(key), stringify_keys(value)}
    end)
  end

  def stringify_keys([head | tail]) do
    [stringify_keys(head) | stringify_keys(tail)]
  end

  def stringify_keys(value), do: value
end
