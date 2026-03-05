defmodule InvoiceStorage.Csv.Encoder do
  @moduledoc """
  CSV encoding functionality for exporting invoices.

  Supports two formats:
  1. **Flat format**: One row per invoice item (invoice fields repeated for each item)
  2. **Hierarchical format**: Separate invoice and items sections

  Both formats are RFC 4180 compliant and can be imported by standard spreadsheet applications.

  ## Flat Format

  Each row represents an invoice item. Invoice-level data (number, date, bill_to, etc.)
  is repeated for each item on that invoice.

  Headers:
  - `invoice_number`, `invoice_date`, `bill_to`, `vendor_details`, `vat`, `sale_amount`
  - `item_description`, `item_units`, `item_amount`, `item_total`

  Example:
  ```
  invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount,item_description,item_units,item_amount,item_total
  2024-0001,2024-01-15,Acme Corp,Our Corp,1000,50000,Service A,2,10000,20000
  2024-0001,2024-01-15,Acme Corp,Our Corp,1000,50000,Service B,3,10000,30000
  ```

  ## Hierarchical Format

  Separate sections for invoices and items. First section contains all invoices,
  second section contains all items with invoice_number references.

  More suitable for data migration and backup purposes.

  ## Usage

      iex> invoice = Factory.build(:invoice, items: [Factory.build(:item)])
      iex> csv = InvoiceStorage.Csv.Encoder.encode_flat([invoice])
      iex> is_binary(csv)
      true
  """

  @doc """
  Encodes invoices to CSV in flat format (one row per item).

  ## Parameters

    - `invoices` - List of Invoice structs to encode

  ## Returns

    - CSV string with headers and rows (RFC 4180 compliant)
  """
  @spec encode_flat([Invoice.t()]) :: String.t()
  def encode_flat(invoices) when is_list(invoices) do
    rows = Enum.flat_map(invoices, &invoice_to_flat_rows/1)

    [flat_headers() | rows]
    |> CSV.encode()
    |> Enum.join("")
  end

  @doc """
  Encodes invoices to CSV in hierarchical format.

  Generates two sections:
  1. INVOICES section with invoice-level data
  2. ITEMS section with line items

  ## Parameters

    - `invoices` - List of Invoice structs to encode

  ## Returns

    - CSV string with two sections separated by blank lines
  """
  @spec encode_hierarchical([Invoice.t()]) :: String.t()
  def encode_hierarchical(invoices) when is_list(invoices) do
    invoice_section = encode_invoice_section(invoices)
    items_section = encode_items_section(invoices)

    "#{invoice_section}\n\n#{items_section}"
  end

  # ============================================================================
  # Private Helpers - Flat Format
  # ============================================================================

  defp flat_headers do
    [
      "invoice_number",
      "invoice_date",
      "bill_to",
      "vendor_details",
      "vat",
      "sale_amount",
      "item_description",
      "item_units",
      "item_amount",
      "item_total"
    ]
  end

  defp invoice_to_flat_rows(%Invoice{items: []} = invoice) do
    # Invoice with no items gets one row with empty item fields
    [
      [
        invoice.number,
        Date.to_iso8601(invoice.date),
        invoice.bill_to || "",
        invoice.vendor_details || "",
        invoice.vat,
        invoice.sale_amount,
        "",
        "",
        "",
        ""
      ]
    ]
  end

  defp invoice_to_flat_rows(%Invoice{items: items} = invoice) do
    Enum.map(items, fn item ->
      item_total = item.units * item.amount

      [
        invoice.number,
        Date.to_iso8601(invoice.date),
        invoice.bill_to || "",
        invoice.vendor_details || "",
        invoice.vat,
        invoice.sale_amount,
        item.description,
        item.units,
        item.amount,
        item_total
      ]
    end)
  end

  # ============================================================================
  # Private Helpers - Hierarchical Format
  # ============================================================================

  defp encode_invoice_section(invoices) do
    invoice_headers = [
      "invoice_number",
      "invoice_date",
      "bill_to",
      "vendor_details",
      "vat",
      "sale_amount"
    ]

    invoice_rows =
      Enum.map(invoices, fn invoice ->
        [
          invoice.number,
          Date.to_iso8601(invoice.date),
          invoice.bill_to || "",
          invoice.vendor_details || "",
          invoice.vat,
          invoice.sale_amount
        ]
      end)

    [["INVOICES"] | [invoice_headers | invoice_rows]]
    |> CSV.encode()
    |> Enum.join("")
  end

  defp encode_items_section(invoices) do
    item_headers = [
      "invoice_number",
      "item_description",
      "item_units",
      "item_amount",
      "item_total"
    ]

    item_rows =
      Enum.flat_map(invoices, fn invoice ->
        Enum.map(invoice.items, fn item ->
          item_total = item.units * item.amount

          [
            invoice.number,
            item.description,
            item.units,
            item.amount,
            item_total
          ]
        end)
      end)

    [["ITEMS"] | [item_headers | item_rows]]
    |> CSV.encode()
    |> Enum.join("")
  end
end
