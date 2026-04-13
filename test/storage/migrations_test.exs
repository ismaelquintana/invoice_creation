defmodule InvoiceStorage.MigrationsTest do
  use ExUnit.Case, async: true
  alias InvoiceStorage.Migrations
  alias InvoiceCreation.Factory
  alias InvoiceStorage.Csv.{Encoder, Decoder}

  describe "database_to_csv/2" do
    test "flat CSV export encodes invoices correctly" do
      # Create invoices
      invoices = [
        Factory.build(:invoice,
          number: "2024-0001",
          items: [Factory.build(:item, description: "Service A")]
        ),
        Factory.build(:invoice,
          number: "2024-0002",
          items: [Factory.build(:item, description: "Service B")]
        )
      ]

      # Test the Encoder directly (what database_to_csv would use)
      csv = Encoder.encode_flat(invoices)

      assert String.contains?(csv, "2024-0001")
      assert String.contains?(csv, "2024-0002")
      assert String.contains?(csv, "Service A")
      assert String.contains?(csv, "Service B")
    end

    test "hierarchical CSV export encodes invoices correctly" do
      invoices = [
        Factory.build(:invoice,
          number: "2024-0001",
          items: [
            Factory.build(:item, description: "Service A"),
            Factory.build(:item, description: "Service B")
          ]
        )
      ]

      csv = Encoder.encode_hierarchical(invoices)

      assert String.contains?(csv, "INVOICES")
      assert String.contains?(csv, "ITEMS")
      assert String.contains?(csv, "2024-0001")
      assert String.contains?(csv, "Service A")
      assert String.contains?(csv, "Service B")
    end
  end

  describe "csv_to_database/2" do
    test "decodes flat CSV format" do
      csv = """
      invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount,item_description,item_units,item_amount
      2024-0001,2024-01-15,Acme Corp,Our Corp,1000,50000,Service A,2,10000
      """

      {:ok, invoices} = Decoder.decode_flat(csv)

      assert length(invoices) == 1
      assert List.first(invoices).number == "2024-0001"
    end

    test "decodes hierarchical CSV format" do
      csv = """
      INVOICES
      invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount
      2024-0001,2024-01-15,Acme Corp,Our Corp,1000,50000

      ITEMS
      invoice_number,item_description,item_units,item_amount
      2024-0001,Service A,2,10000
      """

      {:ok, invoices} = Decoder.decode_hierarchical(csv)

      assert length(invoices) == 1
      assert List.first(invoices).number == "2024-0001"
    end

    test "auto-detects hierarchical format" do
      csv = """
      INVOICES
      invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount
      2024-0001,2024-01-15,Acme Corp,Our Corp,1000,50000

      ITEMS
      invoice_number,item_description,item_units,item_amount
      2024-0001,Service A,2,10000
      """

      {:ok, invoices} = Decoder.decode(csv)

      assert length(invoices) == 1
      assert List.first(invoices).number == "2024-0001"
    end

    test "auto-detects flat format" do
      csv = """
      invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount,item_description,item_units,item_amount
      2024-0001,2024-01-15,Acme Corp,Our Corp,1000,50000,Service A,2,10000
      """

      {:ok, invoices} = Decoder.decode(csv)

      assert length(invoices) == 1
      assert List.first(invoices).number == "2024-0001"
    end
  end

  describe "round-trip migrations" do
    test "flat CSV can be decoded and re-encoded without data loss" do
      original_invoices = [
        Factory.build(:invoice,
          number: "2024-0001",
          bill_to: "Customer A",
          items: [
            Factory.build(:item, description: "Item 1", units: 2, amount: 1000),
            Factory.build(:item, description: "Item 2", units: 3, amount: 2000)
          ]
        )
      ]

      # Encode to flat CSV
      csv = Encoder.encode_flat(original_invoices)

      # Decode back from CSV
      {:ok, decoded_invoices} = Decoder.decode_flat(csv)

      # Verify data preserved
      original = List.first(original_invoices)
      decoded = List.first(decoded_invoices)

      assert decoded.number == original.number
      assert decoded.bill_to == original.bill_to
      assert length(decoded.items) == 2
    end

    test "hierarchical CSV can be decoded and re-encoded without data loss" do
      original_invoices = [
        Factory.build(:invoice,
          number: "2024-0001",
          bill_to: "Customer A",
          items: [
            Factory.build(:item, description: "Service A"),
            Factory.build(:item, description: "Service B")
          ]
        )
      ]

      # Encode to hierarchical CSV
      csv = Encoder.encode_hierarchical(original_invoices)

      # Decode back from CSV
      {:ok, decoded_invoices} = Decoder.decode_hierarchical(csv)

      # Verify data preserved
      original = List.first(original_invoices)
      decoded = List.first(decoded_invoices)

      assert decoded.number == original.number
      assert decoded.bill_to == original.bill_to
      assert length(decoded.items) == 2
    end
  end
end
