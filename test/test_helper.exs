ExUnit.start()
Faker.start()

# Load test support modules
Code.require_file("support/test_helpers.ex", __DIR__)
Code.require_file("support/data_case.ex", __DIR__)
Code.require_file("support/factory.ex", __DIR__)

# Start Ecto sandbox for database tests (only if needed)
# The Repo may already be started by the Application supervision tree
case Mix.env() do
  :test ->
    :ok

  _ ->
    case InvoiceCreation.Repo.start_link(pool: Ecto.Adapters.SQL.Sandbox) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
      error -> error
    end
end
