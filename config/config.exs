import Config

config :invoice_creation,
  storage_fir: "priv/storage"

# Database configuration
config :invoice_creation, InvoiceCreation.Repo,
  username: System.get_env("DATABASE_USER", "postgres"),
  password: System.get_env("DATABASE_PASSWORD", "postgres"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  database: System.get_env("DATABASE_NAME", "invoice_creation_dev"),
  stacktrace: true,
  show_sensitive_data_on_error: true

config :invoice_creation, ecto_repos: [InvoiceCreation.Repo]

if config_env() == :test do
  # config :mix_test_watch,
    # clear: true
end

import_config("#{config_env()}.exs")

