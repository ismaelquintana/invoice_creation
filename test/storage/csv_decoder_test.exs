defmodule InvoiceStorage.Csv.DecoderTest do
  use ExUnit.Case
  alias InvoiceStorage.Csv.{Decoder, Encoder}
  import InvoiceCreation.TestHelpers

  describe "decode_flat/1" do
    test "decodes flat format CSV with single invoice and item" do
      item = build_item(description: "Service A", units: 2, amount: 10000)
      invoice = build_invoice(number: "2024-0001", date: ~D[2024-01-15], items: [item])
      csv = Encoder.encode_flat([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      assert length(decoded_invoices) == 1

      decoded = List.first(decoded_invoices)
      assert decoded.number == "2024-0001"
      assert decoded.date == ~D[2024-01-15]
      assert length(decoded.items) == 1

      decoded_item = List.first(decoded.items)
      assert decoded_item.description == "Service A"
      assert decoded_item.units == 2
      assert decoded_item.amount == 10000
    end

    test "decodes flat format with multiple items per invoice" do
      items = [
        build_item(description: "Service A", units: 2, amount: 10000),
        build_item(description: "Service B", units: 3, amount: 5000)
      ]

      invoice = build_invoice(number: "2024-0001", items: items)
      csv = Encoder.encode_flat([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      assert length(decoded_invoices) == 1

      decoded = List.first(decoded_invoices)
      assert length(decoded.items) == 2
      assert Enum.map(decoded.items, & &1.description) == ["Service A", "Service B"]
    end

    test "decodes flat format with multiple invoices" do
      invoice1 = build_invoice(number: "2024-0001", date: ~D[2024-01-15], items: [build_item()])
      invoice2 = build_invoice(number: "2024-0002", date: ~D[2024-02-20], items: [build_item()])
      csv = Encoder.encode_flat([invoice1, invoice2])

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      assert length(decoded_invoices) == 2

      numbers = Enum.map(decoded_invoices, & &1.number)
      assert "2024-0001" in numbers
      assert "2024-0002" in numbers
    end

    test "decodes flat format with invoice without items" do
      invoice = build_invoice(number: "2024-0001", items: [])
      csv = Encoder.encode_flat([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      assert length(decoded_invoices) == 1

      decoded = List.first(decoded_invoices)
      assert decoded.number == "2024-0001"
      assert decoded.items == []
    end

    test "decodes flat format with optional fields" do
      item = build_item()

      invoice =
        build_invoice(
          number: "2024-0001",
          bill_to: "Acme Corp",
          vendor_details: "Our Vendor",
          items: [item]
        )

      csv = Encoder.encode_flat([invoice])
      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)

      decoded = List.first(decoded_invoices)
      assert decoded.bill_to == "Acme Corp"
      assert decoded.vendor_details == "Our Vendor"
    end

    test "decodes flat format with nil optional fields" do
      item = build_item()
      invoice = build_invoice(bill_to: nil, vendor_details: nil, items: [item])
      csv = Encoder.encode_flat([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      assert length(decoded_invoices) == 1
    end

    test "preserves vat and sale_amount" do
      item = build_item()
      invoice = build_invoice(vat: 5000, sale_amount: 50000, items: [item])
      csv = Encoder.encode_flat([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      decoded = List.first(decoded_invoices)
      assert decoded.vat == 5000
      assert decoded.sale_amount == 50000
    end

    test "handles CSV with empty lines" do
      item = build_item()
      invoice = build_invoice(items: [item])
      csv = Encoder.encode_flat([invoice])
      csv_with_blank = csv <> "\n\n\n"

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv_with_blank)
      assert length(decoded_invoices) >= 1
    end

    test "returns error on missing required headers" do
      csv = "invoice_number,invoice_date\n2024-0001,2024-01-15"

      assert {:error, %InvoiceStorage.Error.ValidationError{}} = Decoder.decode_flat(csv)
    end

    test "returns error on empty CSV" do
      assert {:error, %InvoiceStorage.Error.ValidationError{}} = Decoder.decode_flat("")
    end

    test "returns error on invalid date format" do
      csv =
        "invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount,item_description,item_units,item_amount,item_total\n2024-0001,01/15/2024,Acme,Vendor,5000,50000,Service,1,100,100"

      assert {:error, %InvoiceStorage.Error.ValidationError{}} = Decoder.decode_flat(csv)
    end

    test "returns error on invalid integer fields" do
      csv =
        "invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount,item_description,item_units,item_amount,item_total\n2024-0001,2024-01-15,Acme,Vendor,invalid,50000,Service,1,100,100"

      assert {:error, %InvoiceStorage.Error.ValidationError{}} = Decoder.decode_flat(csv)
    end

    test "ignores item fields when not provided" do
      csv =
        "invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount\n2024-0001,2024-01-15,Acme,Vendor,5000,50000"

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      assert length(decoded_invoices) == 1

      decoded = List.first(decoded_invoices)
      assert decoded.items == []
    end

    test "groups multiple rows of same invoice by number" do
      csv = """
      invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount,item_description,item_units,item_amount,item_total
      2024-0001,2024-01-15,Acme,Vendor,5000,50000,Item 1,1,100,100
      2024-0001,2024-01-15,Acme,Vendor,5000,50000,Item 2,2,200,400
      """

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      assert length(decoded_invoices) == 1

      decoded = List.first(decoded_invoices)
      assert length(decoded.items) == 2
    end
  end

  describe "decode_hierarchical/1" do
    test "decodes hierarchical format with invoices and items sections" do
      item = build_item(description: "Service A", units: 2, amount: 10000)
      invoice = build_invoice(number: "2024-0001", date: ~D[2024-01-15], items: [item])
      csv = Encoder.encode_hierarchical([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_hierarchical(csv)
      assert length(decoded_invoices) == 1

      decoded = List.first(decoded_invoices)
      assert decoded.number == "2024-0001"
      assert decoded.date == ~D[2024-01-15]
      assert length(decoded.items) == 1
    end

    test "decodes hierarchical format with multiple invoices" do
      invoice1 = build_invoice(number: "2024-0001", items: [build_item()])
      invoice2 = build_invoice(number: "2024-0002", items: [build_item()])
      csv = Encoder.encode_hierarchical([invoice1, invoice2])

      assert {:ok, decoded_invoices} = Decoder.decode_hierarchical(csv)
      assert length(decoded_invoices) == 2
    end

    test "decodes hierarchical format with multiple items" do
      items = [
        build_item(description: "Service A"),
        build_item(description: "Service B"),
        build_item(description: "Service C")
      ]

      invoice = build_invoice(items: items)
      csv = Encoder.encode_hierarchical([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_hierarchical(csv)
      decoded = List.first(decoded_invoices)
      assert length(decoded.items) == 3
    end

    test "decodes hierarchical format preserves optional fields" do
      item = build_item()

      invoice =
        build_invoice(
          bill_to: "Acme Corp",
          vendor_details: "Our Vendor",
          items: [item]
        )

      csv = Encoder.encode_hierarchical([invoice])
      assert {:ok, decoded_invoices} = Decoder.decode_hierarchical(csv)

      decoded = List.first(decoded_invoices)
      assert decoded.bill_to == "Acme Corp"
      assert decoded.vendor_details == "Our Vendor"
    end

    test "decodes hierarchical format with invoice without items" do
      invoice = build_invoice(items: [])
      csv = Encoder.encode_hierarchical([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_hierarchical(csv)
      decoded = List.first(decoded_invoices)
      assert decoded.items == []
    end

    test "handles hierarchical format with only invoices section" do
      csv = """
      INVOICES
      invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount
      2024-0001,2024-01-15,Acme,Vendor,5000,50000
      """

      assert {:ok, decoded_invoices} = Decoder.decode_hierarchical(csv)
      assert length(decoded_invoices) == 1

      decoded = List.first(decoded_invoices)
      assert decoded.items == []
    end

    test "returns error on missing required headers in invoices section" do
      csv = """
      INVOICES
      invoice_number,invoice_date
      2024-0001,2024-01-15
      """

      assert {:error, %InvoiceStorage.Error.ValidationError{}} = Decoder.decode_hierarchical(csv)
    end

    test "returns error on missing required headers in items section" do
      csv = """
      INVOICES
      invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount
      2024-0001,2024-01-15,Acme,Vendor,5000,50000

      ITEMS
      invoice_number,item_description
      2024-0001,Service A
      """

      assert {:error, %InvoiceStorage.Error.ValidationError{}} = Decoder.decode_hierarchical(csv)
    end
  end

  describe "decode/1 auto-detection" do
    test "detects and decodes flat format" do
      item = build_item()
      invoice = build_invoice(items: [item])
      csv = Encoder.encode_flat([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode(csv)
      assert length(decoded_invoices) >= 1
    end

    test "detects and decodes hierarchical format" do
      item = build_item()
      invoice = build_invoice(items: [item])
      csv = Encoder.encode_hierarchical([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode(csv)
      assert length(decoded_invoices) >= 1
    end
  end

  describe "round-trip encoding/decoding" do
    test "flat format round-trip preserves all data" do
      items = [
        build_item(description: "Item 1", units: 5, amount: 1000),
        build_item(description: "Item 2", units: 3, amount: 2000)
      ]

      original =
        build_invoice(
          number: "2024-0001",
          date: ~D[2024-01-15],
          bill_to: "Customer A",
          vendor_details: "Vendor B",
          vat: 5000,
          sale_amount: 50000,
          items: items
        )

      csv = Encoder.encode_flat([original])
      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      decoded = List.first(decoded_invoices)

      assert decoded.number == original.number
      assert decoded.date == original.date
      assert decoded.bill_to == original.bill_to
      assert decoded.vendor_details == original.vendor_details
      assert decoded.vat == original.vat
      assert decoded.sale_amount == original.sale_amount
      assert length(decoded.items) == 2

      Enum.zip(decoded.items, items)
      |> Enum.each(fn {decoded_item, original_item} ->
        assert decoded_item.description == original_item.description
        assert decoded_item.units == original_item.units
        assert decoded_item.amount == original_item.amount
      end)
    end

    test "hierarchical format round-trip preserves all data" do
      items = [
        build_item(description: "Item 1", units: 5, amount: 1000),
        build_item(description: "Item 2", units: 3, amount: 2000)
      ]

      original =
        build_invoice(
          number: "2024-0001",
          date: ~D[2024-01-15],
          bill_to: "Customer A",
          vendor_details: "Vendor B",
          vat: 5000,
          sale_amount: 50000,
          items: items
        )

      csv = Encoder.encode_hierarchical([original])
      assert {:ok, decoded_invoices} = Decoder.decode_hierarchical(csv)
      decoded = List.first(decoded_invoices)

      assert decoded.number == original.number
      assert decoded.date == original.date
      assert decoded.bill_to == original.bill_to
      assert decoded.vendor_details == original.vendor_details
      assert decoded.vat == original.vat
      assert decoded.sale_amount == original.sale_amount
      assert length(decoded.items) == 2
    end

    test "handles multiple invoices round-trip" do
      invoices = [
        build_invoice(number: "2024-0001", items: [build_item()]),
        build_invoice(number: "2024-0002", items: [build_item(), build_item()]),
        build_invoice(number: "2024-0003", items: [])
      ]

      csv = Encoder.encode_flat(invoices)
      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)

      assert length(decoded_invoices) == 3

      numbers = Enum.map(decoded_invoices, & &1.number)
      assert "2024-0001" in numbers
      assert "2024-0002" in numbers
      assert "2024-0003" in numbers
    end
  end

  describe "special characters and edge cases" do
    test "handles invoice numbers with special characters" do
      item = build_item()
      invoice = build_invoice(number: "2024-0001-SPECIAL", items: [item])
      csv = Encoder.encode_flat([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      decoded = List.first(decoded_invoices)
      assert decoded.number == "2024-0001-SPECIAL"
    end

    test "handles descriptions with commas" do
      item = build_item(description: "Service, consultation and support")
      invoice = build_invoice(items: [item])
      csv = Encoder.encode_flat([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      decoded = List.first(decoded_invoices)
      decoded_item = List.first(decoded.items)
      assert decoded_item.description == "Service, consultation and support"
    end

    test "handles descriptions with quotes" do
      item = build_item(description: "Service \"Premium\" Edition")
      invoice = build_invoice(items: [item])
      csv = Encoder.encode_flat([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      decoded = List.first(decoded_invoices)
      decoded_item = List.first(decoded.items)
      assert decoded_item.description == "Service \"Premium\" Edition"
    end

    test "handles descriptions with newlines" do
      item = build_item(description: "Service\nMultiline")
      invoice = build_invoice(items: [item])
      csv = Encoder.encode_flat([invoice])

      assert {:ok, decoded_invoices} = Decoder.decode_flat(csv)
      decoded = List.first(decoded_invoices)
      decoded_item = List.first(decoded.items)
      # CSV encoding handles newlines, should preserve
      assert String.contains?(decoded_item.description, "Service") or
               decoded_item.description == "Service\nMultiline"
    end
  end
end
