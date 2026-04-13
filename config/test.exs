import Config

# Test configuration
# SQLite is used for testing to avoid external dependencies
config :invoice_creation, InvoiceCreation.Repo,
  database: "test_invoice_creation.db",
  adapter: Ecto.Adapters.SQLite3,
  pool: Ecto.Adapters.SQL.Sandbox,
  # Show sensitive data in test errors for debugging
  show_sensitive_data_on_error: true
