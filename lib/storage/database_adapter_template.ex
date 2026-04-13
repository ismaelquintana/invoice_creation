defmodule InvoiceStorage.DatabaseAdapterTemplate do
  @moduledoc """
  Template for implementing a database-backed storage adapter.

  This is a reference implementation showing how to create a database adapter
  that implements the `InvoiceStorage.Adapter` behavior. Use this as a guide to
  create adapters for custom databases or ORMs.

  ## Usage

  To implement a real database adapter:
  1. Copy this file to `lib/storage/my_database_adapter.ex`
  2. Replace database calls with your actual database library calls
  3. Configure in `config/config.exs`:

      config :invoice_creation,
        storage_adapter: InvoiceStorage.MyDatabaseAdapter,
        storage_config: [
          repo: MyApp.Repo
        ]

  4. Delete this template file

  ## Implementation Patterns

  This template demonstrates:
  - How to implement all Adapter behavior callbacks
  - Proper error handling with custom error types
  - Data conversion between Invoice domain models and database records
  - Transaction handling for atomicity (save_all)
  - Query patterns for filtering and sorting

  ## Design Considerations

  - Use transactions for atomicity (save_all should be one transaction)
  - Index on (number, date.year) for fast lookups
  - Keep year metadata separate for quick next_id lookups
  - Store dates as DATE type (ISO 8601 compatible)
  - Use NOT NULL constraints for required fields
  - Add CHECK constraints for validation rules (e.g., vat >= 0)
  """

  @behaviour InvoiceStorage.Adapter

  alias Invoice
  alias ListInvoiceYear
  alias InvoiceStorage.Error

  # ============================================================================
  # Single Invoice Operations
  # ============================================================================

  @doc """
  Saves a single invoice to the database.

  Converts the Invoice domain model to database records and persists them.
  Handles both new invoices (insert) and updates to existing invoices.

  ## Implementation Notes
  - Create an invoice record from the Invoice struct
  - Create item records for each item
  - Use cascading deletes for old items when updating
  - Catch database constraint violations and convert to domain errors
  """
  @impl InvoiceStorage.Adapter
  def save(%Invoice{} = _invoice) do
    # Example implementation outline:
    # 1. Convert invoice to database record
    # 2. Insert or update in database
    # 3. Handle constraint violations:
    #    - Duplicate number+year -> return domain-friendly error
    #    - Invalid field values -> return validation error
    # 4. Return :ok on success, {:error, exception} on failure
    #
    # Pseudocode:
    #   with {:ok, _record} <- insert_or_update_invoice(invoice),
    #        {:ok, _items} <- save_items(invoice) do
    #     :ok
    #   else
    #     {:error, reason} -> {:error, convert_db_error(reason)}
    #   end

    {:error,
     Error.ValidationError.exception(
       message: "save/1 not implemented in template. Copy to create a real adapter."
     )}
  end

  @doc """
  Loads a single invoice from the database.

  Queries by invoice number and year, reconstructs the Invoice struct with all items.
  """
  @impl InvoiceStorage.Adapter
  def load(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    # Example implementation outline:
    # 1. Query database by (number, year)
    # 2. If not found, return FileNotFound error
    # 3. Convert database record to Invoice struct
    # 4. Load associated items
    # 5. Return {:ok, invoice} or {:error, exception}
    #
    # Pseudocode:
    #   case query_by_number_and_year(invoice_number, year) do
    #     nil -> {:error, FileNotFound.exception(...)}
    #     record -> {:ok, invoice_from_record(record)}
    #   end

    {:error,
     Error.FileNotFound.exception(
       message: "load/2 not implemented in template. Copy to create a real adapter."
     )}
  end

  @doc """
  Checks if an invoice exists in the database.

  Returns true/false without loading the full record (efficient).
  """
  @impl InvoiceStorage.Adapter
  def exists?(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    # Example implementation outline:
    # Use a COUNT query for efficiency:
    #   repo.exists?(from r in InvoiceRecord,
    #     where: r.number == ^invoice_number and year(r.date) == ^year)

    false
  end

  @doc """
  Deletes a single invoice from the database.

  Removes the invoice and all associated items (cascading delete).
  """
  @impl InvoiceStorage.Adapter
  def delete(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    # Example implementation outline:
    # 1. Delete all items for this invoice first (or use cascading delete)
    # 2. Delete the invoice record
    # 3. Return :ok if deleted, error if not found
    #
    # Pseudocode:
    #   case repo.delete_all(from r in InvoiceRecord,
    #         where: r.number == ^invoice_number and year(r.date) == ^year) do
    #     {0, _} -> {:error, FileNotFound.exception(...)}
    #     {_count, _} -> :ok
    #   end

    {:error,
     Error.ValidationError.exception(
       message: "delete/2 not implemented in template. Copy to create a real adapter."
     )}
  end

  # ============================================================================
  # Batch Invoice Operations
  # ============================================================================

  @doc """
  Saves all invoices in a ListInvoiceYear as a transaction.

  All invoices are saved atomically - either all succeed or all fail.
  This is critical for maintaining consistency.
  """
  @impl InvoiceStorage.Adapter
  def save_all(%ListInvoiceYear{} = _list_year) do
    # Example implementation outline:
    # 1. Start a database transaction
    # 2. Save each invoice in the list
    # 3. If any fail, rollback entire transaction
    # 4. Return :ok or {:error, exception}
    #
    # Pseudocode:
    #   @repo.transaction(fn ->
    #     list_year.invoices
    #     |> Enum.each(fn {_number, invoice} ->
    #       case save(invoice) do
    #         :ok -> :ok
    #         {:error, reason} -> raise reason
    #       end
    #     end)
    #   end)
    #   |> case do
    #     {:ok, :ok} -> :ok
    #     {:error, reason} -> {:error, reason}
    #   end

    {:error,
     Error.ValidationError.exception(
       message: "save_all/1 not implemented in template. Copy to create a real adapter."
     )}
  end

  @doc """
  Loads all invoices for a specific year.

  Returns a map keyed by invoice number for consistent structure.
  """
  @impl InvoiceStorage.Adapter
  def load_all(year) when is_integer(year) do
    # Example implementation outline:
    # 1. Query all invoices with matching year
    # 2. Preload items for each invoice
    # 3. Convert to Invoice structs
    # 4. Build map: {number => invoice}
    # 5. Return {:ok, map} or {:error, exception}
    # 6. Return {:ok, %{}} if no invoices exist for the year
    #
    # Pseudocode:
    #   case repo.all(from r in InvoiceRecord, where: year(r.date) == ^year, preload: :items) do
    #     [] -> {:ok, %{}}
    #     records ->
    #       invoices = Enum.map(records, &invoice_from_record/1)
    #       map = Enum.into(invoices, %{}, fn inv -> {inv.number, inv} end)
    #       {:ok, map}
    #   end

    {:error,
     Error.ValidationError.exception(
       message: "load_all/1 not implemented in template. Copy to create a real adapter."
     )}
  end

  # ============================================================================
  # Year Metadata Operations
  # ============================================================================

  @doc """
  Saves year metadata (next_id counter).

  This allows tracking the next invoice number to generate for a year.
  """
  @impl InvoiceStorage.Adapter
  def save_year_list(%ListInvoiceYear{} = _list_year) do
    # Example implementation outline:
    # 1. Create or update year metadata record
    # 2. Store: year, next_id, created_at, updated_at
    # 3. Return :ok or {:error, exception}
    #
    # Pseudocode:
    #   changeset = YearMetadataRecord.changeset(%YearMetadataRecord{}, %{
    #     year: list_year.year,
    #     next_id: list_year.next_id
    #   })
    #   case repo.insert_or_update(changeset) do
    #     {:ok, _record} -> :ok
    #     {:error, reason} -> {:error, reason}
    #   end

    {:error,
     Error.ValidationError.exception(
       message: "save_year_list/1 not implemented in template. Copy to create a real adapter."
     )}
  end

  @doc """
  Loads year metadata for a specific year.

  Returns next_id and creates ListInvoiceYear with empty invoices.
  Invoices should be loaded separately with load_all/1.
  """
  @impl InvoiceStorage.Adapter
  def load_year_list(year) when is_integer(year) do
    # Example implementation outline:
    # 1. Query year metadata by year
    # 2. If not found, return error (year doesn't exist)
    # 3. Create ListInvoiceYear with empty invoices
    # 4. Return {:ok, ListInvoiceYear} or {:error, exception}
    #
    # Pseudocode:
    #   case repo.get(YearMetadataRecord, year) do
    #     nil -> {:error, "Year #{year} not found"}
    #     record -> {:ok, %ListInvoiceYear{
    #       year: record.year,
    #       next_id: record.next_id,
    #       invoices: %{}
    #     }}
    #   end

    {:error,
     Error.ValidationError.exception(
       message: "load_year_list/1 not implemented in template. Copy to create a real adapter."
     )}
  end

  @doc """
  Lists all years that have invoices.

  Returns years sorted in descending order (newest first).
  """
  @impl InvoiceStorage.Adapter
  def list_years() do
    # Example implementation outline:
    # 1. Query distinct years from year metadata or invoice records
    # 2. Sort descending (newest first)
    # 3. Return {:ok, [2024, 2023, 2022]} or {:error, exception}
    #
    # Pseudocode:
    #   years = repo.all(from r in YearMetadataRecord, select: r.year, order_by: [desc: r.year])
    #   {:ok, years}

    {:error,
     Error.ValidationError.exception(
       message: "list_years/0 not implemented in template. Copy to create a real adapter."
     )}
  end

  @doc """
  Counts invoices in a specific year.

  Efficient count query without loading full records.
  """
  @impl InvoiceStorage.Adapter
  def count(year) when is_integer(year) do
    # Example implementation outline:
    # 1. COUNT query filtered by year
    # 2. Return {:ok, count} or {:error, exception}
    #
    # Pseudocode:
    #   count = repo.one(from r in InvoiceRecord, where: year(r.date) == ^year, select: count(r.id))
    #   {:ok, count}

    {:error,
     Error.ValidationError.exception(
       message: "count/1 not implemented in template. Copy to create a real adapter."
     )}
  end

  # ============================================================================
  # Helper: Data Conversion Functions
  # ============================================================================

  # Example helper to convert a database record to an Invoice struct.
  #
  # This is commented out because it depends on your specific database schema.
  # Uncomment and customize for your implementation.
  #
  # ## Pattern
  #
  # ```elixir
  # defp invoice_from_record(%InvoiceRecord{} = record) do
  #   items = Enum.map(record.items, fn item ->
  #     %Item{
  #       description: item.description,
  #       units: item.units,
  #       amount: item.amount
  #     }
  #   end)
  #
  #   {:ok, %Invoice{
  #     number: record.number,
  #     date: record.date,
  #     bill_to: record.bill_to,
  #     vendor_details: record.vendor_details,
  #     items: items,
  #     sale_amount: record.sale_amount,
  #     vat: record.vat
  #   }}
  # end
  # ```
  #
  # To use: Uncomment and customize for your implementation.

  # TEMPLATE HELPER - UNCOMMENT AND CUSTOMIZE
  # defp invoice_from_record(%InvoiceRecord{} = record) do
  #   items = Enum.map(record.items, fn item ->
  #     %Item{
  #       description: item.description,
  #       units: item.units,
  #       amount: item.amount
  #     }
  #   end)
  #
  #   {:ok, %Invoice{
  #     number: record.number,
  #     date: record.date,
  #     bill_to: record.bill_to,
  #     vendor_details: record.vendor_details,
  #     items: items,
  #     sale_amount: record.sale_amount,
  #     vat: record.vat
  #   }}
  # end
end
