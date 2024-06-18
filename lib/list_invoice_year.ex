defmodule ListInvoiceYear do
  @moduledoc """
  Struct for list of invoices per year
  """
  defstruct year: 0, next_id: 1, invoices: []

  @typedoc """
    Type that representsListInvoiceYear struct
  """
  @type t :: %__MODULE__{year: integer() | nil, next_id: integer(), invoices: [Invoice.t() | nil]}

  @spec new() :: ListInvoiceYear.t()
  def new do
    %ListInvoiceYear{}
  end

  @spec add_invoice(ListInvoiceYear.t(), Invoice.t()) ::
          {:ok, ListInvoiceYear.t()} | {:error, String.t()}
  def add_invoice(list_invoice_year, invoice) do
    if list_invoice_year.year == invoice.date.year do
      invoice_number =
        Integer.to_string(list_invoice_year.year) <>
          "-" <> String.pad_leading(Integer.to_string(list_invoice_year.next_id), 4, "0")

      invoice_with_number = %Invoice{invoice | number: invoice_number}

      {
        :ok,
        %ListInvoiceYear{
          list_invoice_year
          | next_id: list_invoice_year.next_id + 1,
            invoices: [invoice_with_number | list_invoice_year.invoices]
        }
      }
    else
      {:error, "Year not correct!"}
    end
  end
end
