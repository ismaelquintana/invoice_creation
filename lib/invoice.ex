defmodule Invoice do
  @moduledoc """
  Documentation for invoice struct
  """
  defstruct date: Date.utc_today(),
            number: "#{Date.utc_today().year}-0001",
            bill_to: nil,
            vendor_details: nil,
            items: [],
            sale_amount: 0,
            vat: 0

  @typedoc """
    Type that represents Invoice struct
  """
  @type t :: %__MODULE__{
          date: Date.t(),
          number: String.t(),
          bill_to: String.t() | nil,
          vendor_details: String.t() | nil,
          items: [Item.t()],
          sale_amount: integer(),
          vat: integer()
        }

  @spec new :: Invoice.t()
  def new do
    %Invoice{}
  end

  @spec new(keyword()) :: Invoice.t()
  def new(opts) do
    struct(__MODULE__, opts)
  end

  @spec update(Invoice.t(), keyword()) :: Invoice.t()
  def update(invoice, opts) do
    struct(invoice, opts)
  end

  @spec add_item(Invoice.t(), Item.t()) :: Invoice.t()
  def add_item(invoice, %Item{} = item) do
    %Invoice{
      invoice
      | items: [item | invoice.items],
        sale_amount: invoice.sale_amount + item.amount * item.units
    }
  end

  def add_item(_invoice, nil) do
    raise ArgumentError, message: "Item cannot be nil"
  end

  @spec add_list_items(Invoice.t(), list(Item.t())) :: Invoice.t()
  def add_list_items(invoice, items) do
    Enum.reduce(items, invoice, fn i, invoice -> add_item(invoice, i) end)
  end
end
