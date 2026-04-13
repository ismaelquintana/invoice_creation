defmodule InvoiceCreationTest do
  use ExUnit.Case
  doctest InvoiceCreation

  setup do
    # Clean up storage before each test
    on_exit(fn -> cleanup_test_storage() end)
    :ok
  end

  # ============================================================================
  # InvoiceCreation Facade Tests
  # ============================================================================

  describe "create_invoice/0 and create_invoice/1" do
    test "create_invoice/0 creates invoice with defaults" do
      {:ok, invoice} = InvoiceCreation.create_invoice()

      assert is_struct(invoice, Invoice)
      assert invoice.number == "#{Date.utc_today().year}-0001"
      assert invoice.date == Date.utc_today()
      assert invoice.items == []
      assert invoice.sale_amount == 0
      assert invoice.vat == 0
    end

    test "create_invoice/1 creates invoice with custom options" do
      bill_to = "Acme Corp"

      {:ok, invoice} = InvoiceCreation.create_invoice(bill_to: bill_to)

      assert invoice.bill_to == bill_to
      assert invoice.date == Date.utc_today()
    end

    test "create_invoice/1 returns error for invalid options" do
      {:error, error} = InvoiceCreation.create_invoice(vat: -10)

      assert is_struct(error, Invoice.Error)
    end

    test "create_invoice/1 accepts custom date" do
      custom_date = Date.add(Date.utc_today(), -30)
      {:ok, invoice} = InvoiceCreation.create_invoice(date: custom_date)

      assert invoice.date == custom_date
    end

    test "create_invoice/1 rejects future dates" do
      future_date = Date.add(Date.utc_today(), 1)
      {:error, error} = InvoiceCreation.create_invoice(date: future_date)

      assert is_struct(error, Invoice.Error)
    end

    test "create_invoice/1 accepts custom number" do
      number = "2024-CUSTOM"
      {:ok, invoice} = InvoiceCreation.create_invoice(number: number)

      assert invoice.number == number
    end

    test "create_invoice/1 rejects number > 20 chars" do
      too_long = "2024-" <> String.duplicate("x", 20)
      {:error, error} = InvoiceCreation.create_invoice(number: too_long)

      assert is_struct(error, Invoice.Error)
    end
  end

  describe "create_item/3" do
    test "create_item/3 creates valid item" do
      {:ok, item} = InvoiceCreation.create_item("Consulting", 5, 100)

      assert is_struct(item, Item)
      assert item.description == "Consulting"
      assert item.units == 5
      assert item.amount == 100
    end

    test "create_item/3 returns error for empty description" do
      {:error, error} = InvoiceCreation.create_item("", 5, 100)

      assert is_struct(error, Item.Error)
    end

    test "create_item/3 returns error for zero units" do
      {:error, error} = InvoiceCreation.create_item("Service", 0, 100)

      assert is_struct(error, Item.Error)
    end

    test "create_item/3 returns error for negative amount" do
      {:error, error} = InvoiceCreation.create_item("Service", 5, -10)

      assert is_struct(error, Item.Error)
    end

    test "create_item/3 creates item with max description length" do
      long_desc = String.duplicate("x", 500)
      {:ok, item} = InvoiceCreation.create_item(long_desc, 1, 100)

      assert byte_size(item.description) == 500
    end

    test "create_item/3 rejects description > 500 chars" do
      too_long = String.duplicate("x", 501)
      {:error, error} = InvoiceCreation.create_item(too_long, 1, 100)

      assert is_struct(error, Item.Error)
    end
  end

  describe "add_item_to_invoice/2" do
    test "add_item_to_invoice/2 adds item and updates sale_amount" do
      {:ok, invoice} = InvoiceCreation.create_invoice()
      {:ok, item} = InvoiceCreation.create_item("Service", 5, 100)

      {:ok, updated} = InvoiceCreation.add_item_to_invoice(invoice, item)

      assert length(updated.items) == 1
      # 5 * 100
      assert updated.sale_amount == 500
      assert hd(updated.items) == item
    end

    test "add_item_to_invoice/2 returns error for nil item" do
      {:ok, invoice} = InvoiceCreation.create_invoice()

      {:error, error} = InvoiceCreation.add_item_to_invoice(invoice, nil)

      assert is_struct(error, Invoice.Error)
    end

    test "add_item_to_invoice/2 handles invalid item" do
      {:ok, invoice} = InvoiceCreation.create_invoice()
      invalid_item = %{description: "Invalid"}

      {:error, error} = InvoiceCreation.add_item_to_invoice(invoice, invalid_item)

      assert is_struct(error, Invoice.Error)
    end

    test "add_item_to_invoice/2 maintains all items" do
      {:ok, invoice} = InvoiceCreation.create_invoice()
      {:ok, item1} = InvoiceCreation.create_item("Item 1", 1, 100)
      {:ok, item2} = InvoiceCreation.create_item("Item 2", 2, 50)

      {:ok, updated1} = InvoiceCreation.add_item_to_invoice(invoice, item1)
      {:ok, updated2} = InvoiceCreation.add_item_to_invoice(updated1, item2)

      assert length(updated2.items) == 2
      # (1*100) + (2*50)
      assert updated2.sale_amount == 200
    end
  end

  describe "add_items_to_invoice/2" do
    test "add_items_to_invoice/2 adds multiple items at once" do
      {:ok, invoice} = InvoiceCreation.create_invoice()
      {:ok, item1} = InvoiceCreation.create_item("Item 1", 2, 100)
      {:ok, item2} = InvoiceCreation.create_item("Item 2", 3, 50)

      {:ok, updated} = InvoiceCreation.add_items_to_invoice(invoice, [item1, item2])

      assert length(updated.items) == 2
      assert updated.sale_amount == 350
    end

    test "add_items_to_invoice/2 fails if any item is invalid" do
      {:ok, invoice} = InvoiceCreation.create_invoice()
      {:ok, valid_item} = InvoiceCreation.create_item("Valid", 1, 100)
      invalid_item = %{description: "Invalid"}

      {:error, error} = InvoiceCreation.add_items_to_invoice(invoice, [valid_item, invalid_item])

      assert is_struct(error, Invoice.Error)
    end

    test "add_items_to_invoice/2 works with empty list" do
      {:ok, invoice} = InvoiceCreation.create_invoice()

      {:ok, updated} = InvoiceCreation.add_items_to_invoice(invoice, [])

      assert updated.items == []
      assert updated.sale_amount == 0
    end
  end

  # ============================================================================
  # Persistence: Individual Invoices
  # ============================================================================

  describe "save_invoice/1 and load_invoice/2" do
    test "save_invoice/1 and load_invoice/2 roundtrip successfully" do
      {:ok, invoice} = InvoiceCreation.create_invoice(bill_to: "Test Customer")
      {:ok, item} = InvoiceCreation.create_item("Service", 2, 100)
      {:ok, invoice_with_item} = InvoiceCreation.add_item_to_invoice(invoice, item)

      :ok = InvoiceCreation.save_invoice(invoice_with_item)

      {:ok, loaded} =
        InvoiceCreation.load_invoice(invoice_with_item.number, invoice_with_item.date.year)

      assert loaded.bill_to == invoice_with_item.bill_to
      assert loaded.sale_amount == invoice_with_item.sale_amount
      assert length(loaded.items) == 1
    end

    test "save_invoice/1 handles multiple items" do
      {:ok, invoice} = InvoiceCreation.create_invoice()
      {:ok, item1} = InvoiceCreation.create_item("Item 1", 1, 100)
      {:ok, item2} = InvoiceCreation.create_item("Item 2", 2, 50)
      {:ok, invoice_with_items} = InvoiceCreation.add_items_to_invoice(invoice, [item1, item2])

      :ok = InvoiceCreation.save_invoice(invoice_with_items)

      {:ok, loaded} =
        InvoiceCreation.load_invoice(invoice_with_items.number, invoice_with_items.date.year)

      assert length(loaded.items) == 2
    end

    test "load_invoice/2 returns error for non-existent invoice" do
      {:error, _error} = InvoiceCreation.load_invoice("2024-9999", 2024)

      # Error structure depends on storage implementation
    end

    test "load_invoice/2 distinguishes invoices by year" do
      year1_date = Date.new!(2023, 6, 15)
      year2_date = Date.new!(2024, 6, 15)

      {:ok, invoice1} = InvoiceCreation.create_invoice(date: year1_date, number: "2023-0001")
      {:ok, invoice2} = InvoiceCreation.create_invoice(date: year2_date, number: "2023-0001")

      :ok = InvoiceCreation.save_invoice(invoice1)
      :ok = InvoiceCreation.save_invoice(invoice2)

      {:ok, loaded1} = InvoiceCreation.load_invoice("2023-0001", 2023)
      {:ok, loaded2} = InvoiceCreation.load_invoice("2023-0001", 2024)

      assert loaded1.date.year == 2023
      assert loaded2.date.year == 2024
    end
  end

  describe "invoice_exists?/2" do
    test "invoice_exists?/2 returns true for saved invoice" do
      {:ok, invoice} = InvoiceCreation.create_invoice()
      :ok = InvoiceCreation.save_invoice(invoice)

      assert InvoiceCreation.invoice_exists?(invoice.number, invoice.date.year)
    end

    test "invoice_exists?/2 returns false for non-existent invoice" do
      refute InvoiceCreation.invoice_exists?("2024-9999", 2024)
    end

    test "invoice_exists?/2 distinguishes by year" do
      {:ok, invoice} = InvoiceCreation.create_invoice(date: ~D[2023-06-15], number: "2023-0001")
      :ok = InvoiceCreation.save_invoice(invoice)

      assert InvoiceCreation.invoice_exists?("2023-0001", 2023)
      refute InvoiceCreation.invoice_exists?("2023-0001", 2024)
    end
  end

  describe "delete_invoice/2" do
    test "delete_invoice/2 removes saved invoice" do
      {:ok, invoice} = InvoiceCreation.create_invoice()
      :ok = InvoiceCreation.save_invoice(invoice)

      assert InvoiceCreation.invoice_exists?(invoice.number, invoice.date.year)

      :ok = InvoiceCreation.delete_invoice(invoice.number, invoice.date.year)

      refute InvoiceCreation.invoice_exists?(invoice.number, invoice.date.year)
    end

    test "delete_invoice/2 handles non-existent invoice gracefully" do
      result = InvoiceCreation.delete_invoice("2024-9999", 2024)

      # May return :ok or error depending on implementation
      assert result == :ok or is_tuple(result)
    end

    test "delete_invoice/2 doesn't affect other years" do
      {:ok, inv1} = InvoiceCreation.create_invoice(date: ~D[2023-06-15], number: "2023-0001")
      {:ok, inv2} = InvoiceCreation.create_invoice(date: ~D[2024-06-15], number: "2024-0001")

      :ok = InvoiceCreation.save_invoice(inv1)
      :ok = InvoiceCreation.save_invoice(inv2)

      :ok = InvoiceCreation.delete_invoice("2023-0001", 2023)

      refute InvoiceCreation.invoice_exists?("2023-0001", 2023)
      assert InvoiceCreation.invoice_exists?("2024-0001", 2024)
    end
  end

  # ============================================================================
  # Persistence: Year Lists
  # ============================================================================

  describe "create_year_list/0 and create_year_list/1" do
    test "create_year_list/0 creates list for current year" do
      {:ok, list} = InvoiceCreation.create_year_list()

      assert list.year == Date.utc_today().year
      assert list.next_id == 0
      assert list.invoices == %{}
    end

    test "create_year_list/1 creates list for specific year" do
      {:ok, list} = InvoiceCreation.create_year_list(2024)

      assert list.year == 2024
      assert list.next_id == 0
    end

    test "create_year_list/1 returns error for invalid year" do
      {:error, error} = InvoiceCreation.create_year_list(0)

      assert is_struct(error, ListInvoiceYear.Error)
    end
  end

  describe "save_year/1 and load_year/1" do
    test "save_year/1 and load_year/1 roundtrip successfully" do
      {:ok, list} = InvoiceCreation.create_year_list(2024)
      {:ok, invoice} = InvoiceCreation.create_invoice(date: ~D[2024-06-15])
      {:ok, item} = InvoiceCreation.create_item("Service", 1, 100)
      {:ok, invoice_with_item} = InvoiceCreation.add_item_to_invoice(invoice, item)
      {:ok, list_with_invoice} = ListInvoiceYear.add_invoice(list, invoice_with_item)

      :ok = InvoiceCreation.save_year(list_with_invoice)

      {:ok, loaded_list} = InvoiceCreation.load_year(2024)

      assert loaded_list.year == 2024
      assert map_size(loaded_list.invoices) == 1
    end

    test "save_year/1 persists multiple invoices" do
      {:ok, list} = InvoiceCreation.create_year_list(2024)

      invoices =
        Enum.map(1..3, fn i ->
          {:ok, inv} =
            InvoiceCreation.create_invoice(date: ~D[2024-06-15], number: "2024-000#{i}")

          {:ok, item} = InvoiceCreation.create_item("Item #{i}", i, 100)
          {:ok, with_item} = InvoiceCreation.add_item_to_invoice(inv, item)
          with_item
        end)

      {:ok, final_list} =
        Enum.reduce_while(invoices, {:ok, list}, fn inv, {:ok, acc} ->
          case ListInvoiceYear.add_invoice(acc, inv) do
            {:ok, updated} -> {:cont, {:ok, updated}}
            error -> {:halt, error}
          end
        end)

      :ok = InvoiceCreation.save_year(final_list)

      {:ok, loaded} = InvoiceCreation.load_year(2024)

      assert map_size(loaded.invoices) == 3
    end

    test "load_year/1 returns error for non-existent year" do
      {:error, _error} = InvoiceCreation.load_year(9999)

      # Error structure depends on implementation
    end
  end

  describe "list_stored_years/0" do
    test "list_stored_years/0 returns empty list initially" do
      {:ok, years} = InvoiceCreation.list_stored_years()

      assert is_list(years)
    end

    test "list_stored_years/0 includes saved years" do
      {:ok, list2024} = InvoiceCreation.create_year_list(2024)
      {:ok, list2023} = InvoiceCreation.create_year_list(2023)

      :ok = InvoiceCreation.save_year(list2024)
      :ok = InvoiceCreation.save_year(list2023)

      {:ok, years} = InvoiceCreation.list_stored_years()

      assert Enum.member?(years, 2024)
      assert Enum.member?(years, 2023)
    end
  end

  describe "count_invoices_in_year/1" do
    test "count_invoices_in_year/1 returns count for year" do
      {:ok, list} = InvoiceCreation.create_year_list(2024)

      invoices =
        Enum.map(1..5, fn i ->
          {:ok, inv} =
            InvoiceCreation.create_invoice(date: ~D[2024-06-15], number: "2024-000#{i}")

          inv
        end)

      {:ok, final_list} =
        Enum.reduce_while(invoices, {:ok, list}, fn inv, {:ok, acc} ->
          case ListInvoiceYear.add_invoice(acc, inv) do
            {:ok, updated} -> {:cont, {:ok, updated}}
            error -> {:halt, error}
          end
        end)

      :ok = InvoiceCreation.save_year(final_list)

      {:ok, count} = InvoiceCreation.count_invoices_in_year(2024)

      assert count == 5
    end

    test "count_invoices_in_year/1 returns 0 for year with no invoices" do
      {:ok, count} = InvoiceCreation.count_invoices_in_year(9999)

      assert count == 0
    end
  end

  # ============================================================================
  # Export & Import (Backup/Restore)
  # ============================================================================

  describe "export_year/1" do
    test "export_year/1 exports invoices as JSON string" do
      {:ok, list} = InvoiceCreation.create_year_list(2024)
      {:ok, invoice} = InvoiceCreation.create_invoice(date: ~D[2024-06-15])
      {:ok, item} = InvoiceCreation.create_item("Service", 1, 100)
      {:ok, invoice_with_item} = InvoiceCreation.add_item_to_invoice(invoice, item)
      {:ok, list_with_invoice} = ListInvoiceYear.add_invoice(list, invoice_with_item)

      :ok = InvoiceCreation.save_year(list_with_invoice)

      {:ok, json} = InvoiceCreation.export_year(2024)

      assert is_binary(json)
      assert String.contains?(json, "2024")
      assert String.contains?(json, "Service")
    end

    test "export_year/1 returns error for non-existent year" do
      {:error, _error} = InvoiceCreation.export_year(9999)

      # Error structure depends on implementation
    end
  end

  describe "export_all/0" do
    test "export_all/0 exports all years as JSON array" do
      # Setup invoices in two years
      for year <- [2023, 2024] do
        {:ok, list} = InvoiceCreation.create_year_list(year)
        {:ok, invoice} = InvoiceCreation.create_invoice(date: Date.new!(year, 6, 15))
        {:ok, list_with_invoice} = ListInvoiceYear.add_invoice(list, invoice)
        :ok = InvoiceCreation.save_year(list_with_invoice)
      end

      {:ok, json} = InvoiceCreation.export_all()

      assert is_binary(json)
      assert String.contains?(json, "2023")
      assert String.contains?(json, "2024")
    end

    test "export_all/0 returns valid JSON" do
      {:ok, list} = InvoiceCreation.create_year_list(2024)
      :ok = InvoiceCreation.save_year(list)

      {:ok, json} = InvoiceCreation.export_all()

      assert {:ok, _data} = Jason.decode(json)
    end
  end

  describe "import_year/2" do
    test "import_year/2 imports exported JSON" do
      # Export
      {:ok, list} = InvoiceCreation.create_year_list(2024)
      {:ok, invoice} = InvoiceCreation.create_invoice(date: ~D[2024-06-15], number: "2024-0001")
      {:ok, list_with_invoice} = ListInvoiceYear.add_invoice(list, invoice)
      :ok = InvoiceCreation.save_year(list_with_invoice)
      {:ok, exported_json} = InvoiceCreation.export_year(2024)

      # Delete original
      cleanup_test_storage()

      # Import
      :ok = InvoiceCreation.import_year(exported_json, 2024)

      # Verify
      assert InvoiceCreation.invoice_exists?(invoice.number, 2024)
    end

    test "import_year/2 returns error for year mismatch" do
      {:ok, list} = InvoiceCreation.create_year_list(2024)
      :ok = InvoiceCreation.save_year(list)
      {:ok, exported_json} = InvoiceCreation.export_year(2024)

      result = InvoiceCreation.import_year(exported_json, 2023)

      assert is_tuple(result) and elem(result, 0) == :error
    end

    test "import_year/2 returns error for invalid JSON" do
      result = InvoiceCreation.import_year("invalid json", 2024)

      assert is_tuple(result) and elem(result, 0) == :error
    end
  end

  describe "import_all/1" do
    test "import_all/1 imports multiple years" do
      # Export multiple years
      for year <- [2023, 2024] do
        {:ok, list} = InvoiceCreation.create_year_list(year)
        :ok = InvoiceCreation.save_year(list)
      end

      {:ok, exported_json} = InvoiceCreation.export_all()

      cleanup_test_storage()

      # Import
      :ok = InvoiceCreation.import_all(exported_json)

      # Verify
      {:ok, years} = InvoiceCreation.list_stored_years()
      assert Enum.member?(years, 2023)
      assert Enum.member?(years, 2024)
    end

    test "import_all/1 returns error for invalid JSON" do
      result = InvoiceCreation.import_all("invalid json")

      assert is_tuple(result) and elem(result, 0) == :error
    end

    test "import_all/1 returns error for non-array JSON" do
      result = InvoiceCreation.import_all(Jason.encode!(%{year: 2024}))

      assert is_tuple(result) and elem(result, 0) == :error
    end
  end

  # ============================================================================
  # Existing Domain Tests (kept from original file)
  # ============================================================================

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

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp cleanup_test_storage do
    storage_dir = Application.get_env(:invoice_creation, :storage_dir, "priv/storage")

    if File.exists?(storage_dir) do
      File.rm_rf!(storage_dir)
    end
  end
end
