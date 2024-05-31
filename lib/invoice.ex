defmodule Invoice do
  @moduledoc """
  Documentation for invoice struct
  """
  defstruct date: nil,
            number: nil,
            bill_to: nil,
            vendor_details: nil,
            concepts: [],
            sale_amount: nil,
            vat: nil

  def new() do
    date = Date.utc_today()
    number = "#{date.year}-0000"

    %Invoice{
      date: date,
      number: number,
      concepts: [%Bill{invoice_number: number}]
    }
  end
end
