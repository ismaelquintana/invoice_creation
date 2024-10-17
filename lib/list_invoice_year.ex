defmodule ListInvoiceYear do
  @moduledoc """
  Struct for list of invoices per year
  """
  defstruct year: nil, next_id: 0, invoices: %{}

  @typedoc """
    Type that represents ListInvoiceYear struct
  """
  @type t :: %__MODULE__{
          year: integer() | nil,
          next_id: integer() | 0,
          invoices: Invoice.t() | %{}
        }

  @spec new :: ListInvoiceYear.t()
  def new do
    %ListInvoiceYear{}
  end

  @spec new(keyword()) :: ListInvoiceYear.t()
  def new(opts) do
    map =
      opts
      |> Enum.into(%{})

    struct(new(), map)
  end

  @spec add_invoice(ListInvoiceYear.t(), Invoice.t()) :: ListInvoiceYear.t()
  def add_invoice(list_invoice_year, invoice) do
    if list_invoice_year.year == invoice.date.year do
      invoice_number =
        Integer.to_string(list_invoice_year.year) <>
          "-" <>
          String.pad_leading(
            Integer.to_string(list_invoice_year.next_id),
            4,
            "0"
          )

      invoice_with_number = %Invoice{invoice | number: invoice_number}

      %ListInvoiceYear{
        list_invoice_year
        | next_id: list_invoice_year.next_id + 1,
          invoices:
            Map.put(
              list_invoice_year.invoices,
              invoice_number,
              invoice_with_number
            )
      }
    else
      list_invoice_year
    end
  end
end
