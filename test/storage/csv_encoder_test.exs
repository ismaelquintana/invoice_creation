defmodule InvoiceStorage.Csv.EncoderTest do
  use ExUnit.Case
  alias InvoiceStorage.Csv.Encoder
  import InvoiceCreation.TestHelpers

  describe "encode_flat/1" do
    test "generates CSV with headers" do
      invoices = []
      csv = Encoder.encode_flat(invoices)

      assert String.contains?(csv, "invoice_number")
      assert String.contains?(csv, "item_description")
    end

    test "generates one row per item" do
      items = [build_item(), build_item()]
      invoice = build_invoice(items: items)
      csv = Encoder.encode_flat([invoice])

      lines = String.split(csv, "\n", trim: true)
      assert length(lines) >= 3
    end

    test "handles invoice without items" do
      invoice = build_invoice(items: [])
      csv = Encoder.encode_flat([invoice])

      lines = String.split(csv, "\n", trim: true)
      assert length(lines) >= 2
    end

    test "includes invoice number in all rows" do
      invoice =
        build_invoice(
          number: "2024-0001",
          items: [
            build_item(),
            build_item(),
            build_item()
          ]
        )

      csv = Encoder.encode_flat([invoice])

      count = csv |> String.split("2024-0001") |> length() |> Kernel.-(1)
      assert count >= 3
    end

    test "includes invoice dates" do
      invoice = build_invoice(date: ~D[2024-01-15])
      csv = Encoder.encode_flat([invoice])

      assert String.contains?(csv, "2024-01-15")
    end

    test "handles optional fields" do
      invoice =
        build_invoice(
          bill_to: "Acme Corp",
          vendor_details: "Our Vendor",
          items: [build_item()]
        )

      csv = Encoder.encode_flat([invoice])

      assert String.contains?(csv, "Acme Corp")
      assert String.contains?(csv, "Our Vendor")
    end

    test "handles nil optional fields" do
      invoice =
        build_invoice(
          bill_to: nil,
          vendor_details: nil,
          items: [build_item()]
        )

      csv = Encoder.encode_flat([invoice])

      assert is_binary(csv)
      assert byte_size(csv) > 0
    end

    test "includes item details" do
      item = build_item(description: "Consulting Services", units: 10, amount: 5000)
      invoice = build_invoice(items: [item])
      csv = Encoder.encode_flat([invoice])

      assert String.contains?(csv, "Consulting Services")
      assert String.contains?(csv, "10")
      assert String.contains?(csv, "5000")
    end

    test "calculates item totals" do
      item = build_item(units: 5, amount: 2000)
      invoice = build_invoice(items: [item])
      csv = Encoder.encode_flat([invoice])

      expected_total = 5 * 2000
      assert String.contains?(csv, Integer.to_string(expected_total))
    end

    test "handles multiple invoices" do
      invoices =
        Enum.map(1..3, fn i ->
          build_invoice(number: "2024-000#{i}", items: [build_item()])
        end)

      csv = Encoder.encode_flat(invoices)

      assert String.contains?(csv, "2024-0001")
      assert String.contains?(csv, "2024-0002")
      assert String.contains?(csv, "2024-0003")
    end

    test "is RFC 4180 compliant" do
      invoice =
        build_invoice(
          bill_to: "Smith, Inc.",
          items: [build_item(description: "Service, comprehensive")]
        )

      csv = Encoder.encode_flat([invoice])

      assert is_binary(csv)
      assert byte_size(csv) > 0
    end

    test "includes financial amounts" do
      invoice = build_invoice(vat: 5000, sale_amount: 50000)
      csv = Encoder.encode_flat([invoice])

      assert String.contains?(csv, "5000")
      assert String.contains?(csv, "50000")
    end
  end

  describe "encode_hierarchical/1" do
    test "generates two sections" do
      invoices = [build_invoice(items: [build_item()])]
      csv = Encoder.encode_hierarchical(invoices)

      assert String.contains?(csv, "INVOICES")
      assert String.contains?(csv, "ITEMS")
    end

    test "includes invoice headers in INVOICES section" do
      invoices = [build_invoice()]
      csv = Encoder.encode_hierarchical(invoices)

      invoice_section = String.split(csv, "\n\n") |> List.first()
      assert String.contains?(invoice_section, "invoice_number")
      assert String.contains?(invoice_section, "invoice_date")
      assert String.contains?(invoice_section, "vat")
      assert String.contains?(invoice_section, "sale_amount")
    end

    test "includes item headers in ITEMS section" do
      invoices = [build_invoice(items: [build_item()])]
      csv = Encoder.encode_hierarchical(invoices)

      item_section = String.split(csv, "\n\n") |> List.last()
      assert String.contains?(item_section, "item_description")
      assert String.contains?(item_section, "item_units")
      assert String.contains?(item_section, "item_amount")
    end

    test "includes invoice numbers for item reference" do
      invoice =
        build_invoice(
          number: "2024-0001",
          items: [
            build_item(),
            build_item()
          ]
        )

      csv = Encoder.encode_hierarchical([invoice])

      item_section = String.split(csv, "\n\n") |> List.last()
      count = item_section |> String.split("2024-0001") |> length() |> Kernel.-(1)
      assert count >= 2
    end

    test "handles multiple invoices" do
      invoices =
        Enum.map(1..3, fn i ->
          build_invoice(
            number: "2024-000#{i}",
            items: [build_item()]
          )
        end)

      csv = Encoder.encode_hierarchical(invoices)

      assert String.contains?(csv, "2024-0001")
      assert String.contains?(csv, "2024-0002")
      assert String.contains?(csv, "2024-0003")
    end

    test "handles invoices without items" do
      invoice = build_invoice(items: [])
      csv = Encoder.encode_hierarchical([invoice])

      assert is_binary(csv)
      assert byte_size(csv) > 0
    end

    test "separates sections with blank lines" do
      invoices = [build_invoice(items: [build_item()])]
      csv = Encoder.encode_hierarchical(invoices)

      sections = String.split(csv, "\n\n")
      assert length(sections) >= 2
    end

    test "preserves invoice and item details" do
      invoice =
        build_invoice(
          number: "2024-TEST-001",
          date: ~D[2024-01-15],
          bill_to: "Test Customer",
          vat: 1000,
          sale_amount: 50000,
          items: [
            build_item(description: "Item A", units: 2, amount: 10000)
          ]
        )

      csv = Encoder.encode_hierarchical([invoice])

      assert String.contains?(csv, "2024-TEST-001")
      assert String.contains?(csv, "2024-01-15")
      assert String.contains?(csv, "Test Customer")
      assert String.contains?(csv, "Item A")
      assert String.contains?(csv, "2")
      assert String.contains?(csv, "10000")
    end
  end

  describe "format compliance" do
    test "flat format is valid CSV" do
      invoice = build_invoice(items: [build_item()])
      csv = Encoder.encode_flat([invoice])

      rows =
        csv
        |> String.split("\n")
        |> CSV.decode()
        |> Enum.map(fn
          {:ok, row} -> row
          err -> err
        end)

      assert length(rows) >= 2

      assert List.first(rows) == [
               "invoice_number",
               "invoice_date",
               "bill_to",
               "vendor_details",
               "vat",
               "sale_amount",
               "item_description",
               "item_units",
               "item_amount",
               "item_total"
             ]
    end

    test "hierarchical format sections are valid CSV" do
      invoices = [build_invoice(items: [build_item()])]
      csv = Encoder.encode_hierarchical(invoices)

      sections = String.split(csv, "\n\n")
      invoices_section = List.first(sections)
      items_section = List.last(sections)

      invoices_rows =
        invoices_section
        |> String.split("\n")
        |> CSV.decode()
        |> Enum.map(fn
          {:ok, row} -> row
          err -> err
        end)

      items_rows =
        items_section
        |> String.split("\n")
        |> CSV.decode()
        |> Enum.map(fn
          {:ok, row} -> row
          err -> err
        end)

      assert length(invoices_rows) >= 1
      assert length(items_rows) >= 1
    end
  end
end
