defmodule Invoice do
  @moduledoc """
  Documentation for invoice struct
  """
  defstruct date: nil,
            number: nil,
            bill_to: nil,
            vendor_details: nil,
            items: [],
            sale_amount: nil,
            vat: nil

  @typedoc """
    Type that represents Invoice struct
  """
  @type t :: %__MODULE__{
          date: Date.t() | nil,
          number: String.t() | nil,
          bill_to: String.t() | nil,
          vendor_details: String.t() | nil,
          items: [Item.t() | nil],
          sale_amount: integer | nil,
          vat: integer | nil
        }

  @spec new :: Invoice.t()
  def new do
    date = Date.utc_today()
    number = "#{date.year}-0000"

    %Invoice{
      date: date,
      number: number,
      sale_amount: 0
    }
  end

  @spec new(keyword()) :: Invoice.t()
  def new(opts) do
    invoice = new()

    Enum.reduce(
      opts,
      invoice,
      fn {k, v}, invoice ->
        Map.update(
          invoice,
          k,
          v,
          fn _x -> v end
        )
      end
    )
  end

  @spec add_item(Invoice.t(), Item.t()) :: Invoice.t()
  def add_item(invoice, item) do
    %Invoice{
      invoice
      | items: [item | invoice.items],
        sale_amount: invoice.sale_amount + item.amount * item.units
    }
  end

  @spec add_list_items(Invoice.t(), list(Item.t())) :: Invoice.t()
  def add_list_items(invoice, items) do
    items
    |> Enum.reduce(invoice, fn i, invoice -> add_item(invoice, i) end)
  end
end
