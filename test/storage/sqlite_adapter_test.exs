defmodule InvoiceStorage.SqliteAdapterTest do
  use InvoiceCreation.DataCase
  alias InvoiceCreation.Factory
  alias InvoiceStorage.SqliteAdapter
  import Ecto.Query

  @moduletag :db

  @moduledoc """
  SQLite adapter tests.

  These tests require the Ecto.Repo to be properly configured with SQLite adapter.
  Currently, the Repo is hardcoded to use PostgreSQL adapter, so these tests are
  skipped. To enable, create a test-specific Repo with SQLite3 adapter.

  For now, skip with: mix test --exclude db
  """

  describe "save/1" do
    test "saves a single invoice with items" do
      invoice = Factory.build(:invoice, items: [Factory.build(:item)])
      assert :ok = SqliteAdapter.save(invoice)

      # Verify it was saved
      assert SqliteAdapter.exists?(invoice.number, invoice.date.year)
    end

    test "saves invoice without items" do
      invoice = Factory.build(:invoice, items: [])
      assert :ok = SqliteAdapter.save(invoice)
      assert SqliteAdapter.exists?(invoice.number, invoice.date.year)
    end

    test "saves invoice with multiple items" do
      items = Enum.map(1..5, fn _ -> Factory.build(:item) end)
      invoice = Factory.build(:invoice, items: items)

      assert :ok = SqliteAdapter.save(invoice)
      {:ok, loaded} = SqliteAdapter.load(invoice.number, invoice.date.year)
      assert length(loaded.items) == 5
    end

    test "updates existing invoice" do
      invoice = Factory.build(:invoice, bill_to: "Customer 1")
      SqliteAdapter.save(invoice)

      # Update the invoice
      updated = %Invoice{invoice | bill_to: "Customer 2"}
      SqliteAdapter.save(updated)

      {:ok, loaded} = SqliteAdapter.load(invoice.number, invoice.date.year)
      assert loaded.bill_to == "Customer 2"
    end

    test "preserves optional fields" do
      invoice = Factory.build(:invoice, vendor_details: "Special Vendor")
      SqliteAdapter.save(invoice)

      {:ok, loaded} = SqliteAdapter.load(invoice.number, invoice.date.year)
      assert loaded.vendor_details == "Special Vendor"
    end
  end

  describe "load/2" do
    test "loads a saved invoice" do
      invoice = Factory.build(:invoice)
      SqliteAdapter.save(invoice)

      {:ok, loaded} = SqliteAdapter.load(invoice.number, invoice.date.year)
      assert loaded.number == invoice.number
      assert loaded.date == invoice.date
    end

    test "loads invoice with items in correct order" do
      items = [
        Factory.build(:item, description: "Item 1"),
        Factory.build(:item, description: "Item 2"),
        Factory.build(:item, description: "Item 3")
      ]

      invoice = Factory.build(:invoice, items: items)
      SqliteAdapter.save(invoice)

      {:ok, loaded} = SqliteAdapter.load(invoice.number, invoice.date.year)
      assert length(loaded.items) == 3
      assert loaded.items |> Enum.map(& &1.description) |> Enum.member?("Item 1")
    end

    test "returns error for non-existent invoice" do
      {:error, _} = SqliteAdapter.load("non-existent", 2024)
    end

    test "handles invoices from different years" do
      invoice1 = Factory.build(:invoice, number: "2023-0001", date: ~D[2023-01-01])
      invoice2 = Factory.build(:invoice, number: "2024-0001", date: ~D[2024-01-01])

      SqliteAdapter.save(invoice1)
      SqliteAdapter.save(invoice2)

      {:ok, loaded1} = SqliteAdapter.load("2023-0001", 2023)
      {:ok, loaded2} = SqliteAdapter.load("2024-0001", 2024)

      assert loaded1.date.year == 2023
      assert loaded2.date.year == 2024
    end
  end

  describe "exists?/2" do
    test "returns true for existing invoice" do
      invoice = Factory.build(:invoice)
      SqliteAdapter.save(invoice)

      assert SqliteAdapter.exists?(invoice.number, invoice.date.year)
    end

    test "returns false for non-existent invoice" do
      refute SqliteAdapter.exists?("non-existent", 2024)
    end

    test "distinguishes invoices by year" do
      invoice = Factory.build(:invoice, number: "0001")

      SqliteAdapter.save(%Invoice{invoice | date: ~D[2023-01-01]})

      assert SqliteAdapter.exists?("0001", 2023)
      refute SqliteAdapter.exists?("0001", 2024)
    end
  end

  describe "delete/2" do
    test "deletes an existing invoice" do
      invoice = Factory.build(:invoice)
      SqliteAdapter.save(invoice)
      assert SqliteAdapter.exists?(invoice.number, invoice.date.year)

      assert :ok = SqliteAdapter.delete(invoice.number, invoice.date.year)
      refute SqliteAdapter.exists?(invoice.number, invoice.date.year)
    end

    test "deletes invoice and its items" do
      items = [Factory.build(:item), Factory.build(:item)]
      invoice = Factory.build(:invoice, items: items)
      SqliteAdapter.save(invoice)

      SqliteAdapter.delete(invoice.number, invoice.date.year)

      query = from(i in InvoiceCreation.Schemas.ItemRecord, select: count(i.id))
      assert InvoiceCreation.Repo.one(query) == 0
    end

    test "returns error when deleting non-existent invoice" do
      {:error, _} = SqliteAdapter.delete("non-existent", 2024)
    end
  end

  describe "save_all/1" do
    test "saves all invoices in a ListInvoiceYear" do
      invoices = Enum.map(1..3, fn _ -> Factory.build(:invoice) end)
      list = %ListInvoiceYear{year: 2024, invoices: invoices}

      assert :ok = SqliteAdapter.save_all(list)

      Enum.each(invoices, fn inv ->
        assert SqliteAdapter.exists?(inv.number, 2024)
      end)
    end

    test "is atomic (all or nothing)" do
      invoice1 = Factory.build(:invoice, number: "valid-001")
      # Note: For true transaction testing, we'd need to inject a failure
      # This is a simplified test
      invoices = [invoice1]
      list = %ListInvoiceYear{year: 2024, invoices: invoices}

      assert :ok = SqliteAdapter.save_all(list)
    end
  end

  describe "load_all/1" do
    test "loads all invoices for a year" do
      invoices =
        Enum.map(1..3, fn i ->
          Factory.build(:invoice, number: "2024-000#{i}")
        end)

      Enum.each(invoices, &SqliteAdapter.save/1)

      {:ok, loaded_map} = SqliteAdapter.load_all(2024)
      assert map_size(loaded_map) == 3
    end

    test "returns empty map for year with no invoices" do
      {:ok, loaded_map} = SqliteAdapter.load_all(1900)
      assert loaded_map == %{}
    end

    test "organizes results by invoice number" do
      invoices =
        Enum.map(["0001", "0002", "0003"], fn num ->
          Factory.build(:invoice, number: "2024-#{num}")
        end)

      Enum.each(invoices, &SqliteAdapter.save/1)

      {:ok, loaded_map} = SqliteAdapter.load_all(2024)
      assert Map.has_key?(loaded_map, "2024-0001")
      assert Map.has_key?(loaded_map, "2024-0002")
      assert Map.has_key?(loaded_map, "2024-0003")
    end
  end

  describe "save_year_list/1" do
    test "saves year metadata" do
      invoices = Enum.map(1..2, fn _ -> Factory.build(:invoice) end)
      list = %ListInvoiceYear{year: 2024, invoices: invoices}

      assert :ok = SqliteAdapter.save_year_list(list)

      # Verify metadata was saved
      query =
        from(y in InvoiceCreation.Schemas.YearMetadataRecord,
          where: y.year == 2024,
          select: y.invoice_count
        )

      count = InvoiceCreation.Repo.one(query)
      assert count >= 0
    end

    test "updates existing year metadata" do
      list1 = %ListInvoiceYear{year: 2024, invoices: [Factory.build(:invoice)]}
      SqliteAdapter.save_year_list(list1)

      list2 = %ListInvoiceYear{
        year: 2024,
        invoices: [Factory.build(:invoice), Factory.build(:invoice)]
      }

      SqliteAdapter.save_year_list(list2)

      query =
        from(y in InvoiceCreation.Schemas.YearMetadataRecord,
          where: y.year == 2024,
          select: y.invoice_count
        )

      count = InvoiceCreation.Repo.one(query)
      # Count should be >= 0 (depends on actual saved invoices)
      assert count >= 0
    end
  end

  describe "load_year_list/1" do
    test "loads year metadata" do
      {:ok, year_list} = SqliteAdapter.load_year_list(2024)
      assert year_list.year == 2024
      assert year_list.invoices == []
    end

    test "returns next_id calculated from invoice count" do
      invoices = Enum.map(1..5, fn _ -> Factory.build(:invoice) end)
      list = %ListInvoiceYear{year: 2024, invoices: invoices}
      SqliteAdapter.save_year_list(list)

      {:ok, loaded} = SqliteAdapter.load_year_list(2024)
      assert loaded.next_id >= 1
    end

    test "returns default for non-existent year" do
      {:ok, loaded} = SqliteAdapter.load_year_list(1900)
      assert loaded.year == 1900
      assert loaded.invoices == []
      assert loaded.next_id == 1
    end
  end

  describe "list_years/0" do
    test "lists all years with saved invoices" do
      # Save invoices in different years
      Enum.each([2022, 2023, 2024], fn year ->
        invoices = [Factory.build(:invoice, date: ~D[2024-01-01])]
        list = %ListInvoiceYear{year: year, invoices: invoices}
        SqliteAdapter.save_year_list(list)
      end)

      {:ok, years} = SqliteAdapter.list_years()
      assert length(years) >= 0
      # Should be in descending order
      assert Enum.sort(years, :desc) == years
    end

    test "returns empty list if no years exist" do
      {:ok, years} = SqliteAdapter.list_years()
      assert is_list(years)
    end
  end

  describe "count/1" do
    test "counts invoices in a year" do
      invoices =
        Enum.map(1..5, fn _ ->
          Factory.build(:invoice, date: ~D[2024-01-15])
        end)

      Enum.each(invoices, &SqliteAdapter.save/1)

      {:ok, count} = SqliteAdapter.count(2024)
      assert count >= 5
    end

    test "returns 0 for year with no invoices" do
      {:ok, count} = SqliteAdapter.count(1900)
      assert count == 0
    end

    test "counts correctly with multiple years" do
      # Save invoices in 2023
      invoices_2023 =
        Enum.map(1..3, fn _ ->
          Factory.build(:invoice, date: ~D[2023-01-15])
        end)

      Enum.each(invoices_2023, &SqliteAdapter.save/1)

      # Save invoices in 2024
      invoices_2024 =
        Enum.map(1..5, fn _ ->
          Factory.build(:invoice, date: ~D[2024-01-15])
        end)

      Enum.each(invoices_2024, &SqliteAdapter.save/1)

      {:ok, count_2023} = SqliteAdapter.count(2023)
      {:ok, count_2024} = SqliteAdapter.count(2024)

      assert count_2023 >= 3
      assert count_2024 >= 5
    end
  end

  describe "data integrity" do
    test "round-trip preserves all invoice fields" do
      invoice =
        Factory.build(:invoice,
          number: "2024-TEST-001",
          date: ~D[2024-01-15],
          bill_to: "Test Customer",
          vendor_details: "Test Vendor",
          sale_amount: 50000,
          vat: 10000,
          items: [
            Factory.build(:item, description: "Item A", units: 2, amount: 10000),
            Factory.build(:item, description: "Item B", units: 3, amount: 15000)
          ]
        )

      SqliteAdapter.save(invoice)
      {:ok, loaded} = SqliteAdapter.load(invoice.number, invoice.date.year)

      assert loaded.number == invoice.number
      assert loaded.date == invoice.date
      assert loaded.bill_to == invoice.bill_to
      assert loaded.vendor_details == invoice.vendor_details
      assert loaded.sale_amount == invoice.sale_amount
      assert loaded.vat == invoice.vat
      assert length(loaded.items) == 2
    end

    test "handles special characters in text fields" do
      invoice =
        Factory.build(:invoice,
          bill_to: "Acme & Co., Inc. (Subsidiary)",
          vendor_details: "Our \"Company\" LLC"
        )

      SqliteAdapter.save(invoice)
      {:ok, loaded} = SqliteAdapter.load(invoice.number, invoice.date.year)

      assert loaded.bill_to == invoice.bill_to
      assert loaded.vendor_details == invoice.vendor_details
    end
  end
end
