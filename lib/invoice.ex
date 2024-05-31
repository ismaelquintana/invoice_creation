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
end
