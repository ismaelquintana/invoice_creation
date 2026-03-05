import Config

# For tests, we'll skip database tests and focus on CSV export
# The Postgres adapter tests require a running PostgreSQL instance
# In a CI environment, you would set up a test database or use Docker

# Configuration is kept at defaults from config.exs for compatibility
# If you want to run all tests including database tests, set up PostgreSQL:
# 1. Create a test database: createdb invoice_creation_test
# 2. Run migrations: mix ecto.migrate --repo InvoiceCreation.Repo
