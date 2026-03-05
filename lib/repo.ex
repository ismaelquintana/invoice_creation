defmodule InvoiceCreation.Repo do
  use Ecto.Repo,
    otp_app: :invoice_creation,
    adapter: Ecto.Adapters.Postgres

  @moduledoc """
  The Ecto Repo for InvoiceCreation.

  This is the main database interface for the application. It handles all database
  operations through Ecto schemas and changesets.

  ## Environment Variables

  The repo uses the following environment variables for configuration:
  - DATABASE_USER: PostgreSQL user (default: "postgres")
  - DATABASE_PASSWORD: PostgreSQL password (default: "postgres")
  - DATABASE_HOST: PostgreSQL host (default: "localhost")
  - DATABASE_NAME: PostgreSQL database name (default: "invoice_creation_dev")
  - DATABASE_URL: Full database URL (production only, supersedes other vars)
  - POOL_SIZE: Connection pool size (default: 10)

  ## Configuration

  The repo is configured in config/config.exs and environment-specific configs:
  - config/dev.exs: Development database settings
  - config/test.exs: Test database settings (uses SQLite in-memory)
  - config/prod.exs: Production database settings

  ## Usage

  ```elixir
  # Create a new invoice record
  {:ok, invoice} = InvoiceCreation.Repo.insert(invoice_changeset)

  # Fetch an invoice by ID
  invoice = InvoiceCreation.Repo.get!(InvoiceCreation.Schemas.InvoiceRecord, id)

  # Update an invoice
  {:ok, updated} = InvoiceCreation.Repo.update(invoice_changeset)

  # Delete an invoice
  {:ok, deleted} = InvoiceCreation.Repo.delete(invoice)
  ```
  """
end
