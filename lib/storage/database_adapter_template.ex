defmodule InvoiceStorage.DatabaseAdapterTemplate do
  @moduledoc """
  Template for implementing a database-backed storage adapter.

  This is a reference implementation showing how to create a database adapter
  that implements the `InvoiceStorage.Adapter` behavior. Replace database calls
  with your actual database library (Ecto, Postgrex, etc.).

  ## Usage

  To implement a real database adapter:
  1. Copy this file to `lib/storage/database_adapter.ex`
  2. Replace placeholders with actual database calls
  3. Configure in `config/config.exs`:

      config :invoice_creation,
        storage_adapter: InvoiceStorage.DatabaseAdapter,
        storage_config: [
          repo: MyApp.Repo
        ]

  4. Delete this template file

  ## Design Considerations

  - Use transactions for atomicity (save_all should be one transaction)
  - Index on (invoice_number, year) for fast lookups
  - Keep year metadata separate for quick next_id lookups
  - Store dates as DATE type (ISO 8601 compatible)
  - Use NOT NULL constraints for required fields
  - Add CHECK constraints for validation rules (e.g., vat >= 0)
  """

  @behaviour InvoiceStorage.Adapter

  alias Invoice
  alias ListInvoiceYear

  # Example: assuming Ecto with a Repo
  @repo Application.compile_env(:invoice_creation, :repo, nil)

  def save(%Invoice{} = invoice) do
    # TODO: Insert or update invoice in database
    # - Convert invoice to database schema
    # - Handle DATE field conversion (date to ISO string)
    # - Validate business rules
    # - Return :ok or {:error, exception}
    #
    # Example structure:
    #   Repo.insert_or_update(%InvoiceRecord{
    #     invoice_number: invoice.number,
    #     year: invoice.date.year,
    #     date: invoice.date,
    #     bill_to: invoice.bill_to,
    #     vendor_details: invoice.vendor_details,
    #     items: Jason.encode!(invoice.items),
    #     sale_amount: invoice.sale_amount,
    #     vat: invoice.vat
    #   })
    {:error, "Not implemented - database adapter template"}
  end

  def load(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    # TODO: Query database for invoice
    # - Look up by (invoice_number, year)
    # - Convert database record back to Invoice struct
    # - Handle missing records gracefully
    # - Return {:ok, Invoice} or {:error, exception}
    #
    # Example structure:
    #   case Repo.get_by(InvoiceRecord, number: invoice_number, year: year) do
    #     nil -> {:error, FileNotFound.exception(path: "#{year}/#{invoice_number}")}
    #     record -> {:ok, from_database(record)}
    #   end
    {:error, "Not implemented - database adapter template"}
  end

  def exists?(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    # TODO: Check if invoice exists in database
    # - Simple count query
    # - Return boolean
    #
    # Example: Repo.exists?(from r in InvoiceRecord, where: r.number == ^invoice_number and r.year == ^year)
    false
  end

  def delete(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    # TODO: Delete invoice from database
    # - Handle non-existent invoices
    # - Return :ok or {:error, exception}
    #
    # Example: Repo.delete_all(from r in InvoiceRecord, where: r.number == ^invoice_number and r.year == ^year)
    {:error, "Not implemented - database adapter template"}
  end

  def save_all(%ListInvoiceYear{} = list_year) do
    # TODO: Save all invoices in a transaction
    # - Use database transaction for atomicity
    # - Save each invoice
    # - If any fails, rollback
    # - Return :ok or {:error, exception}
    #
    # Example:
    #   Repo.transaction(fn ->
    #     list_year.invoices |> Enum.each(fn {_num, invoice} ->
    #       save(invoice)
    #     end)
    #   end)
    {:error, "Not implemented - database adapter template"}
  end

  def load_all(year) when is_integer(year) do
    # TODO: Load all invoices for a year
    # - Query all invoices with matching year
    # - Convert to map keyed by invoice_number
    # - Return {:ok, map} or {:error, exception}
    # - Return {:ok, %{}} if no invoices for year
    #
    # Example:
    #   case Repo.all(from r in InvoiceRecord, where: r.year == ^year) do
    #     records -> {:ok, records |> Enum.map(&from_database/1) |> Enum.into(%{}, fn inv -> {inv.number, inv} end)}
    #     [] -> {:ok, %{}}
    #   end
    {:error, "Not implemented - database adapter template"}
  end

  def save_year_list(%ListInvoiceYear{} = list_year) do
    # TODO: Save year metadata
    # - Insert or update year record with next_id
    # - Return :ok or {:error, exception}
    #
    # Example:
    #   Repo.insert_or_update(%YearRecord{
    #     year: list_year.year,
    #     next_id: list_year.next_id
    #   })
    {:error, "Not implemented - database adapter template"}
  end

  def load_year_list(year) when is_integer(year) do
    # TODO: Load year metadata
    # - Query year record
    # - Return ListInvoiceYear with empty invoices
    # - Return error if year not found
    #
    # Example:
    #   case Repo.get(YearRecord, year) do
    #     nil -> {:error, "Year #{year} not found"}
    #     record -> {:ok, %ListInvoiceYear{year: record.year, next_id: record.next_id, invoices: %{}}}
    #   end
    {:error, "Not implemented - database adapter template"}
  end

  def list_years() do
    # TODO: Get list of all years with invoices
    # - Query distinct years
    # - Sort descending (newest first)
    # - Return {:ok, list} or {:error, exception}
    #
    # Example: {:ok, Repo.all(from r in YearRecord, select: r.year, order_by: [desc: r.year])}
    {:error, "Not implemented - database adapter template"}
  end

  def count(year) when is_integer(year) do
    # TODO: Count invoices in a year
    # - Query count with year filter
    # - Return {:ok, count} or {:error, exception}
    #
    # Example: {:ok, Repo.one(from r in InvoiceRecord, where: r.year == ^year, select: count(r.id))}
    {:error, "Not implemented - database adapter template"}
  end

  # ============================================================================
  # Helper: Convert between database record and Invoice struct
  # ============================================================================

  # TODO: Implement conversion functions
  # defp from_database(%InvoiceRecord{} = record) do
  #   %Invoice{
  #     number: record.invoice_number,
  #     date: record.date,
  #     bill_to: record.bill_to,
  #     vendor_details: record.vendor_details,
  #     items: Jason.decode!(record.items),
  #     sale_amount: record.sale_amount,
  #     vat: record.vat
  #   }
  # end
end
