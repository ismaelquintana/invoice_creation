defmodule InvoiceCreation do
  @moduledoc """
  Main entry point for the invoice creation application.

  Provides high-level convenience functions that combine domain logic
  (Invoice, Item, ListInvoiceYear) with persistence operations (InvoiceStorage).

  ## Overview

  InvoiceCreation enables:
  - Creating and managing invoices with items
  - Persisting invoices to storage (file or database)
  - Loading invoices from storage
  - Managing invoices organized by year
  - Exporting and importing invoice data

  ## Examples

      # Create a new invoice with item and save it
      {:ok, item} = Item.new(description: "Service", units: 2, amount: 100)
      {:ok, invoice} = InvoiceCreation.create_invoice(bill_to: "Acme Corp")
      {:ok, invoice} = InvoiceCreation.add_item_to_invoice(invoice, item)
      :ok = InvoiceCreation.save_invoice(invoice)

      # Load an invoice from storage
      {:ok, invoice} = InvoiceCreation.load_invoice("2024-0001", 2024)

      # Create and save multiple invoices as a year list
      {:ok, year_list} = InvoiceCreation.create_year_list(2024)
      :ok = InvoiceCreation.save_year(year_list)

      # Export all invoices for a year
      {:ok, data} = InvoiceCreation.export_year(2024)
      :ok = File.write("invoices_2024.json", data)

  ## Integration with Persistence

  The storage layer follows the same error handling pattern as the domain
  modules (Invoice, Item, ListInvoiceYear). All functions return:
  - `{:ok, result}` on success
  - `{:error, exception}` on failure

  Use `InvoiceStorage.Error.format_error/1` for user-friendly error messages.
  """

  alias Invoice
  alias Item
  alias ListInvoiceYear
  alias InvoiceStorage

  # ============================================================================
  # Invoice Creation & Management
  # ============================================================================

  @doc """
  Creates a new invoice with validation.

  Convenience wrapper around Invoice.new/1 with sensible defaults.

  ## Parameters
    - `opts` - Keyword list with optional `:bill_to`, `:vendor_details`, `:date`, etc.

  ## Returns
    - `{:ok, Invoice.t()}` - If invoice is valid
    - `{:error, Invoice.Error.t()}` - If validation fails

  ## Examples

      {:ok, invoice} = InvoiceCreation.create_invoice(bill_to: "Acme Corp")
      {:ok, invoice} = InvoiceCreation.create_invoice()
  """
  @spec create_invoice(keyword()) :: {:ok, Invoice.t()} | {:error, Invoice.Error.t()}
  def create_invoice(opts \\ []) do
    Invoice.new(opts)
  end

  @doc """
  Creates a new item with validation.

  Convenience wrapper around Item.new/1.

  ## Parameters
    - `description` - Item description (required)
    - `units` - Number of units (required, positive integer)
    - `amount` - Price per unit (required, positive integer)

  ## Returns
    - `{:ok, Item.t()}` - If item is valid
    - `{:error, Item.Error.t()}` - If validation fails

  ## Examples

      {:ok, item} = InvoiceCreation.create_item("Service", 2, 100)
  """
  @spec create_item(String.t(), pos_integer(), pos_integer()) ::
          {:ok, Item.t()} | {:error, Item.Error.t()}
  def create_item(description, units, amount) do
    Item.new(description: description, units: units, amount: amount)
  end

  @doc """
  Adds an item to an invoice.

  Convenience wrapper around Invoice.add_item/2.

  ## Parameters
    - `invoice` - The invoice to update
    - `item` - The item to add

  ## Returns
    - `{:ok, Invoice.t()}` - If item was added successfully
    - `{:error, Invoice.Error.t()}` - If validation fails

  ## Examples

      {:ok, item} = InvoiceCreation.create_item("Service", 2, 100)
      {:ok, invoice} = InvoiceCreation.create_invoice()
      {:ok, updated} = InvoiceCreation.add_item_to_invoice(invoice, item)
  """
  @spec add_item_to_invoice(Invoice.t(), Item.t()) ::
          {:ok, Invoice.t()} | {:error, Invoice.Error.t()}
  def add_item_to_invoice(invoice, item) do
    Invoice.add_item(invoice, item)
  end

  @doc """
  Adds multiple items to an invoice.

  Convenience wrapper around Invoice.add_list_items/2.

  ## Parameters
    - `invoice` - The invoice to update
    - `items` - List of items to add

  ## Returns
    - `{:ok, Invoice.t()}` - If all items were added successfully
    - `{:error, Invoice.Error.t()}` - If any validation fails

  ## Examples

      items = [item1, item2, item3]
      {:ok, invoice} = InvoiceCreation.create_invoice()
      {:ok, updated} = InvoiceCreation.add_items_to_invoice(invoice, items)
  """
  @spec add_items_to_invoice(Invoice.t(), [Item.t()]) ::
          {:ok, Invoice.t()} | {:error, Invoice.Error.t()}
  def add_items_to_invoice(invoice, items) do
    Invoice.add_list_items(invoice, items)
  end

  # ============================================================================
  # Persistence: Individual Invoices
  # ============================================================================

  @doc """
  Saves an invoice to storage.

  Persists the invoice to the configured storage backend (default: JSON files).

  ## Parameters
    - `invoice` - The invoice to save

  ## Returns
    - `:ok` - If save was successful
    - `{:error, exception}` - If save failed (file I/O error, permission denied, etc.)

  ## Examples

      {:ok, invoice} = InvoiceCreation.create_invoice(bill_to: "Acme")
      :ok = InvoiceCreation.save_invoice(invoice)
  """
  @spec save_invoice(Invoice.t()) :: :ok | {:error, any()}
  def save_invoice(invoice) do
    InvoiceStorage.save(invoice)
  end

  @doc """
  Loads an invoice from storage by invoice number and year.

  ## Parameters
    - `invoice_number` - Invoice number (e.g., "2024-0001")
    - `year` - Year the invoice was created

  ## Returns
    - `{:ok, Invoice.t()}` - If invoice was loaded and validated
    - `{:error, exception}` - If file not found, corrupted, or invalid

  ## Examples

      {:ok, invoice} = InvoiceCreation.load_invoice("2024-0001", 2024)

      # Error handling
      case InvoiceCreation.load_invoice("2024-9999", 2024) do
        {:ok, invoice} -> {:ok, invoice}
        {:error, reason} ->
          message = InvoiceStorage.Error.format_error(reason)
          {:error, message}
      end
  """
  @spec load_invoice(String.t(), pos_integer()) ::
          {:ok, Invoice.t()} | {:error, any()}
  def load_invoice(invoice_number, year) do
    InvoiceStorage.load(invoice_number, year)
  end

  @doc """
  Checks if an invoice exists in storage.

  ## Parameters
    - `invoice_number` - Invoice number to check
    - `year` - Year to check

  ## Returns
    - `true` - If invoice file exists
    - `false` - If invoice file does not exist

  ## Examples

      true = InvoiceCreation.invoice_exists?("2024-0001", 2024)
      false = InvoiceCreation.invoice_exists?("2024-9999", 2024)
  """
  @spec invoice_exists?(String.t(), pos_integer()) :: boolean()
  def invoice_exists?(invoice_number, year) do
    InvoiceStorage.exists?(invoice_number, year)
  end

  @doc """
  Deletes an invoice from storage.

  ## Parameters
    - `invoice_number` - Invoice number to delete
    - `year` - Year of the invoice

  ## Returns
    - `:ok` - If invoice was deleted
    - `{:error, exception}` - If delete failed (file not found, permission denied, etc.)

  ## Examples

      :ok = InvoiceCreation.delete_invoice("2024-0001", 2024)
  """
  @spec delete_invoice(String.t(), pos_integer()) :: :ok | {:error, any()}
  def delete_invoice(invoice_number, year) do
    InvoiceStorage.delete(invoice_number, year)
  end

  # ============================================================================
  # Persistence: Year Lists
  # ============================================================================

  @doc """
  Creates a new year list for organizing invoices by year.

  Convenience wrapper around ListInvoiceYear.new/1.

  ## Parameters
    - `year` - Year for the list (optional, defaults to current year)

  ## Returns
    - `{:ok, ListInvoiceYear.t()}` - If year list is valid
    - `{:error, ListInvoiceYear.Error.t()}` - If validation fails

  ## Examples

      {:ok, list} = InvoiceCreation.create_year_list(2024)
      {:ok, list} = InvoiceCreation.create_year_list()
  """
  @spec create_year_list(pos_integer() | nil) ::
          {:ok, ListInvoiceYear.t()} | {:error, ListInvoiceYear.Error.t()}
  def create_year_list(year \\ nil) do
    if year do
      ListInvoiceYear.new(year: year)
    else
      ListInvoiceYear.new()
    end
  end

  @doc """
  Saves all invoices from a year list to storage.

  Persists all invoices in the year list as well as the year metadata.

  ## Parameters
    - `year_list` - ListInvoiceYear struct with invoices to save

  ## Returns
    - `:ok` - If all invoices were saved
    - `{:error, exception}` - If any save operation failed

  ## Examples

      {:ok, list} = InvoiceCreation.create_year_list(2024)
      :ok = InvoiceCreation.save_year(list)
  """
  @spec save_year(ListInvoiceYear.t()) :: :ok | {:error, any()}
  def save_year(year_list) do
    with :ok <- InvoiceStorage.save_all(year_list),
         :ok <- InvoiceStorage.save_year_list(year_list) do
      :ok
    end
  end

  @doc """
  Loads all invoices for a specific year from storage.

  Reconstructs a ListInvoiceYear with all invoices for that year.

  ## Parameters
    - `year` - Year to load

  ## Returns
    - `{:ok, ListInvoiceYear.t()}` - If year was loaded
    - `{:error, exception}` - If load or validation failed

  ## Examples

      {:ok, year_list} = InvoiceCreation.load_year(2024)
      length(year_list.invoices)  # Number of invoices for 2024
  """
  @spec load_year(pos_integer()) ::
          {:ok, ListInvoiceYear.t()} | {:error, any()}
  def load_year(year) do
    with {:ok, year_list} <- InvoiceStorage.load_year_list(year),
         {:ok, invoices} <- InvoiceStorage.load_all(year) do
      {:ok, %ListInvoiceYear{year_list | invoices: invoices}}
    end
  end

  @doc """
  Lists all years with stored invoices.

  ## Returns
    - `{:ok, [pos_integer()]}` - List of years with invoices
    - `{:error, exception}` - If listing failed

  ## Examples

      {:ok, years} = InvoiceCreation.list_stored_years()
      # years = [2024, 2023, 2022]
  """
  @spec list_stored_years() :: {:ok, [pos_integer()]} | {:error, any()}
  def list_stored_years() do
    InvoiceStorage.list_years()
  end

  @doc """
  Counts the number of invoices stored for a specific year.

  ## Parameters
    - `year` - Year to count

  ## Returns
    - `{:ok, non_neg_integer()}` - Number of invoices in year
    - `{:error, exception}` - If count operation failed

  ## Examples

      {:ok, count} = InvoiceCreation.count_invoices_in_year(2024)
      # count = 15
  """
  @spec count_invoices_in_year(pos_integer()) :: {:ok, non_neg_integer()} | {:error, any()}
  def count_invoices_in_year(year) do
    InvoiceStorage.count(year)
  end

  # ============================================================================
  # Export & Import (Backup/Restore)
  # ============================================================================

  @doc """
  Exports all invoices for a year as JSON string.

  Useful for backup, data migration, or API responses.

  ## Parameters
    - `year` - Year to export

  ## Returns
    - `{:ok, String.t()}` - JSON string with all invoices and metadata
    - `{:error, exception}` - If export failed

  ## Examples

      {:ok, json} = InvoiceCreation.export_year(2024)
      :ok = File.write("backup_2024.json", json)
  """
  @spec export_year(pos_integer()) :: {:ok, String.t()} | {:error, any()}
  def export_year(year) do
    with {:ok, year_list} <- InvoiceStorage.load_year_list(year),
         {:ok, invoices} <- InvoiceStorage.load_all(year) do
      year_list_with_invoices = %ListInvoiceYear{year_list | invoices: invoices}
      {:ok, Jason.encode!(year_list_with_invoices)}
    end
  rescue
    e -> {:error, e}
  end

  @doc """
  Exports all stored invoices across all years as JSON string.

  Useful for complete backup or system migration.

  ## Returns
    - `{:ok, String.t()}` - JSON array with all years and invoices
    - `{:error, exception}` - If export failed

  ## Examples

      {:ok, json} = InvoiceCreation.export_all()
      :ok = File.write("complete_backup.json", json)
  """
  @spec export_all() :: {:ok, String.t()} | {:error, any()}
  def export_all() do
    with {:ok, years} <- InvoiceStorage.list_years() do
      results =
        years
        |> Enum.map(fn year ->
          case InvoiceStorage.load_year_list(year) do
            {:ok, year_list} ->
              case InvoiceStorage.load_all(year) do
                {:ok, invoices} ->
                  %ListInvoiceYear{year_list | invoices: invoices}

                {:error, _} ->
                  year_list
              end

            {:error, _} ->
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      {:ok, Jason.encode!(results)}
    end
  rescue
    e -> {:error, e}
  end

  @doc """
  Imports invoices from a JSON string containing a single year.

  Used for restoring backups or importing data. Will overwrite existing
  invoices with the same number.

  ## Parameters
    - `json` - JSON string from export_year/1
    - `year` - Year to import to (must match JSON data)

  ## Returns
    - `:ok` - If all invoices were imported successfully
    - `{:error, exception}` - If import failed

  ## Examples

      {:ok, json} = File.read("backup_2024.json")
      :ok = InvoiceCreation.import_year(json, 2024)
  """
  @spec import_year(String.t(), pos_integer()) :: :ok | {:error, any()}
  def import_year(json, year) do
    try do
      with {:ok, data} <- Jason.decode(json),
           {:ok, year_list} <- InvoiceStorage.Decoder.decode_list_invoice_year(data) do
        # Verify year matches
        if year_list.year == year do
          InvoiceStorage.save_all(year_list)
        else
          {:error, "Year mismatch: JSON contains year #{year_list.year}, expected #{year}"}
        end
      end
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Imports invoices from a JSON string containing multiple years.

  Used for complete system restoration or bulk data import.

  ## Parameters
    - `json` - JSON string from export_all/0

  ## Returns
    - `:ok` - If all invoices were imported successfully
    - `{:error, exception}` - If import failed at any point

  ## Examples

      {:ok, json} = File.read("complete_backup.json")
      :ok = InvoiceCreation.import_all(json)
  """
  @spec import_all(String.t()) :: :ok | {:error, any()}
  def import_all(json) do
    try do
      with {:ok, data} <- Jason.decode(json) do
        if is_list(data) do
          data
          |> Enum.reduce_while(:ok, fn year_data, :ok ->
            case InvoiceStorage.Decoder.decode_list_invoice_year(year_data) do
              {:ok, year_list} ->
                case InvoiceStorage.save_all(year_list) do
                  :ok -> {:cont, :ok}
                  error -> {:halt, error}
                end

              {:error, reason} ->
                {:halt, {:error, reason}}
            end
          end)
        else
          {:error, "Expected JSON array of year lists"}
        end
      end
    rescue
      e -> {:error, e}
    end
  end
end
