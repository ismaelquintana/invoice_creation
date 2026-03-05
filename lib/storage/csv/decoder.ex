defmodule InvoiceStorage.Csv.Decoder do
  @moduledoc """
  CSV decoding functionality for importing invoices.

  Supports two formats:
  1. **Flat format**: One row per invoice item (invoice fields repeated for each item)
  2. **Hierarchical format**: Separate invoice and items sections

  Both formats are RFC 4180 compliant and can be exported by standard spreadsheet applications.

  ## Flat Format

  Each row represents an invoice item. Invoice-level data (number, date, bill_to, etc.)
  is repeated for each item on that invoice.

  Headers (required):
  - `invoice_number`, `invoice_date`, `bill_to`, `vendor_details`, `vat`, `sale_amount`
  - `item_description`, `item_units`, `item_amount`, `item_total` (optional)

  Example:
  ```
  invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount,item_description,item_units,item_amount,item_total
  2024-0001,2024-01-15,Acme Corp,Our Corp,1000,50000,Service A,2,10000,20000
  2024-0001,2024-01-15,Acme Corp,Our Corp,1000,50000,Service B,3,10000,30000
  ```

  ## Hierarchical Format

  Separate sections for invoices and items. First section contains all invoices,
  second section contains all items with invoice_number references.

  Format:
  ```
  INVOICES
  invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount
  2024-0001,2024-01-15,Acme Corp,Our Corp,1000,50000

  ITEMS
  invoice_number,item_description,item_units,item_amount,item_total
  2024-0001,Service A,2,10000,20000
  2024-0001,Service B,3,10000,30000
  ```

  ## Usage

      iex> csv = "invoice_number,invoice_date,...\\n2024-0001,2024-01-15,..."
      iex> {:ok, invoices} = InvoiceStorage.Csv.Decoder.decode_flat(csv)
      iex> is_list(invoices)
      true
  """

  alias InvoiceStorage.Error

  @doc """
  Decodes a flat-format CSV string into invoices.

  Groups rows by invoice number and creates Invoice structs with embedded items.

  ## Parameters

    - `csv_string` - CSV data as a string (RFC 4180 compliant)

  ## Returns

    - `{:ok, invoices}` - List of Invoice structs
    - `{:error, error}` - InvoiceStorage.Error struct with details

  ## Examples

      iex> csv = "invoice_number,invoice_date,bill_to,vendor_details,vat,sale_amount,item_description,item_units,item_amount,item_total\\n2024-0001,2024-01-15,Acme Corp,Our Corp,1000,50000,Service A,2,10000,20000"
      iex> {:ok, invoices} = decode_flat(csv)
      iex> length(invoices)
      1
  """
  @spec decode_flat(String.t()) :: {:ok, [Invoice.t()]} | {:error, Error.t()}
  def decode_flat(csv_string) when is_binary(csv_string) do
    with {:ok, rows} <- parse_csv(csv_string),
         {:ok, headers} <- extract_headers(rows),
         {:ok, data_rows} <- validate_headers_flat(headers),
         {:ok, invoices_map} <- process_flat_rows(rows, data_rows, headers) do
      # Convert map of invoices to list
      invoices =
        invoices_map
        |> Map.values()
        |> Enum.sort_by(& &1.number)

      {:ok, invoices}
    end
  end

  @doc """
  Decodes a hierarchical-format CSV string into invoices.

  Parses separate INVOICES and ITEMS sections and reconstructs Invoice structs.

  ## Parameters

    - `csv_string` - CSV data with separate INVOICES and ITEMS sections

  ## Returns

    - `{:ok, invoices}` - List of Invoice structs
    - `{:error, error}` - InvoiceStorage.Error struct with details
  """
  @spec decode_hierarchical(String.t()) :: {:ok, [Invoice.t()]} | {:error, Error.t()}
  def decode_hierarchical(csv_string) when is_binary(csv_string) do
    with {:ok, invoices_section, items_section} <- split_hierarchical_sections(csv_string),
         {:ok, invoices_map} <- parse_invoices_section(invoices_section),
         {:ok, items_by_invoice} <- parse_items_section(items_section) do
      # Attach items to invoices
      result =
        invoices_map
        |> Enum.map(fn {invoice_number, invoice} ->
          items = Map.get(items_by_invoice, invoice_number, [])
          %{invoice | items: items}
        end)
        |> Enum.sort_by(& &1.number)

      {:ok, result}
    end
  end

  @doc """
  Auto-detects the CSV format (flat or hierarchical) and decodes accordingly.

  Checks for the presence of INVOICES/ITEMS section markers to determine format.

  ## Parameters

    - `csv_string` - CSV data as a string

  ## Returns

    - `{:ok, invoices}` - List of Invoice structs
    - `{:error, error}` - InvoiceStorage.Error struct with details
  """
  @spec decode(String.t()) :: {:ok, [Invoice.t()]} | {:error, Error.t()}
  def decode(csv_string) when is_binary(csv_string) do
    if String.contains?(csv_string, "INVOICES") or String.contains?(csv_string, "ITEMS") do
      decode_hierarchical(csv_string)
    else
      decode_flat(csv_string)
    end
  end

  # ============================================================================
  # Private Helpers - CSV Parsing
  # ============================================================================

  @spec parse_csv(String.t()) :: {:ok, [[String.t()]]} | {:error, Error.t()}
  defp parse_csv(csv_string) do
    try do
      # Split by newlines, trim each line, and decode each row
      rows =
        csv_string
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(String.length(&1) == 0))
        |> Enum.map(&decode_row/1)
        |> Enum.reject(&Enum.empty?/1)

      {:ok, rows}
    rescue
      e ->
        {:error, Error.ValidationError.exception(message: "Failed to parse CSV: #{inspect(e)}")}
    end
  end

  @spec decode_row(String.t()) :: [String.t()]
  defp decode_row(line) do
    case CSV.decode([line]) |> Enum.to_list() do
      [{:ok, row}] when is_list(row) -> row
      _ -> []
    end
  end

  @spec extract_headers([list()]) :: {:ok, [String.t()]} | {:error, Error.t()}
  defp extract_headers([]), do: {:error, Error.ValidationError.exception(message: "CSV is empty")}

  defp extract_headers([headers | _]) do
    case headers do
      [] ->
        {:error, Error.ValidationError.exception(message: "CSV has no headers")}

      headers when is_list(headers) ->
        {:ok, Enum.map(headers, &String.trim/1)}

      _ ->
        {:error, Error.ValidationError.exception(message: "Invalid headers format")}
    end
  end

  @spec validate_headers_flat([String.t()]) :: {:ok, [String.t()]} | {:error, Error.t()}
  defp validate_headers_flat(headers) do
    required_headers = [
      "invoice_number",
      "invoice_date",
      "bill_to",
      "vendor_details",
      "vat",
      "sale_amount"
    ]

    missing =
      Enum.filter(required_headers, fn header ->
        not Enum.any?(headers, &String.equivalent?(&1, header))
      end)

    case missing do
      [] ->
        {:ok, headers}

      missing ->
        {:error, Error.ValidationError.exception(message: "Missing headers: #{inspect(missing)}")}
    end
  end

  @spec process_flat_rows([[String.t()]], [String.t()], [String.t()]) ::
          {:ok, map()} | {:error, Error.t()}
  defp process_flat_rows(rows, headers, _headers) do
    # Skip header row
    [_header_row | data_rows] = rows

    result =
      Enum.reduce_while(data_rows, {:ok, %{}}, fn row, acc ->
        case {acc, parse_flat_row(row, headers)} do
          {{:ok, invoices}, {:ok, invoice_number, invoice, item}} ->
            # Group by invoice number
            updated_invoices =
              Map.update(invoices, invoice_number, invoice, fn existing ->
                case item do
                  nil ->
                    existing

                  item ->
                    %{existing | items: existing.items ++ [item]}
                end
              end)

            {:cont, {:ok, updated_invoices}}

          {_, {:error, error}} ->
            {:halt, {:error, error}}

          {{:error, error}, _} ->
            {:halt, {:error, error}}
        end
      end)

    result
  end

  @spec parse_flat_row([String.t()], [String.t()]) ::
          {:ok, String.t(), Invoice.t(), Item.t() | nil} | {:error, Error.t()}
  defp parse_flat_row(row, headers) do
    with {:ok, parsed} <- parse_row_to_map(row, headers),
         {:ok, invoice_number} <- extract_string(parsed, "invoice_number"),
         {:ok, date} <- extract_date(parsed, "invoice_date"),
         {:ok, vat} <- extract_integer(parsed, "vat"),
         {:ok, sale_amount} <- extract_integer(parsed, "sale_amount") do
      bill_to = extract_optional_string(parsed, "bill_to")
      vendor_details = extract_optional_string(parsed, "vendor_details")

      invoice = %Invoice{
        number: invoice_number,
        date: date,
        bill_to: bill_to,
        vendor_details: vendor_details,
        vat: vat,
        sale_amount: sale_amount,
        items: []
      }

      # Try to parse item if present
      item =
        case {extract_optional_string(parsed, "item_description"),
              extract_optional_integer(parsed, "item_units"),
              extract_optional_integer(parsed, "item_amount")} do
          {nil, _, _} ->
            nil

          {description, units, amount} when is_binary(description) ->
            %Item{
              description: description,
              units: units || 0,
              amount: amount || 0
            }

          _ ->
            nil
        end

      {:ok, invoice_number, invoice, item}
    end
  end

  @spec parse_row_to_map([String.t()], [String.t()]) :: {:ok, map()} | {:error, Error.t()}
  defp parse_row_to_map(row, headers) do
    try do
      map =
        headers
        |> Enum.zip(row)
        |> Enum.into(%{})

      {:ok, map}
    rescue
      e ->
        {:error, Error.ValidationError.exception(message: "Failed to parse row: #{inspect(e)}")}
    end
  end

  # ============================================================================
  # Private Helpers - Field Extraction
  # ============================================================================

  @spec extract_string(map(), String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  defp extract_string(map, key) do
    case Map.get(map, key, "") |> String.trim() do
      "" ->
        {:error,
         Error.ValidationError.exception(message: "Missing or empty required field: #{key}")}

      value ->
        {:ok, value}
    end
  end

  @spec extract_optional_string(map(), String.t()) :: String.t() | nil
  defp extract_optional_string(map, key) do
    case Map.get(map, key, "") |> String.trim() do
      "" -> nil
      value -> value
    end
  end

  @spec extract_date(map(), String.t()) :: {:ok, Date.t()} | {:error, Error.t()}
  defp extract_date(map, key) do
    case extract_string(map, key) do
      {:ok, value} ->
        case Date.from_iso8601(value) do
          {:ok, date} ->
            {:ok, date}

          {:error, _} ->
            {:error,
             Error.ValidationError.exception(
               message: "Invalid date format for #{key}: expected YYYY-MM-DD"
             )}
        end

      error ->
        error
    end
  end

  @spec extract_integer(map(), String.t()) :: {:ok, integer()} | {:error, Error.t()}
  defp extract_integer(map, key) do
    with {:ok, value} <- extract_string(map, key) do
      case Integer.parse(value) do
        {num, ""} ->
          {:ok, num}

        _ ->
          {:error,
           Error.ValidationError.exception(message: "Invalid integer for #{key}: #{value}")}
      end
    end
  end

  @spec extract_optional_integer(map(), String.t()) :: integer() | nil
  defp extract_optional_integer(map, key) do
    case Map.get(map, key, "") |> String.trim() do
      "" ->
        nil

      value ->
        case Integer.parse(value) do
          {num, ""} -> num
          _ -> nil
        end
    end
  end

  # ============================================================================
  # Private Helpers - Hierarchical Format
  # ============================================================================

  @spec split_hierarchical_sections(String.t()) ::
          {:ok, String.t(), String.t()} | {:error, Error.t()}
  defp split_hierarchical_sections(csv_string) do
    case String.split(csv_string, ~r/\n\s*\n/, parts: 2) do
      [invoices_section, items_section] ->
        {:ok, invoices_section, items_section}

      [single_section] ->
        # Could be INVOICES or ITEMS only
        if String.contains?(single_section, "INVOICES") do
          {:ok, single_section, ""}
        else
          {:ok, "", single_section}
        end

      _ ->
        {:error,
         Error.ValidationError.exception(
           message: "Invalid hierarchical format: expected INVOICES and ITEMS sections"
         )}
    end
  end

  @spec parse_invoices_section(String.t()) :: {:ok, map()} | {:error, Error.t()}
  defp parse_invoices_section(""), do: {:ok, %{}}

  defp parse_invoices_section(section) do
    with {:ok, rows} <- parse_csv(section) do
      # First row might be "INVOICES" label, skip it
      {rows_to_process, headers} =
        case rows do
          [["INVOICES"] | rest] -> {rest, validate_invoices_headers(rest)}
          rest -> {rest, validate_invoices_headers(rest)}
        end

      case headers do
        {:ok, headers} ->
          # First row is now the headers
          [_header_row | data_rows] = rows_to_process

          invoices =
            Enum.reduce(data_rows, %{}, fn row, acc ->
              case parse_invoice_row(row, headers) do
                {:ok, invoice_number, invoice} ->
                  Map.put(acc, invoice_number, invoice)

                {:error, _} ->
                  acc
              end
            end)

          {:ok, invoices}

        error ->
          error
      end
    end
  end

  @spec validate_invoices_headers([[String.t()]]) :: {:ok, [String.t()]} | {:error, Error.t()}
  defp validate_invoices_headers([]),
    do: {:error, Error.ValidationError.exception(message: "Empty invoices section")}

  defp validate_invoices_headers([headers | _]) do
    headers_to_check = Enum.map(headers, &String.trim/1)

    required = [
      "invoice_number",
      "invoice_date",
      "bill_to",
      "vendor_details",
      "vat",
      "sale_amount"
    ]

    missing =
      Enum.filter(required, fn header ->
        not Enum.any?(headers_to_check, &String.equivalent?(&1, header))
      end)

    case missing do
      [] ->
        {:ok, headers_to_check}

      missing ->
        {:error,
         Error.ValidationError.exception(message: "Missing invoice headers: #{inspect(missing)}")}
    end
  end

  @spec parse_invoice_row([String.t()], [String.t()]) ::
          {:ok, String.t(), Invoice.t()} | {:error, Error.t()}
  defp parse_invoice_row(row, headers) do
    with {:ok, parsed} <- parse_row_to_map(row, headers),
         {:ok, invoice_number} <- extract_string(parsed, "invoice_number"),
         {:ok, date} <- extract_date(parsed, "invoice_date"),
         {:ok, vat} <- extract_integer(parsed, "vat"),
         {:ok, sale_amount} <- extract_integer(parsed, "sale_amount") do
      bill_to = extract_optional_string(parsed, "bill_to")
      vendor_details = extract_optional_string(parsed, "vendor_details")

      invoice = %Invoice{
        number: invoice_number,
        date: date,
        bill_to: bill_to,
        vendor_details: vendor_details,
        vat: vat,
        sale_amount: sale_amount,
        items: []
      }

      {:ok, invoice_number, invoice}
    end
  end

  @spec parse_items_section(String.t()) :: {:ok, map()} | {:error, Error.t()}
  defp parse_items_section(""), do: {:ok, %{}}

  defp parse_items_section(section) do
    with {:ok, rows} <- parse_csv(section) do
      # First row might be "ITEMS" label, skip it
      {rows_to_process, headers} =
        case rows do
          [["ITEMS"] | rest] -> {rest, validate_items_headers(rest)}
          rest -> {rest, validate_items_headers(rest)}
        end

      case headers do
        {:ok, headers} ->
          # First row is now the headers
          [_header_row | data_rows] = rows_to_process

          items_by_invoice =
            Enum.reduce(data_rows, %{}, fn row, acc ->
              case parse_item_row(row, headers) do
                {:ok, invoice_number, item} ->
                  Map.update(acc, invoice_number, [item], fn items -> items ++ [item] end)

                {:error, _} ->
                  acc
              end
            end)

          {:ok, items_by_invoice}

        error ->
          error
      end
    end
  end

  @spec validate_items_headers([[String.t()]]) :: {:ok, [String.t()]} | {:error, Error.t()}
  defp validate_items_headers([]),
    do: {:error, Error.ValidationError.exception(message: "Empty items section")}

  defp validate_items_headers([headers | _]) do
    headers_to_check = Enum.map(headers, &String.trim/1)

    required = [
      "invoice_number",
      "item_description",
      "item_units",
      "item_amount"
    ]

    missing =
      Enum.filter(required, fn header ->
        not Enum.any?(headers_to_check, &String.equivalent?(&1, header))
      end)

    case missing do
      [] ->
        {:ok, headers_to_check}

      missing ->
        {:error,
         Error.ValidationError.exception(message: "Missing item headers: #{inspect(missing)}")}
    end
  end

  @spec parse_item_row([String.t()], [String.t()]) ::
          {:ok, String.t(), Item.t()} | {:error, Error.t()}
  defp parse_item_row(row, headers) do
    with {:ok, parsed} <- parse_row_to_map(row, headers),
         {:ok, invoice_number} <- extract_string(parsed, "invoice_number"),
         {:ok, description} <- extract_string(parsed, "item_description"),
         {:ok, units} <- extract_integer(parsed, "item_units"),
         {:ok, amount} <- extract_integer(parsed, "item_amount") do
      item = %Item{
        description: description,
        units: units,
        amount: amount
      }

      {:ok, invoice_number, item}
    end
  end
end
