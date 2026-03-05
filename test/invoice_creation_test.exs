defmodule InvoiceCreationTest do
  use ExUnit.Case
  doctest InvoiceCreation

  describe "Item operations" do
    test "create new item" do
      assert {:error, error} = Item.new()
      assert error.type == :invalid_item
    end

    test "create new item with valid data" do
      description =
        Faker.Lorem.words(5)
        |> Enum.join(" ")

      {:ok, item} =
        Item.new(
          description: description,
          units: 4,
          amount: 4
        )

      assert item.description == description
      assert item.units == 4
      assert item.amount == 4
    end

    test "create new item with required fields" do
      {:ok, item} =
        Item.new(
          description: "Test Item",
          units: 5,
          amount: 100
        )

      assert item.description == "Test Item"
      assert item.units == 5
      assert item.amount == 100
    end

    test "update an item data" do
      {:ok, item1} =
        Item.new(
          description: "Original",
          units: 1,
          amount: 1
        )

      {:ok, item2} = Item.update(item1, units: 2)
      assert item2.units == 2
      refute item1.units == item2.units
    end

    test "reject item with empty description" do
      assert {:error, error} =
               Item.new(description: "", units: 1, amount: 1)

      assert error.type == :invalid_item
      assert String.contains?(Item.Error.to_user_message(error), "description")
    end

    test "reject item with zero units" do
      assert {:error, error} =
               Item.new(description: "Item", units: 0, amount: 100)

      assert error.type == :invalid_item
      assert String.contains?(Item.Error.to_user_message(error), "units")
    end

    test "reject item with negative units" do
      assert {:error, error} =
               Item.new(description: "Item", units: -5, amount: 100)

      assert error.type == :invalid_item
      assert String.contains?(Item.Error.to_user_message(error), "units")
    end

    test "reject item with zero amount" do
      assert {:error, error} =
               Item.new(description: "Item", units: 5, amount: 0)

      assert error.type == :invalid_item
      assert String.contains?(Item.Error.to_user_message(error), "amount")
    end

    test "reject item with negative amount" do
      assert {:error, error} =
               Item.new(description: "Item", units: 5, amount: -100)

      assert error.type == :invalid_item
      assert String.contains?(Item.Error.to_user_message(error), "amount")
    end

    test "reject item with description exceeding max length (500 chars)" do
      long_description = String.duplicate("a", 501)

      assert {:error, error} =
               Item.new(description: long_description, units: 5, amount: 100)

      assert error.type == :invalid_item
      message = Item.Error.to_user_message(error)
      assert String.contains?(message, "description")
    end

    test "accept item with description at max length (500 chars)" do
      max_description = String.duplicate("a", 500)

      assert {:ok, item} =
               Item.new(description: max_description, units: 5, amount: 100)

      assert item.description == max_description
    end

    test "reject item with units exceeding max value (1,000,000)" do
      assert {:error, error} =
               Item.new(description: "Item", units: 1_000_001, amount: 100)

      assert error.type == :invalid_item
      message = Item.Error.to_user_message(error)
      assert String.contains?(message, "units")
    end

    test "accept item with units at max value (1,000,000)" do
      assert {:ok, item} =
               Item.new(description: "Item", units: 1_000_000, amount: 100)

      assert item.units == 1_000_000
    end

    test "reject item with amount exceeding max value (999,999,999)" do
      assert {:error, error} =
               Item.new(description: "Item", units: 5, amount: 1_000_000_000)

      assert error.type == :invalid_item
      message = Item.Error.to_user_message(error)
      assert String.contains?(message, "amount")
    end

    test "accept item with amount at max value (999,999,999)" do
      assert {:ok, item} =
               Item.new(description: "Item", units: 5, amount: 999_999_999)

      assert item.amount == 999_999_999
    end
  end

  describe "ListInvoiceYear operations" do
    test "create list invoice year" do
      {:ok, list} = ListInvoiceYear.new()
      assert list.year == nil
      assert list.next_id == 0
      assert list.invoices == %{}
    end

    test "create list invoice with year" do
      {:ok, list} = ListInvoiceYear.new(year: 2024)

      assert list.year == 2024
      assert list.next_id == 0
      assert list.invoices == %{}
    end

    test "create list invoice with year and next_id" do
      {:ok, list} = ListInvoiceYear.new(year: 2024, next_id: 5)

      assert list.year == 2024
      assert list.next_id == 5
      assert list.invoices == %{}
    end

    test "reject invalid year (zero)" do
      assert {:error, error} = ListInvoiceYear.new(year: 0)
      assert error.type == :invalid_year
      assert String.contains?(ListInvoiceYear.Error.to_user_message(error), "positive")
    end

    test "reject invalid year (negative)" do
      assert {:error, error} = ListInvoiceYear.new(year: -2024)
      assert error.type == :invalid_year
      assert String.contains?(ListInvoiceYear.Error.to_user_message(error), "positive")
    end

    test "reject invalid next_id (negative)" do
      assert {:error, error} = ListInvoiceYear.new(next_id: -1)
      assert error.type == :invalid_next_id
      assert String.contains?(ListInvoiceYear.Error.to_user_message(error), "non-negative")
    end

    test "add invoices to list invoice year" do
      {:ok, date1} = Date.new(2024, 1, 15)
      {:ok, date2} = Date.new(2024, 2, 20)
      {:ok, invoice1} = Invoice.new(date: date1)
      {:ok, invoice2} = Invoice.new(date: date2)

      year = date1.year

      {:ok, list} = ListInvoiceYear.new(year: year)
      {:ok, list_with_invoice1} = ListInvoiceYear.add_invoice(list, invoice1)

      assert list_with_invoice1.next_id == 1
      assert map_size(list_with_invoice1.invoices) == 1

      key_invoice1 = "2024-0001"
      assert Map.has_key?(list_with_invoice1.invoices, key_invoice1)

      {:ok, list_with_invoice2} = ListInvoiceYear.add_invoice(list_with_invoice1, invoice2)
      assert list_with_invoice2.next_id == 2
      assert map_size(list_with_invoice2.invoices) == 2

      key_invoice2 = "2024-0002"
      assert Map.has_key?(list_with_invoice2.invoices, key_invoice2)
    end

    test "reject adding invoice with mismatched year" do
      {:ok, date1} = Date.new(2024, 1, 15)
      {:ok, date2} = Date.new(2025, 2, 20)
      {:ok, invoice1} = Invoice.new(date: date1)
      {:ok, invoice2} = Invoice.new(date: date2)

      {:ok, list} = ListInvoiceYear.new(year: 2024)
      {:ok, _list_with_invoice1} = ListInvoiceYear.add_invoice(list, invoice1)

      # Invoice 2 has year 2025, but list is for 2024
      assert {:error, error} = ListInvoiceYear.add_invoice(list, invoice2)
      assert error.type == :year_mismatch
      assert String.contains?(ListInvoiceYear.Error.to_user_message(error), "2025")
      assert String.contains?(ListInvoiceYear.Error.to_user_message(error), "2024")
    end

    test "reject adding invoice when year not set" do
      {:ok, date1} = Date.new(2024, 1, 15)
      {:ok, invoice1} = Invoice.new(date: date1)

      {:ok, list} = ListInvoiceYear.new()
      # Year is nil, should fail

      assert {:error, error} = ListInvoiceYear.add_invoice(list, invoice1)
      assert error.type == :year_not_set
      assert String.contains?(ListInvoiceYear.Error.to_user_message(error), "year must be set")
    end

    test "reject adding nil invoice" do
      {:ok, list} = ListInvoiceYear.new(year: 2024)
      assert {:error, error} = ListInvoiceYear.add_invoice(list, nil)
      assert error.type == :nil_invoice
      assert String.contains?(ListInvoiceYear.Error.to_user_message(error), "cannot be nil")
    end

    test "reject adding invalid invoice type" do
      {:ok, list} = ListInvoiceYear.new(year: 2024)
      assert {:error, error} = ListInvoiceYear.add_invoice(list, "not an invoice")
      assert error.type == :invalid_invoice_type
      assert String.contains?(ListInvoiceYear.Error.to_user_message(error), "Invoice struct")
    end
  end

  describe "Invoice operations" do
    test "create new invoice" do
      {:ok, invoice} = Invoice.new()
      assert invoice.bill_to == nil
      assert invoice.items == []
      assert invoice.sale_amount == 0
      assert invoice.vat == 0
      assert match?(%Date{}, invoice.date)
      assert is_binary(invoice.number)
    end

    test "create invoice with keys" do
      client = "Acme Corp"
      details = "123 Business St"
      {:ok, date} = Date.new(2024, 3, 15)

      {:ok, invoice} =
        Invoice.new(
          bill_to: client,
          vendor_details: details,
          date: date
        )

      assert invoice.bill_to == client
      assert invoice.vendor_details == details
      assert invoice.date == date
    end

    test "reject invoice with invalid vat (negative)" do
      assert {:error, error} = Invoice.new(vat: -10)
      assert error.type == :invalid_vat
      assert String.contains?(Invoice.Error.to_user_message(error), "non-negative")
    end

    test "reject invoice with invalid sale_amount (negative)" do
      assert {:error, error} = Invoice.new(sale_amount: -100)
      assert error.type == :invalid_sale_amount
      assert String.contains?(Invoice.Error.to_user_message(error), "non-negative")
    end

    test "update invoice key" do
      {:ok, invoice} = Invoice.new()

      {:ok, invoice2} = Invoice.update(invoice, vat: 21)
      assert invoice2.vat == 21
    end

    test "add item to invoice" do
      {:ok, item} = Item.new(description: "Service", units: 2, amount: 100)
      {:ok, invoice} = Invoice.new()

      {:ok, updated} = Invoice.add_item(invoice, item)

      assert length(updated.items) == 1
      assert updated.sale_amount == 200
    end

    test "add multiple items to invoice" do
      {:ok, item1} = Item.new(description: "Service 1", units: 2, amount: 100)
      {:ok, item2} = Item.new(description: "Service 2", units: 3, amount: 50)
      {:ok, invoice} = Invoice.new()

      {:ok, updated1} = Invoice.add_item(invoice, item1)
      {:ok, updated2} = Invoice.add_item(updated1, item2)

      assert length(updated2.items) == 2
      assert updated2.sale_amount == 350
    end

    test "add list of items to invoice" do
      {:ok, item1} = Item.new(description: "Service 1", units: 2, amount: 100)
      {:ok, item2} = Item.new(description: "Service 2", units: 3, amount: 50)
      {:ok, invoice} = Invoice.new()

      {:ok, updated} = Invoice.add_list_items(invoice, [item1, item2])

      assert length(updated.items) == 2
      assert updated.sale_amount == 350
    end

    test "reject adding nil item" do
      {:ok, invoice} = Invoice.new()
      assert {:error, error} = Invoice.add_item(invoice, nil)
      assert error.type == :nil_item
      assert String.contains?(Invoice.Error.to_user_message(error), "cannot be nil")
    end

    test "reject adding invalid item" do
      {:ok, invoice} = Invoice.new()
      invalid_item = %Item{description: "", units: 0, amount: 0}

      assert {:error, error} = Invoice.add_item(invoice, invalid_item)
      assert error.type == :invalid_item

      message = Invoice.Error.to_user_message(error)
      assert String.contains?(message, "description")
      assert String.contains?(message, "units")
      assert String.contains?(message, "amount")
    end

    test "reject adding item with single invalid field" do
      {:ok, invoice} = Invoice.new()
      invalid_item = %Item{description: "Valid", units: 5, amount: 0}

      assert {:error, error} = Invoice.add_item(invoice, invalid_item)
      assert error.type == :invalid_item

      message = Invoice.Error.to_user_message(error)
      assert String.contains?(message, "amount")
      refute String.contains?(message, "description")
      refute String.contains?(message, "units")
    end

    test "error for non-list items parameter" do
      {:ok, invoice} = Invoice.new()
      assert {:error, error} = Invoice.add_list_items(invoice, "not a list")
      assert error.type == :invalid_items_list
      assert String.contains?(Invoice.Error.to_user_message(error), "list")
    end

    test "reject invoice with number exceeding max length (20 chars)" do
      long_number = String.duplicate("1", 21)

      assert {:error, error} = Invoice.new(number: long_number)

      assert error.type == :number_too_long
      message = Invoice.Error.to_user_message(error)
      assert String.contains?(message, "length")
    end

    test "accept invoice with number at max length (20 chars)" do
      max_number = String.duplicate("1", 20)

      assert {:ok, invoice} = Invoice.new(number: max_number)

      assert invoice.number == max_number
    end

    test "reject invoice with bill_to exceeding max length (500 chars)" do
      long_bill_to = String.duplicate("a", 501)

      assert {:error, error} = Invoice.new(bill_to: long_bill_to)

      assert error.type == :bill_to_too_long
      message = Invoice.Error.to_user_message(error)
      assert String.contains?(message, "length")
    end

    test "accept invoice with bill_to at max length (500 chars)" do
      max_bill_to = String.duplicate("a", 500)

      assert {:ok, invoice} = Invoice.new(bill_to: max_bill_to)

      assert invoice.bill_to == max_bill_to
    end

    test "reject invoice with vendor_details exceeding max length (500 chars)" do
      long_vendor_details = String.duplicate("a", 501)

      assert {:error, error} = Invoice.new(vendor_details: long_vendor_details)

      assert error.type == :vendor_details_too_long
      message = Invoice.Error.to_user_message(error)
      assert String.contains?(message, "length")
    end

    test "accept invoice with vendor_details at max length (500 chars)" do
      max_vendor_details = String.duplicate("a", 500)

      assert {:ok, invoice} = Invoice.new(vendor_details: max_vendor_details)

      assert invoice.vendor_details == max_vendor_details
    end

    test "reject invoice with VAT exceeding max value (999,999)" do
      assert {:error, error} = Invoice.new(vat: 1_000_000)

      assert error.type == :vat_too_large
      message = Invoice.Error.to_user_message(error)
      assert String.contains?(message, "max")
    end

    test "accept invoice with VAT at max value (999,999)" do
      assert {:ok, invoice} = Invoice.new(vat: 999_999)

      assert invoice.vat == 999_999
    end

    test "reject invoice with sale_amount exceeding max value (999,999,999)" do
      assert {:error, error} = Invoice.new(sale_amount: 1_000_000_000)

      assert error.type == :sale_amount_too_large
      message = Invoice.Error.to_user_message(error)
      assert String.contains?(message, "max")
    end

    test "accept invoice with sale_amount at max value (999,999,999)" do
      assert {:ok, invoice} = Invoice.new(sale_amount: 999_999_999)

      assert invoice.sale_amount == 999_999_999
    end

    test "reject invoice with future date" do
      {:ok, future_date} = Date.new(2099, 12, 31)

      assert {:error, error} = Invoice.new(date: future_date)

      assert error.type == :date_in_future
      message = Invoice.Error.to_user_message(error)
      assert String.contains?(message, "future")
    end

    test "reject invoice with date older than 10 years" do
      {:ok, old_date} = Date.new(2015, 1, 1)

      assert {:error, error} = Invoice.new(date: old_date)

      assert error.type == :date_too_old
      message = Invoice.Error.to_user_message(error)
      assert String.contains?(message, "old")
    end

    test "accept invoice with today's date" do
      today = Date.utc_today()

      assert {:ok, invoice} = Invoice.new(date: today)

      assert invoice.date == today
    end

    test "accept invoice with date within valid range (within last 10 years)" do
      {:ok, valid_date} = Date.new(2020, 6, 15)

      assert {:ok, invoice} = Invoice.new(date: valid_date)

      assert invoice.date == valid_date
    end
  end
end
