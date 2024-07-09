defmodule ListInvoiceYear do
  @moduledoc """
  Struct for list of invoices per year
  """
  defstruct year: nil, next_id: nil, invoices: nil

  @typedoc """
    Type that represents ListInvoiceYear struct
  """
  @type t :: %__MODULE__{
          year: integer() | nil,
          next_id: integer() | nil,
          invoices: Invoice.t() | nil
        }

  @spec new :: ListInvoiceYear.t()
  def new do
    %ListInvoiceYear{}
  end

  @spec new(integer) :: ListInvoiceYear.t()
  def new(year) do
    %ListInvoiceYear{next_id: 1, year: year, invoices: Map.new()}
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
