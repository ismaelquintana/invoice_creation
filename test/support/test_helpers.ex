defmodule InvoiceCreation.TestHelpers do
  @moduledoc """
  Test helpers for building test data without ExMachina (no database required).
  """

  def build_invoice(opts \\ []) do
    today = Date.utc_today()

    %Invoice{
      number: Keyword.get(opts, :number, "#{today.year}-0001"),
      date: Keyword.get(opts, :date, today),
      bill_to: Keyword.get(opts, :bill_to, "Test Customer"),
      vendor_details: Keyword.get(opts, :vendor_details, "Test Vendor"),
      items: Keyword.get(opts, :items, []),
      sale_amount: Keyword.get(opts, :sale_amount, 0),
      vat: Keyword.get(opts, :vat, 0)
    }
  end

  def build_item(opts \\ []) do
    %Item{
      description: Keyword.get(opts, :description, "Test Item"),
      units: Keyword.get(opts, :units, 1),
      amount: Keyword.get(opts, :amount, 10000)
    }
  end
end
