defmodule InvoiceStorage.Encoder do
  @moduledoc """
  JSON serialization for invoice domain objects.

  Converts Invoice, Item, and ListInvoiceYear structs into JSON-compatible
  maps with proper type conversions (especially Date to ISO 8601 strings).

  All functions return {:ok, json_map} or {:error, exception}.
  """

  alias Invoice
  alias Item
  alias ListInvoiceYear
  alias InvoiceStorage.Error.EncodeFailed

  @doc """
  Encodes an Invoice struct into a JSON-compatible map.

  Converts the date field to ISO 8601 string format. Items are encoded
  recursively. All required fields must be present.

  Returns {:ok, map} on success or {:error, exception} on failure.
  """
  def encode_invoice(%Invoice{} = invoice) do
    try do
      {:ok,
       %{
         "date" => Date.to_iso8601(invoice.date),
         "number" => invoice.number,
         "bill_to" => invoice.bill_to,
         "vendor_details" => invoice.vendor_details,
         "items" => Enum.map(invoice.items, &encode_item!/1),
         "sale_amount" => invoice.sale_amount,
         "vat" => invoice.vat
       }}
    rescue
      e ->
        {:error,
         EncodeFailed.exception(
           reason: e,
           message: "Failed to encode invoice: #{inspect(e)}"
         )}
    end
  end

  def encode_invoice(data) do
    {:error,
     EncodeFailed.exception(
       reason: :invalid_type,
       message: "Expected Invoice struct, got #{inspect(data)}"
     )}
  end

  @doc """
  Encodes an Item struct into a JSON-compatible map.

  Simple three-field mapping with no type conversions needed.

  Returns {:ok, map} on success or {:error, exception} on failure.
  """
  def encode_item(%Item{} = item) do
    try do
      {:ok,
       %{
         "description" => item.description,
         "units" => item.units,
         "amount" => item.amount
       }}
    rescue
      e ->
        {:error,
         EncodeFailed.exception(
           reason: e,
           message: "Failed to encode item: #{inspect(e)}"
         )}
    end
  end

  def encode_item(data) do
    {:error,
     EncodeFailed.exception(
       reason: :invalid_type,
       message: "Expected Item struct, got #{inspect(data)}"
     )}
  end

  @doc """
  Encodes a ListInvoiceYear struct into a JSON-compatible map.

  The invoices map is converted from a map of Invoice structs keyed by
  invoice number to a list of encoded invoices.

  Returns {:ok, map} on success or {:error, exception} on failure.
  """
  def encode_list_invoice_year(%ListInvoiceYear{} = list_year) do
    try do
      invoices_list =
        list_year.invoices
        |> Enum.map(fn {_num, invoice} -> encode_invoice!(invoice) end)

      {:ok,
       %{
         "year" => list_year.year,
         "next_id" => list_year.next_id,
         "invoices" => invoices_list
       }}
    rescue
      e ->
        {:error,
         EncodeFailed.exception(
           reason: e,
           message: "Failed to encode ListInvoiceYear: #{inspect(e)}"
         )}
    end
  end

  def encode_list_invoice_year(data) do
    {:error,
     EncodeFailed.exception(
       reason: :invalid_type,
       message: "Expected ListInvoiceYear struct, got #{inspect(data)}"
     )}
  end

  @doc """
  Encodes an Invoice struct, raising on error.

  Internal helper used by encode_list_invoice_year. Raises EncodeFailed
  if encoding fails.
  """
  def encode_invoice!(invoice) do
    case encode_invoice(invoice) do
      {:ok, encoded} -> encoded
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Encodes an Item struct, raising on error.

  Internal helper. Raises EncodeFailed if encoding fails.
  """
  def encode_item!(item) do
    case encode_item(item) do
      {:ok, encoded} -> encoded
      {:error, reason} -> raise reason
    end
  end
end
