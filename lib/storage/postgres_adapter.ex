defmodule InvoiceStorage.PostgresAdapter do
  @moduledoc """
  PostgreSQL adapter for invoice storage.

  Implements the InvoiceStorage.Adapter behavior using PostgreSQL as the backend
  storage. Uses Ecto schemas to manage data persistence and validation.

  ## Configuration

  Add to `config/dev.exs` or `config/prod.exs`:

      config :invoice_creation,
        storage_adapter: InvoiceStorage.PostgresAdapter,
        storage_config: [repo: InvoiceCreation.Repo]

  ## Database Requirements

  Requires the following migrations to be run:
  - CreateInvoices: creates invoices table
  - CreateItems: creates items table with foreign key to invoices
  - CreateYearMetadata: creates year_metadata table for tracking

  Run migrations with:

      mix ecto.migrate
  """

  @behaviour InvoiceStorage.Adapter

  alias InvoiceCreation.Repo
  alias InvoiceCreation.Schemas.{InvoiceRecord, ItemRecord, YearMetadataRecord}
  import Ecto.Query

  # ============================================================================
  # Single Invoice Operations
  # ============================================================================

  @impl InvoiceStorage.Adapter
  def save(%Invoice{} = invoice) do
    with {:ok, _record} <- save_invoice_and_items(invoice) do
      :ok
    end
  end

  @impl InvoiceStorage.Adapter
  def load(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    query =
      from(i in InvoiceRecord,
        where:
          i.number == ^invoice_number and fragment("extract(year from ?) = ?", i.date, ^year),
        preload: :items
      )

    case Repo.one(query) do
      nil ->
        {:error,
         InvoiceStorage.Error.FileNotFound.exception(
           message: "Invoice #{invoice_number} not found for year #{year}"
         )}

      record ->
        invoice_from_record(record)
    end
  end

  @impl InvoiceStorage.Adapter
  def exists?(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    query =
      from(i in InvoiceRecord,
        where:
          i.number == ^invoice_number and fragment("extract(year from ?) = ?", i.date, ^year),
        select: true
      )

    Repo.exists?(query)
  end

  @impl InvoiceStorage.Adapter
  def delete(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    case load(invoice_number, year) do
      {:ok, _invoice} ->
        query =
          from(i in InvoiceRecord,
            where:
              i.number == ^invoice_number and fragment("extract(year from ?) = ?", i.date, ^year)
          )

        case Repo.delete_all(query) do
          {1, _} ->
            :ok

          {0, _} ->
            {:error,
             InvoiceStorage.Error.FileNotFound.exception(
               message: "Invoice #{invoice_number} not found for year #{year}"
             )}
        end

      error ->
        error
    end
  end

  # ============================================================================
  # Bulk Operations
  # ============================================================================

  @impl InvoiceStorage.Adapter
  def save_all(%ListInvoiceYear{invoices: invoices}) do
    Repo.transaction(fn ->
      Enum.each(invoices, fn invoice ->
        case save_invoice_and_items(invoice) do
          :ok -> :ok
          {:ok, _} -> :ok
          error -> Repo.rollback(error)
        end
      end)
    end)
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @impl InvoiceStorage.Adapter
  def load_all(year) when is_integer(year) do
    query =
      from(i in InvoiceRecord,
        where: fragment("extract(year from ?) = ?", i.date, ^year),
        preload: :items
      )

    invoices = Repo.all(query)

    result =
      invoices
      |> Enum.reduce({:ok, %{}}, fn record, acc ->
        case {acc, invoice_from_record(record)} do
          {{:ok, map}, {:ok, invoice}} ->
            {:ok, Map.put(map, invoice.number, invoice)}

          {{:ok, _}, error} ->
            error

          {error, _} ->
            error
        end
      end)

    result
  end

  # ============================================================================
  # Year Metadata
  # ============================================================================

  @impl InvoiceStorage.Adapter
  def save_year_list(%ListInvoiceYear{year: year}) do
    # Calculate metadata from current invoices in the year
    query =
      from(i in InvoiceRecord,
        where: fragment("extract(year from ?) = ?", i.date, ^year),
        select: {count(i.id), sum(i.sale_amount), sum(i.vat)}
      )

    {count, total_sale, total_vat} = Repo.one(query) || {0, 0, 0}

    attrs = %{
      year: year,
      invoice_count: count || 0,
      total_sale_amount: total_sale || 0,
      total_vat: total_vat || 0
    }

    case Repo.get_by(YearMetadataRecord, year: year) do
      nil ->
        %YearMetadataRecord{}
        |> YearMetadataRecord.changeset(attrs)
        |> Repo.insert()

      record ->
        record
        |> YearMetadataRecord.changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @impl InvoiceStorage.Adapter
  def load_year_list(year) when is_integer(year) do
    case Repo.get_by(YearMetadataRecord, year: year) do
      nil ->
        {:ok,
         %ListInvoiceYear{
           year: year,
           invoices: [],
           next_id: 1
         }}

      record ->
        {:ok,
         %ListInvoiceYear{
           year: year,
           invoices: [],
           next_id: record.invoice_count + 1
         }}
    end
  end

  # ============================================================================
  # Discovery & Utility
  # ============================================================================

  @impl InvoiceStorage.Adapter
  def list_years do
    query =
      from(y in YearMetadataRecord,
        select: y.year,
        order_by: [desc: y.year]
      )

    years = Repo.all(query)
    {:ok, years}
  end

  @impl InvoiceStorage.Adapter
  def count(year) when is_integer(year) do
    query =
      from(i in InvoiceRecord,
        where: fragment("extract(year from ?) = ?", i.date, ^year),
        select: count(i.id)
      )

    count = Repo.one(query) || 0
    {:ok, count}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  @spec save_invoice_and_items(Invoice.t()) :: {:ok, InvoiceRecord.t()} | {:error, any()}
  defp save_invoice_and_items(%Invoice{} = invoice) do
    Repo.transaction(fn ->
      # Create or update invoice record
      invoice_record =
        case load(invoice.number, invoice.date.year) do
          {:ok, _} ->
            # Update existing
            query = from(i in InvoiceRecord, where: i.number == ^invoice.number)
            Repo.one(query)

          {:error, _} ->
            # Create new
            nil
        end

      changeset = InvoiceRecord.from_invoice(invoice)

      record =
        case invoice_record do
          nil ->
            Repo.insert!(changeset)

          existing ->
            Repo.update!(Ecto.Changeset.change(existing, Ecto.Changeset.apply_changes(changeset)))
        end

      # Delete old items and create new ones
      Repo.delete_all(from(it in ItemRecord, where: it.invoice_id == ^record.id))

      Enum.each(invoice.items, fn item ->
        item_changeset = ItemRecord.from_item(item, record.id)
        Repo.insert!(item_changeset)
      end)

      record
    end)
  end

  @spec invoice_from_record(InvoiceRecord.t()) :: {:ok, Invoice.t()} | {:error, any()}
  defp invoice_from_record(record) do
    items =
      record.items
      |> Enum.map(fn item_record ->
        %Item{
          description: item_record.description,
          units: item_record.units,
          amount: item_record.amount
        }
      end)

    invoice = %Invoice{
      number: record.number,
      date: record.date,
      bill_to: record.bill_to,
      vendor_details: record.vendor_details,
      sale_amount: record.sale_amount,
      vat: record.vat,
      items: items
    }

    {:ok, invoice}
  end
end
