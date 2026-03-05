defmodule InvoiceStorage.DecoderTest do
  use ExUnit.Case

  alias Invoice
  alias Item
  alias ListInvoiceYear
  alias InvoiceStorage.{Encoder, Decoder}

  describe "decode_invoice/1" do
    test "decodes valid invoice JSON map" do
      encoded = create_encoded_invoice()
      {:ok, decoded} = Decoder.decode_invoice(encoded)

      assert decoded.number == "2024-0001"
      assert decoded.bill_to == "Test Client"
      assert is_struct(decoded, Invoice)
    end

    test "validates invoice data after decoding" do
      encoded = create_encoded_invoice()
      {:ok, decoded} = Decoder.decode_invoice(encoded)

      # Validation should have been called
      assert is_binary(decoded.number)
    end

    test "converts date string to Date struct" do
      encoded = create_encoded_invoice()
      {:ok, decoded} = Decoder.decode_invoice(encoded)

      assert is_struct(decoded.date, Date)
      assert decoded.date == ~D[2024-03-05]
    end

    test "decodes items list correctly" do
      encoded = create_encoded_invoice()
      {:ok, decoded} = Decoder.decode_invoice(encoded)

      assert is_list(decoded.items)
      assert length(decoded.items) == 2
      assert Enum.all?(decoded.items, &is_struct(&1, Item))
    end

    test "returns error for missing date field" do
      encoded = create_encoded_invoice() |> Map.delete("date")
      result = Decoder.decode_invoice(encoded)

      assert {:error, _} = result
    end

    test "returns error for invalid date format" do
      encoded = create_encoded_invoice() |> Map.put("date", "invalid-date")
      result = Decoder.decode_invoice(encoded)

      assert {:error, %InvoiceStorage.Error.DecodeFailed{}} = result
    end

    test "returns error for non-map input" do
      result = Decoder.decode_invoice([1, 2, 3])
      assert {:error, _} = result
    end

    test "returns error for nil input" do
      result = Decoder.decode_invoice(nil)
      assert {:error, _} = result
    end
  end

  describe "decode_item/1" do
    test "decodes valid item JSON map" do
      encoded = create_encoded_item()
      {:ok, decoded} = Decoder.decode_item(encoded)

      assert decoded.description == "Test Item"
      assert decoded.units == 5
      assert decoded.amount == 100
      assert is_struct(decoded, Item)
    end

    test "validates item data after decoding" do
      encoded = create_encoded_item()
      {:ok, decoded} = Decoder.decode_item(encoded)

      # Validation from Item.new should have passed
      assert decoded.units > 0
    end

    test "returns error for non-map input" do
      result = Decoder.decode_item([1, 2, 3])
      assert {:error, _} = result
    end

    test "handles string fields correctly" do
      encoded = %{
        "description" => "Custom Description",
        "units" => 10,
        "amount" => 250
      }

      {:ok, decoded} = Decoder.decode_item(encoded)

      assert decoded.description == "Custom Description"
      assert decoded.units == 10
      assert decoded.amount == 250
    end
  end

  describe "decode_list_invoice_year/1" do
    test "decodes valid ListInvoiceYear JSON map" do
      encoded = create_encoded_list_invoice_year()
      {:ok, decoded} = Decoder.decode_list_invoice_year(encoded)

      assert decoded.year == 2024
      assert decoded.next_id == 3
      assert is_struct(decoded, ListInvoiceYear)
    end

    test "rebuilds invoices map from list" do
      encoded = create_encoded_list_invoice_year()
      {:ok, decoded} = Decoder.decode_list_invoice_year(encoded)

      assert is_map(decoded.invoices)
      assert map_size(decoded.invoices) == 2
    end

    test "maps invoices by number" do
      encoded = create_encoded_list_invoice_year()
      {:ok, decoded} = Decoder.decode_list_invoice_year(encoded)

      assert Map.has_key?(decoded.invoices, "2024-0001")
      assert Map.has_key?(decoded.invoices, "2024-0002")
      assert decoded.invoices["2024-0001"].number == "2024-0001"
      assert decoded.invoices["2024-0002"].number == "2024-0002"
    end

    test "handles empty invoices list" do
      encoded = %{
        "year" => 2024,
        "next_id" => 1,
        "invoices" => []
      }

      {:ok, decoded} = Decoder.decode_list_invoice_year(encoded)

      assert decoded.invoices == %{}
    end

    test "returns error for invalid year type" do
      encoded = %{
        "year" => "not an integer",
        "next_id" => 1,
        "invoices" => []
      }

      result = Decoder.decode_list_invoice_year(encoded)
      assert {:error, %InvoiceStorage.Error.InvalidYear{}} = result
    end

    test "returns error for non-map input" do
      result = Decoder.decode_list_invoice_year([1, 2, 3])
      assert {:error, _} = result
    end
  end

  describe "decode_date/1" do
    test "decodes ISO 8601 date string" do
      {:ok, date} = Decoder.decode_date("2024-03-05")

      assert date == ~D[2024-03-05]
      assert is_struct(date, Date)
    end

    test "returns error for invalid ISO 8601 string" do
      result = Decoder.decode_date("2024-13-32")
      assert {:error, %InvoiceStorage.Error.DecodeFailed{}} = result
    end

    test "returns error for malformed date string" do
      result = Decoder.decode_date("not-a-date")
      assert {:error, _} = result
    end

    test "returns error for nil" do
      result = Decoder.decode_date(nil)
      assert {:error, _} = result
    end

    test "returns error for non-string input" do
      result = Decoder.decode_date(2024)
      assert {:error, _} = result
    end
  end

  describe "round-trip deserialization" do
    test "invoice round-trip preserves data" do
      original = create_invoice()

      {:ok, encoded} = Encoder.encode_invoice(original)
      {:ok, decoded} = Decoder.decode_invoice(encoded)

      assert decoded.number == original.number
      assert decoded.bill_to == original.bill_to
      assert decoded.date == original.date
      assert decoded.vendor_details == original.vendor_details
      assert decoded.sale_amount == original.sale_amount
      assert decoded.vat == original.vat
    end

    test "item round-trip preserves data" do
      original = create_item()

      {:ok, encoded} = Encoder.encode_item(original)
      {:ok, decoded} = Decoder.decode_item(encoded)

      assert decoded.description == original.description
      assert decoded.units == original.units
      assert decoded.amount == original.amount
    end

    test "list_invoice_year round-trip preserves structure" do
      original = create_list_invoice_year()

      {:ok, encoded} = Encoder.encode_list_invoice_year(original)
      {:ok, decoded} = Decoder.decode_list_invoice_year(encoded)

      assert decoded.year == original.year
      assert decoded.next_id == original.next_id
      assert map_size(decoded.invoices) == map_size(original.invoices)
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

  defp create_encoded_invoice do
    invoice = create_invoice()
    {:ok, encoded} = Encoder.encode_invoice(invoice)
    encoded
  end

  defp create_encoded_item do
    item = create_item()
    {:ok, encoded} = Encoder.encode_item(item)
    encoded
  end

  defp create_encoded_list_invoice_year do
    invoice1 = create_invoice("2024-0001")
    invoice2 = create_invoice("2024-0002")

    list_year = %ListInvoiceYear{
      year: 2024,
      next_id: 3,
      invoices: %{"2024-0001" => invoice1, "2024-0002" => invoice2}
    }

    {:ok, encoded} = Encoder.encode_list_invoice_year(list_year)
    encoded
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
