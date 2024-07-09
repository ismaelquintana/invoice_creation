defmodule InvoiceCreationTest do
  use ExUnit.Case
  doctest InvoiceCreation

  test "create new invoice" do
    date = Date.utc_today()
    year = date.year

    invoice = %Invoice{
      bill_to: nil,
      date: date,
      items: [],
      number: Integer.to_string(year) <> "-0000",
      sale_amount: 0,
      vat: nil,
      vendor_details: nil
    }

    assert Invoice.new() == invoice
  end

  test "create new item" do
    assert Item.new() == %Item{}
  end

  test "create new item with data" do
    item = %Item{
      description: "description test",
      units: 4,
      amount: 4
    }

    assert Item.new(
             description: "description test",
             units: 4,
             amount: 4
           ) == item
  end

  test "create list invoice year" do
    assert ListInvoiceYear.new() == %ListInvoiceYear{}
  end

  test "create list invoice" do
    list = ListInvoiceYear.new()

    assert list == %ListInvoiceYear{invoices: nil, next_id: nil, year: nil}
  end

  test "create list invoice with year" do
    list = ListInvoiceYear.new(2024)

    assert list == %ListInvoiceYear{invoices: %{}, next_id: 1, year: 2024}
  end

  test "add invoice to list invoice year" do
    invoice = Invoice.new()
    year = invoice.date.year

    _list_invoice = %ListInvoiceYear{
      invoices: %{year => invoice},
      next_id: 1,
      year: year
    }

    key_invoice = Integer.to_string(year) <> "-0001"

    list = ListInvoiceYear.new(year)
    list_with_invoice = ListInvoiceYear.add_invoice(list, invoice)

    assert list_with_invoice == %ListInvoiceYear{
             invoices: %{key_invoice => invoice},
             next_id: 2,
             year: year
           }
  end
end
