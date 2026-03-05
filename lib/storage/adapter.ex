defmodule InvoiceStorage.Adapter do
  @moduledoc """
  Behavior specification for storage adapters.

  This module defines the contract that all storage implementations must follow.
  The default implementation uses JSON files on disk. Future implementations
  can support databases (PostgreSQL, MySQL, etc.) by implementing this behavior.

  ## Design Philosophy

  The adapter pattern allows:
  - Swapping storage backends without changing business logic
  - Testing with in-memory or file-based stores
  - Future database integration without API changes
  - Multiple storage backends running simultaneously

  ## Configuration

  Configure which adapter to use in `config/config.exs`:

      config :invoice_creation,
        storage_adapter: InvoiceStorage.FileAdapter,
        storage_config: [
          dir: "priv/storage"
        ]

  For database:

      config :invoice_creation,
        storage_adapter: InvoiceStorage.PostgresAdapter,
        storage_config: [
          repo: MyApp.Repo,
          pool_size: 10
        ]

  ## Adapter Responsibilities

  Each adapter must implement:
  - Single invoice persistence (save, load, delete, exists?)
  - Bulk year operations (save_all, load_all)
  - Year metadata (save_year_list, load_year_list)
  - Discovery (list_years, count)

  All functions follow the same error handling pattern:
  - Return `:ok` or `{:ok, result}` on success
  - Return `{:error, exception}` on failure

  ## Error Types

  Adapters should return exceptions from `InvoiceStorage.Error`:
  - `FileNotFound` - Resource doesn't exist
  - `IoError` - I/O operation failed
  - `InvalidJson` - Serialization error
  - `DecodeFailed` - Deserialization error
  - `ValidationFailed` - Domain object invalid

  ## Examples

  ### Implementing a Custom Adapter

      defmodule MyApp.DatabaseAdapter do
        @behaviour InvoiceStorage.Adapter

        def save(invoice) do
          # Write to database
        end

        def load(invoice_number, year) do
          # Read from database
        end

        # ... implement other required callbacks
      end

  ### Using the Adapter

      adapter = Application.fetch_env!(:invoice_creation, :storage_adapter)
      case adapter.save(invoice) do
        :ok -> {:ok, invoice}
        error -> error
      end
  """

  alias Invoice
  alias ListInvoiceYear

  # ============================================================================
  # Single Invoice Operations
  # ============================================================================

  @doc """
  Saves an individual invoice.

  ## Parameters
    - `invoice` - Invoice struct to persist

  ## Returns
    - `:ok` - Success
    - `{:error, exception}` - Failure

  ## Guarantees
    - Atomic: Either fully written or fails
    - Idempotent: Saving same invoice twice results in same state
    - Consistent: Data written to storage is validated
  """
  @callback save(invoice :: Invoice.t()) ::
              :ok | {:error, any()}

  @doc """
  Loads an invoice by invoice number and year.

  ## Parameters
    - `invoice_number` - Invoice identifier (e.g., "2024-0001")
    - `year` - Year the invoice belongs to

  ## Returns
    - `{:ok, Invoice.t()}` - Invoice found and loaded
    - `{:error, exception}` - Not found or error

  ## Guarantees
    - Loaded invoices are validated against domain rules
    - All fields are properly typed (dates, integers, strings)
    - Returns error if invoice is corrupted or invalid
  """
  @callback load(invoice_number :: String.t(), year :: pos_integer()) ::
              {:ok, Invoice.t()} | {:error, any()}

  @doc """
  Checks if an invoice exists.

  ## Parameters
    - `invoice_number` - Invoice identifier
    - `year` - Year to check

  ## Returns
    - `true` - Invoice exists
    - `false` - Invoice does not exist
  """
  @callback exists?(invoice_number :: String.t(), year :: pos_integer()) ::
              boolean()

  @doc """
  Deletes an invoice.

  ## Parameters
    - `invoice_number` - Invoice to delete
    - `year` - Year of invoice

  ## Returns
    - `:ok` - Deleted successfully
    - `{:error, exception}` - Failure (file not found, permission denied, etc.)

  ## Guarantees
    - Atomic: Either fully deleted or fails
    - Safe: Returns error if invoice doesn't exist (caller can decide action)
  """
  @callback delete(invoice_number :: String.t(), year :: pos_integer()) ::
              :ok | {:error, any()}

  # ============================================================================
  # Bulk Operations
  # ============================================================================

  @doc """
  Saves all invoices in a year list.

  ## Parameters
    - `list_year` - ListInvoiceYear with invoices to save

  ## Returns
    - `:ok` - All invoices saved
    - `{:error, exception}` - Operation failed (stops at first error)

  ## Guarantees
    - Atomic: Either all succeed or operation fails
    - Idempotent: Saving same year list twice results in same state
    - Ordered: Invoices saved in stable order
  """
  @callback save_all(list_year :: ListInvoiceYear.t()) ::
              :ok | {:error, any()}

  @doc """
  Loads all invoices for a specific year.

  ## Parameters
    - `year` - Year to load

  ## Returns
    - `{:ok, invoices_map}` - Map of invoice_number => Invoice
    - `{:error, exception}` - Failure

  ## Guarantees
    - Empty map returned if year has no invoices (not an error)
    - All returned invoices are validated and consistent
    - Keys match invoice numbers for easy lookup
  """
  @callback load_all(year :: pos_integer()) ::
              {:ok, map()} | {:error, any()}

  # ============================================================================
  # Year Metadata
  # ============================================================================

  @doc """
  Saves year metadata (year, next_id).

  Metadata includes tracking information needed to generate next invoice number.

  ## Parameters
    - `list_year` - ListInvoiceYear with metadata to save

  ## Returns
    - `:ok` - Metadata saved
    - `{:error, exception}` - Failure
  """
  @callback save_year_list(list_year :: ListInvoiceYear.t()) ::
              :ok | {:error, any()}

  @doc """
  Loads year metadata.

  Used to reconstruct ListInvoiceYear with current next_id.

  ## Parameters
    - `year` - Year to load metadata for

  ## Returns
    - `{:ok, ListInvoiceYear.t()}` - Metadata loaded (invoices will be empty)
    - `{:error, exception}` - Failure
  """
  @callback load_year_list(year :: pos_integer()) ::
              {:ok, ListInvoiceYear.t()} | {:error, any()}

  # ============================================================================
  # Discovery & Utility
  # ============================================================================

  @doc """
  Lists all years with stored invoices.

  ## Returns
    - `{:ok, [pos_integer()]}` - List of years, may be empty
    - `{:error, exception}` - Operation failed
  """
  @callback list_years() ::
              {:ok, [pos_integer()]} | {:error, any()}

  @doc """
  Counts invoices in a specific year.

  ## Parameters
    - `year` - Year to count

  ## Returns
    - `{:ok, non_neg_integer()}` - Number of invoices
    - `{:error, exception}` - Operation failed
  """
  @callback count(year :: pos_integer()) ::
              {:ok, non_neg_integer()} | {:error, any()}

  # ============================================================================
  # Adapter Discovery
  # ============================================================================

  @doc """
  Gets the configured storage adapter.

  ## Returns
    - Adapter module (e.g., InvoiceStorage.FileAdapter)
  """
  @spec get_adapter() :: module()
  def get_adapter() do
    Application.get_env(:invoice_creation, :storage_adapter, InvoiceStorage.FileAdapter)
  end

  @doc """
  Gets adapter configuration.

  ## Returns
    - Configuration keyword list for the adapter
  """
  @spec get_config() :: keyword()
  def get_config() do
    Application.get_env(:invoice_creation, :storage_config, [])
  end
end
