defmodule InvoiceCreationTest do
  use ExUnit.Case
  doctest InvoiceCreation

  describe "Item operations" do
    test "create new item" do
      assert Item.new() == %Item{}
    end

    test "create new item with data" do
      description =
        Faker.Lorem.words(5)
        |> Enum.join(" ")

      item = %Item{
        description: description,
        units: 4,
        amount: 4
      }

      assert Item.new(
               description: description,
               units: 4,
               amount: 4
             ) == item
    end

    test "update an item data" do
      description =
        Faker.Lorem.words(5)
        |> Enum.join(" ")

      units = 1
      amount = 1

      item1 =
        Item.new(
          description: description,
          units: units,
          amount: amount
        )

      item2 = Item.update(item1, units: 2)
      assert item2.units == 2
      refute item1.units == item2.units
    end
  end

  describe "ListInvoiceYear operations" do
    test "create list invoice year" do
      assert ListInvoiceYear.new() == %ListInvoiceYear{}
    end

    test "create list invoice" do
      list = ListInvoiceYear.new()

      assert list == %ListInvoiceYear{invoices: nil, next_id: nil, year: nil}
    end

    test "create list invoice with year" do
      list = ListInvoiceYear.new(next_id: 1, invoices: %{}, year: 2024)

      assert list == %ListInvoiceYear{invoices: %{}, next_id: 1, year: 2024}
    end

    test "add invoices to list invoice year" do
      date1 = Faker.Date.forward(1)
      date2 = Faker.Date.forward(2)
      invoice1 = Invoice.new(date: date1)
      invoice2 = Invoice.new(date: date2)
      invoice3 = Invoice.new(date: date2)
      year = invoice1.date.year

      _list_invoice = %ListInvoiceYear{
        invoices: %{year => invoice1},
        next_id: 1,
        year: year
      }

      key_invoice1 = Integer.to_string(year) <> "-0001"
      key_invoice2 = Integer.to_string(year) <> "-0002"
      key_invoice3 = Integer.to_string(year) <> "-0003"

      invoice2 = Invoice.update(invoice2, number: key_invoice2)
      invoice3 = Invoice.update(invoice3, number: key_invoice3)

      list_with_invoice =
        ListInvoiceYear.new(invoices: %{}, next_id: 1, year: year)
        |> ListInvoiceYear.add_invoice(invoice1)
        |> ListInvoiceYear.add_invoice(invoice2)
        |> ListInvoiceYear.add_invoice(invoice3)

      assert list_with_invoice == %ListInvoiceYear{
               invoices: %{
                 key_invoice1 => invoice1,
                 key_invoice2 => invoice2,
                 key_invoice3 => invoice3
               },
               next_id: 4,
               year: year
             }
    end
  end

  describe "Invoice operations" do
    test "create new invoice" do
      date = Date.utc_today()
      year = date.year

      # income_tax
      # sales_tax

      invoice = %Invoice{
        bill_to: nil,
        date: date,
        items: [],
        number: Integer.to_string(year) <> "-0001",
        sale_amount: 0,
        vat: nil,
        vendor_details: nil
      }

      assert Invoice.new() == invoice
    end

    test "create invoice with keys that do not exist in struct" do
      invoice1 = Invoice.new(year: 2024)
      invoice2 = Invoice.new()

      assert invoice1 == invoice2
    end

    test "create invoice with keys" do
      client = Faker.Company.name()
      details = Faker.Address.street_address(true)
      date = Faker.Date.forward(4)

      invoice =
        Invoice.new(
          bill_to: client,
          vendor_details: details,
          date: date
        )

      assert invoice.bill_to == client
      assert invoice.vendor_details == details
      assert invoice.date == date
    end

    test "update invoice key" do
      client = Faker.Company.name()
      details = Faker.Address.street_address(true)
      date = Faker.Date.forward(4)

      invoice =
        Invoice.new(
          bill_to: client,
          vendor_details: details,
          date: date
        )

      invoice2 = Invoice.update(invoice, vat: 21)
      assert invoice2.vat == 21
      assert invoice2.bill_to == client
      assert invoice2.date == date
      refute invoice.vat == invoice2.vat
    end
  end
end
