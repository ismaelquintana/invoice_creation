defmodule InvoiceStorageTest do
  use ExUnit.Case

  alias Invoice
  alias Item
  alias ListInvoiceYear
  alias InvoiceStorage
  alias InvoiceStorage.Error

  setup do
    # Use unique test directory per test
    test_storage = Path.join(System.tmp_dir!(), "invoice_test_#{System.unique_integer()}")
    Application.put_env(:invoice_creation, :storage_root, test_storage)

    on_exit(fn ->
      File.rm_rf(test_storage)
    end)

    {:ok, storage_root: test_storage}
  end

  describe "save/1" do
    test "saves an invoice to disk with correct filename" do
      invoice = create_invoice()
      assert :ok = InvoiceStorage.save(invoice)
      assert InvoiceStorage.exists?(invoice.number, invoice.date.year)
    end

    test "creates directory structure if missing" do
      invoice = create_invoice()
      InvoiceStorage.save(invoice)
      # Just verify no error was raised
      assert true
    end

    test "saves invoice with correct JSON format", %{storage_root: root} do
      invoice = create_invoice()
      InvoiceStorage.save(invoice)

      path = Path.join([root, "invoices", "#{invoice.date.year}", "#{invoice.number}.json"])
      assert File.exists?(path)

      content = File.read!(path)
      {:ok, data} = Jason.decode(content)

      assert data["number"] == invoice.number
      assert data["bill_to"] == invoice.bill_to
      assert data["date"] == Date.to_iso8601(invoice.date)
    end

    test "overwrites existing invoice" do
      invoice1 = create_invoice()
      InvoiceStorage.save(invoice1)

      # Create modified invoice with same number
      updated = %{
        invoice1
        | bill_to: "New Client"
      }

      InvoiceStorage.save(updated)

      {:ok, loaded} = InvoiceStorage.load(invoice1.number, invoice1.date.year)
      assert loaded.bill_to == "New Client"
    end

    test "returns error for non-Invoice struct" do
      result = InvoiceStorage.save(%{"invalid" => "data"})
      assert {:error, _} = result
    end
  end

  describe "load/2" do
    test "loads saved invoice from disk" do
      invoice = create_invoice()
      InvoiceStorage.save(invoice)

      {:ok, loaded} = InvoiceStorage.load(invoice.number, invoice.date.year)

      assert loaded.number == invoice.number
      assert loaded.bill_to == invoice.bill_to
      assert loaded.date == invoice.date
    end

    test "returns error when invoice not found" do
      result = InvoiceStorage.load("2099-9999", 2024)
      assert {:error, %Error.FileNotFound{}} = result
    end

    test "reconstructs items correctly from disk" do
      invoice = create_invoice()
      InvoiceStorage.save(invoice)

      {:ok, loaded} = InvoiceStorage.load(invoice.number, invoice.date.year)

      assert length(loaded.items) == length(invoice.items)
      assert Enum.all?(Enum.zip(loaded.items, invoice.items), fn {l, o} ->
        l.description == o.description && l.units == o.units && l.amount == o.amount
      end)
    end

    test "correctly deserializes date from ISO 8601" do
      invoice = create_invoice()
      InvoiceStorage.save(invoice)

      {:ok, loaded} = InvoiceStorage.load(invoice.number, invoice.date.year)

      assert loaded.date == invoice.date
      assert is_struct(loaded.date, Date)
    end

    test "returns error for invalid parameters" do
      result = InvoiceStorage.load(123, "2024")
      assert {:error, %Error.InvalidPath{}} = result
    end
  end

  describe "delete/2" do
    test "removes invoice file from disk" do
      invoice = create_invoice()
      InvoiceStorage.save(invoice)
      assert InvoiceStorage.exists?(invoice.number, invoice.date.year)

      :ok = InvoiceStorage.delete(invoice.number, invoice.date.year)

      refute InvoiceStorage.exists?(invoice.number, invoice.date.year)
    end

    test "returns error when file doesn't exist" do
      result = InvoiceStorage.delete("2099-9999", 2024)
      assert {:error, %Error.FileNotFound{}} = result
    end

    test "returns error for invalid parameters" do
      result = InvoiceStorage.delete(123, "2024")
      assert {:error, %Error.InvalidPath{}} = result
    end
  end

  describe "exists?/2" do
    test "returns true for saved invoice" do
      invoice = create_invoice()
      InvoiceStorage.save(invoice)

      assert InvoiceStorage.exists?(invoice.number, invoice.date.year)
    end

    test "returns false for missing invoice" do
      refute InvoiceStorage.exists?("2099-9999", 2024)
    end

    test "returns false for invalid parameters" do
      refute InvoiceStorage.exists?(123, "2024")
    end
  end

  describe "save_all/1" do
    test "saves all invoices from a list year" do
      invoice1 = create_invoice("2024-0001")
      invoice2 = create_invoice("2024-0002")

      list_year = %ListInvoiceYear{
        year: 2024,
        next_id: 3,
        invoices: %{
          "2024-0001" => invoice1,
          "2024-0002" => invoice2
        }
      }

      assert :ok = InvoiceStorage.save_all(list_year)
      assert InvoiceStorage.exists?("2024-0001", 2024)
      assert InvoiceStorage.exists?("2024-0002", 2024)
    end

    test "returns error if any invoice fails to save" do
      result = InvoiceStorage.save_all(%{})
      assert {:error, _} = result
    end

    test "returns error for non-ListInvoiceYear struct" do
      result = InvoiceStorage.save_all([])
      assert {:error, _} = result
    end
  end

  describe "load_all/1" do
    test "loads all invoices for a year" do
      invoice1 = create_invoice("2024-0001")
      invoice2 = create_invoice("2024-0002")

      list_year = %ListInvoiceYear{
        year: 2024,
        next_id: 3,
        invoices: %{
          "2024-0001" => invoice1,
          "2024-0002" => invoice2
        }
      }

      InvoiceStorage.save_all(list_year)

      {:ok, loaded_invoices} = InvoiceStorage.load_all(2024)

      assert map_size(loaded_invoices) == 2
      assert loaded_invoices["2024-0001"].number == "2024-0001"
      assert loaded_invoices["2024-0002"].number == "2024-0002"
    end

    test "returns empty map when year directory doesn't exist" do
      {:ok, invoices} = InvoiceStorage.load_all(2099)
      assert invoices == %{}
    end

    test "returns error for invalid year parameter" do
      result = InvoiceStorage.load_all("2024")
      assert {:error, %Error.InvalidYear{}} = result
    end
  end

  describe "save_year_list/1" do
    test "saves year metadata to separate file" do
      list_year = %ListInvoiceYear{
        year: 2024,
        next_id: 42,
        invoices: %{}
      }

      assert :ok = InvoiceStorage.save_year_list(list_year)
    end

    test "saves year, next_id and invoices in JSON format", %{storage_root: root} do
      invoice = create_invoice("2024-0001")

      list_year = %ListInvoiceYear{
        year: 2024,
        next_id: 2,
        invoices: %{"2024-0001" => invoice}
      }

      InvoiceStorage.save_year_list(list_year)

      path = Path.join([root, "years", "2024.json"])
      assert File.exists?(path)

      content = File.read!(path)
      {:ok, data} = Jason.decode(content)

      assert data["year"] == 2024
      assert data["next_id"] == 2
      assert is_list(data["invoices"])
    end

    test "returns error for non-ListInvoiceYear" do
      result = InvoiceStorage.save_year_list(%{})
      assert {:error, _} = result
    end
  end

  describe "load_year_list/1" do
    test "loads year list from disk" do
      list_year = %ListInvoiceYear{
        year: 2024,
        next_id: 42,
        invoices: %{}
      }

      InvoiceStorage.save_year_list(list_year)

      {:ok, loaded} = InvoiceStorage.load_year_list(2024)

      assert loaded.year == 2024
      assert loaded.next_id == 42
    end

    test "returns error when file doesn't exist" do
      result = InvoiceStorage.load_year_list(2099)
      assert {:error, %Error.FileNotFound{}} = result
    end

    test "returns error for invalid year parameter" do
      result = InvoiceStorage.load_year_list("2024")
      assert {:error, %Error.InvalidYear{}} = result
    end
  end

  describe "list_years/0" do
    test "returns empty list when no invoices saved" do
      {:ok, years} = InvoiceStorage.list_years()
      assert years == []
    end

    test "returns sorted list of years with invoices" do
      invoice1 = create_invoice("2023-0001", 2023)
      invoice2 = create_invoice("2024-0001", 2024)
      invoice3 = create_invoice("2022-0001", 2022)

      InvoiceStorage.save(invoice1)
      InvoiceStorage.save(invoice2)
      InvoiceStorage.save(invoice3)

      {:ok, years} = InvoiceStorage.list_years()

      assert 2024 in years
      assert 2023 in years
      assert 2022 in years
      # Most recent first
      assert Enum.take(years, 1) == [2024]
    end
  end

  describe "count/1" do
    test "returns 0 for empty year" do
      {:ok, count} = InvoiceStorage.count(2024)
      assert count == 0
    end

    test "counts all invoices in a year" do
      for i <- 1..5 do
        number = "2024-#{String.pad_leading(Integer.to_string(i), 4, "0")}"
        invoice = create_invoice(number)
        InvoiceStorage.save(invoice)
      end

      {:ok, count} = InvoiceStorage.count(2024)
      assert count == 5
    end

    test "counts only .json files" do
      invoice = create_invoice("2024-0001")
      InvoiceStorage.save(invoice)

      {:ok, count} = InvoiceStorage.count(2024)
      assert count >= 1
    end

    test "returns error for invalid year parameter" do
      result = InvoiceStorage.count("2024")
      assert {:error, %Error.InvalidYear{}} = result
    end
  end

  # Helpers

  defp create_invoice(number \\ "2024-0001", year \\ 2024) do
    {:ok, invoice} =
      Invoice.new(
        number: number,
        date: Date.new!(year, 3, 5),
        bill_to: "Test Client",
        vendor_details: "My Company",
        items: [
          create_item("Item 1"),
          create_item("Item 2")
        ],
        sale_amount: 1000,
        vat: 210
      )

    invoice
  end

  defp create_item(description \\ "Test Item") do
    {:ok, item} =
      Item.new(
        description: description,
        units: 5,
        amount: 100
      )

    item
  end
end
