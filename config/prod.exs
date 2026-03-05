import Config

config :invoice_creation, InvoiceCreation.Repo,
  ssl: true,
  url: System.fetch_env!("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  migration_primary_key: [type: :uuid]
