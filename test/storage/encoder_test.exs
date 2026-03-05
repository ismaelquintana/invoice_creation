defmodule InvoiceStorage.EncoderTest do
  use ExUnit.Case

  alias Invoice
  alias Item
  alias ListInvoiceYear
  alias InvoiceStorage.Encoder

  describe "encode_invoice/1" do
    test "encodes invoice to JSON-compatible map" do
      invoice = create_invoice()
      {:ok, encoded} = Encoder.encode_invoice(invoice)

      assert is_map(encoded)
      assert encoded["number"] == invoice.number
      assert encoded["bill_to"] == invoice.bill_to
    end

    test "converts date to ISO 8601 string" do
      invoice = create_invoice()
      {:ok, encoded} = Encoder.encode_invoice(invoice)

      assert encoded["date"] == "2024-03-05"
      assert is_binary(encoded["date"])
    end

    test "encodes all required fields" do
      invoice = create_invoice()
      {:ok, encoded} = Encoder.encode_invoice(invoice)

      assert Map.has_key?(encoded, "date")
      assert Map.has_key?(encoded, "number")
      assert Map.has_key?(encoded, "bill_to")
      assert Map.has_key?(encoded, "vendor_details")
      assert Map.has_key?(encoded, "items")
      assert Map.has_key?(encoded, "sale_amount")
      assert Map.has_key?(encoded, "vat")
    end

    test "encodes items as list" do
      invoice = create_invoice()
      {:ok, encoded} = Encoder.encode_invoice(invoice)

      assert is_list(encoded["items"])
      assert length(encoded["items"]) == 2
    end

    test "returns error for non-Invoice struct" do
      result = Encoder.encode_invoice(%{"not" => "invoice"})
      assert {:error, _} = result
    end

    test "returns error for nil" do
      result = Encoder.encode_invoice(nil)
      assert {:error, _} = result
    end
  end

  describe "encode_item/1" do
    test "encodes item to JSON-compatible map" do
      item = create_item()
      {:ok, encoded} = Encoder.encode_item(item)

      assert is_map(encoded)
      assert encoded["description"] == item.description
      assert encoded["units"] == item.units
      assert encoded["amount"] == item.amount
    end

    test "encodes all fields" do
      item = create_item()
      {:ok, encoded} = Encoder.encode_item(item)

      assert encoded["description"] == "Test Item"
      assert encoded["units"] == 5
      assert encoded["amount"] == 100
    end

    test "handles string description" do
      item = %Item{description: "Custom Description", units: 10, amount: 50}
      {:ok, encoded} = Encoder.encode_item(item)

      assert encoded["description"] == "Custom Description"
    end

    test "returns error for non-Item struct" do
      result = Encoder.encode_item(%{"not" => "item"})
      assert {:error, _} = result
    end

    test "returns error for nil" do
      result = Encoder.encode_item(nil)
      assert {:error, _} = result
    end
  end

  describe "encode_list_invoice_year/1" do
    test "encodes ListInvoiceYear to JSON-compatible map" do
      list_year = create_list_invoice_year()
      {:ok, encoded} = Encoder.encode_list_invoice_year(list_year)

      assert is_map(encoded)
      assert encoded["year"] == 2024
      assert encoded["next_id"] == 3
    end

    test "encodes all invoices in list" do
      invoice1 = create_invoice("1")
      invoice2 = create_invoice("2")

      list_year = %ListInvoiceYear{
        year: 2024,
        next_id: 3,
        invoices: %{"1" => invoice1, "2" => invoice2}
      }

      {:ok, encoded} = Encoder.encode_list_invoice_year(list_year)

      assert is_list(encoded["invoices"])
      assert length(encoded["invoices"]) == 2
    end

    test "encodes invoices with all fields" do
      list_year = create_list_invoice_year()
      {:ok, encoded} = Encoder.encode_list_invoice_year(list_year)

      assert Enum.all?(encoded["invoices"], fn inv ->
        Map.has_key?(inv, "date") &&
          Map.has_key?(inv, "number") &&
          Map.has_key?(inv, "items")
      end)
    end

    test "returns error for non-ListInvoiceYear" do
      result = Encoder.encode_list_invoice_year(%{})
      assert {:error, _} = result
    end

    test "handles empty invoices map" do
      list_year = %ListInvoiceYear{
        year: 2024,
        next_id: 1,
        invoices: %{}
      }

      {:ok, encoded} = Encoder.encode_list_invoice_year(list_year)

      assert encoded["invoices"] == []
    end
  end

  describe "encode_invoice!/1" do
    test "returns encoded map on success" do
      invoice = create_invoice()
      encoded = Encoder.encode_invoice!(invoice)

      assert is_map(encoded)
      assert encoded["number"] == invoice.number
    end

    test "raises exception on error" do
      assert_raise InvoiceStorage.Error.EncodeFailed, fn ->
        Encoder.encode_invoice!("not an invoice")
      end
    end
  end

  describe "encode_item!/1" do
    test "returns encoded map on success" do
      item = create_item()
      encoded = Encoder.encode_item!(item)

      assert is_map(encoded)
      assert encoded["description"] == "Test Item"
    end

    test "raises exception on error" do
      assert_raise InvoiceStorage.Error.EncodeFailed, fn ->
        Encoder.encode_item!("not an item")
      end
    end
  end

  describe "round-trip serialization" do
    test "invoice survives encode/decode cycle" do
      original = create_invoice()

      {:ok, encoded} = Encoder.encode_invoice(original)
      json = Jason.encode!(encoded)
      {:ok, decoded_map} = Jason.decode(json)

      {:ok, restored} = InvoiceStorage.Decoder.decode_invoice(decoded_map)

      assert restored.number == original.number
      assert restored.bill_to == original.bill_to
      assert restored.date == original.date
      assert length(restored.items) == length(original.items)
    end

    test "item survives encode/decode cycle" do
      original = create_item()

      {:ok, encoded} = Encoder.encode_item(original)
      json = Jason.encode!(encoded)
      {:ok, decoded_map} = Jason.decode(json)

      {:ok, restored} = InvoiceStorage.Decoder.decode_item(decoded_map)

      assert restored.description == original.description
      assert restored.units == original.units
      assert restored.amount == original.amount
    end
  end

  # Helpers

  defp create_invoice(number \\ "2024-0001") do
    {:ok, invoice} =
      Invoice.new(
        number: number,
        date: Date.new!(2024, 3, 5),
        bill_to: "Test Client",
        vendor_details: "Test Vendor",
        items: [
          create_item(),
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

  defp create_list_invoice_year do
    invoice1 = create_invoice("2024-0001")
    invoice2 = create_invoice("2024-0002")

    %ListInvoiceYear{
      year: 2024,
      next_id: 3,
      invoices: %{"2024-0001" => invoice1, "2024-0002" => invoice2}
    }
  end
end
