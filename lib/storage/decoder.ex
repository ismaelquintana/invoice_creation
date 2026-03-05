defmodule InvoiceStorage.Decoder do
  @moduledoc """
  JSON deserialization for invoice domain objects.

  Converts JSON maps back into Invoice, Item, and ListInvoiceYear structs
  with proper type conversions and validation.

  All functions return {:ok, struct} or {:error, exception}.
  Validation is performed after deserialization to catch data integrity issues.
  """

  alias Invoice
  alias Item
  alias ListInvoiceYear
  alias InvoiceStorage.Error.{DecodeFailed, InvalidYear}

  @doc """
  Decodes a JSON map into an Invoice struct.

  Required fields: date, number, bill_to, vendor_details, items, sale_amount, vat
  - date must be a valid ISO 8601 date string
  - items must be a list of valid item maps
  - All other fields are passed through as-is

  Performs validation via Invoice.new/1 after deserialization.

  Returns {:ok, Invoice} on success or {:error, exception} on failure.
  """
  def decode_invoice(data) when is_map(data) do
    try do
      with {:ok, date} <- decode_date(Map.get(data, "date")),
           {:ok, items} <- decode_items(Map.get(data, "items", [])),
           # Convert string keys to atom keys for Invoice.new
           invoice_opts <- [
             date: date,
             number: Map.get(data, "number"),
             bill_to: Map.get(data, "bill_to"),
             vendor_details: Map.get(data, "vendor_details"),
             items: items,
             sale_amount: Map.get(data, "sale_amount"),
             vat: Map.get(data, "vat")
           ],
           {:ok, invoice} <- Invoice.new(invoice_opts) do
        {:ok, invoice}
      else
        {:error, reason} -> {:error, reason}
      end
    rescue
      e ->
        {:error,
         DecodeFailed.exception(
           reason: e,
           message: "Failed to decode invoice: #{inspect(e)}"
         )}
    end
  end

  def decode_invoice(data) do
    {:error,
     DecodeFailed.exception(
       reason: :invalid_type,
       message: "Expected map, got #{inspect(data)}"
     )}
  end

  @doc """
  Decodes a JSON map into an Item struct.

  Required fields: description, units, amount

  Performs validation via Item.new/1 after deserialization.

  Returns {:ok, Item} on success or {:error, exception} on failure.
  """
  def decode_item(data) when is_map(data) do
    try do
      # Convert string keys to atom keys for Item.new
      item_opts = [
        description: Map.get(data, "description"),
        units: Map.get(data, "units"),
        amount: Map.get(data, "amount")
      ]

      Item.new(item_opts)
    rescue
      e ->
        {:error,
         DecodeFailed.exception(
           reason: e,
           message: "Failed to decode item: #{inspect(e)}"
         )}
    end
  end

  def decode_item(data) do
    {:error,
     DecodeFailed.exception(
       reason: :invalid_type,
       message: "Expected map, got #{inspect(data)}"
     )}
  end

  @doc """
  Decodes a JSON map into a ListInvoiceYear struct.

  Required fields: year, next_id, invoices
  - invoices is a list of invoice maps (not a map keyed by invoice number)

  Rebuilds the invoices map from the list after decoding each invoice.

  Returns {:ok, ListInvoiceYear} on success or {:error, exception} on failure.
  """
  def decode_list_invoice_year(data) when is_map(data) do
    try do
      year = Map.get(data, "year")
      next_id = Map.get(data, "next_id")
      invoices_list = Map.get(data, "invoices", [])

      with true <- is_integer(year) or {:error, InvalidYear.exception(year: year)},
           true <- is_integer(next_id) or {:error, :invalid_next_id},
           {:ok, invoices_map} <- decode_invoices_list(invoices_list) do
        list_year = %ListInvoiceYear{
          year: year,
          next_id: next_id,
          invoices: invoices_map
        }

        {:ok, list_year}
      else
        error when is_tuple(error) -> error
        false -> {:error, InvalidYear.exception(year: year)}
      end
    rescue
      e ->
        {:error,
         DecodeFailed.exception(
           reason: e,
           message: "Failed to decode ListInvoiceYear: #{inspect(e)}"
         )}
    end
  end

  def decode_list_invoice_year(data) do
    {:error,
     DecodeFailed.exception(
       reason: :invalid_type,
       message: "Expected map, got #{inspect(data)}"
     )}
  end

  @doc """
  Decodes an ISO 8601 date string into a Date struct.

  Returns {:ok, Date} on success or {:error, exception} on failure.
  """
  def decode_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        {:ok, date}

      {:error, reason} ->
        {:error,
         DecodeFailed.exception(
           reason: reason,
           message: "Invalid ISO 8601 date: #{date_string}"
         )}
    end
  end

  def decode_date(nil) do
    {:error,
     DecodeFailed.exception(
       reason: :missing_date,
       message: "Date field is required"
     )}
  end

  def decode_date(data) do
    {:error,
     DecodeFailed.exception(
       reason: :invalid_type,
       message: "Expected date string, got #{inspect(data)}"
     )}
  end

  # Private helpers

  defp decode_items(items) when is_list(items) do
    items
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {item_data, _idx}, {:ok, acc} ->
      case decode_item(item_data) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, decoded} -> {:ok, Enum.reverse(decoded)}
      error -> error
    end
  end

  defp decode_items(data) do
    {:error,
     DecodeFailed.exception(
       reason: :invalid_type,
       message: "Expected items list, got #{inspect(data)}"
     )}
  end

  defp decode_invoices_list(invoices_list) when is_list(invoices_list) do
    invoices_list
    |> Enum.reduce_while({:ok, %{}}, fn invoice_data, {:ok, acc} ->
      case decode_invoice(invoice_data) do
        {:ok, invoice} ->
          {:cont, {:ok, Map.put(acc, invoice.number, invoice)}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp decode_invoices_list(data) do
    {:error,
     DecodeFailed.exception(
       reason: :invalid_type,
       message: "Expected invoices list, got #{inspect(data)}"
     )}
  end
end
