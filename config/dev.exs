import Config

config :invoice_creation, InvoiceCreation.Repo,
  database: "invoice_creation_dev",
  pool_size: 10,
  migration_primary_key: [type: :uuid]
