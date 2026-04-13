defmodule InvoiceStorage do
  @moduledoc """
  Main API for invoice persistence layer.

  Provides a complete interface for saving and loading invoices from disk,
  supporting individual invoice operations and bulk year-based operations.

  ## Overview

  InvoiceStorage enables:
  - Saving and loading individual invoices
  - Bulk operations on entire years of invoices
  - Metadata tracking (next invoice ID per year)
  - File existence checks
  - Year discovery and invoice counting

  ## Storage Format & Location

  - **Format:** JSON files with ISO 8601 dates
  - **Location:** `priv/storage/` (configured via config)
  - **Organization:** Year-based directory structure

  ## Directory Structure

      priv/storage/
      ├── invoices/
      │   ├── 2024/
      │   │   ├── 2024-0001.json
      │   │   ├── 2024-0002.json
      │   │   └── ...
      │   └── 2023/
      │       └── ...
      └── years/
          ├── 2024.json (metadata: year, next_id)
          └── 2023.json

  ## Error Handling

  All functions return:
  - `{:ok, result}` on success
  - `{:error, exception}` on failure

  Error types include: `FileNotFound`, `IoError`, `InvalidJson`, `InvalidPath`, etc.

  For user-friendly messages, use `InvoiceStorage.Error.format_error/1`.

  ## Examples

      # Save a single invoice
      {:ok, invoice} = Invoice.new(bill_to: "Acme Corp")
      :ok = InvoiceStorage.save(invoice)

      # Load an invoice
      {:ok, loaded} = InvoiceStorage.load("2024-0001", 2024)

      # Check if invoice exists
      true = InvoiceStorage.exists?("2024-0001", 2024)

      # Save all invoices in a year
      {:ok, list_year} = ListInvoiceYear.new(year: 2024)
      :ok = InvoiceStorage.save_all(list_year)

      # Load all invoices for a year
      {:ok, invoices} = InvoiceStorage.load_all(2024)

      # List all stored years
      {:ok, years} = InvoiceStorage.list_years()

  ## Configuration

  Configure storage location in `config/config.exs`:

      config :invoice_creation,
        storage_dir: "priv/storage"

  ## Database Adapter Pattern (Future)

  While currently file-based, the storage layer is designed to support
  database adapters. Future implementations should follow the same API
  contract defined here while replacing file operations with database calls.

  See `InvoiceStorage.DatabaseAdapter` (planned) for interface definition.
  """

  alias Invoice
  alias ListInvoiceYear
  alias InvoiceStorage.{Encoder, Decoder, Error}
  alias Error.{FileNotFound, InvalidPath, InvalidYear, IoError}

  @doc """
  Saves an individual invoice to disk.

  Creates the directory structure if it doesn't exist.
  Filename: invoice-number.json (e.g., "2024-0001.json")

  Returns :ok on success or {:error, exception} on failure.
  """
  def save(%Invoice{} = invoice) do
    with {:ok, path} <- invoice_path(invoice.number, invoice.date.year),
         :ok <- ensure_dir(path),
         {:ok, encoded} <- Encoder.encode_invoice(invoice),
         json <- Jason.encode!(encoded),
         :ok <- File.write(path, json) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, IoError.exception(operation: "save_invoice", reason: e)}
  end

  def save(data) do
    {:error,
     Error.EncodeFailed.exception(
       reason: :invalid_type,
       message: "Expected Invoice struct, got #{inspect(data)}"
     )}
  end

  @doc """
  Loads an individual invoice from disk by invoice number and year.

  Returns {:ok, Invoice} on success or {:error, exception} on failure.
  """
  def load(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    with {:ok, path} <- invoice_path(invoice_number, year),
         {:ok, contents} <- File.read(path),
         {:ok, data} <- Jason.decode(contents),
         {:ok, invoice} <- Decoder.decode_invoice(data) do
      {:ok, invoice}
    else
      {:error, :enoent} ->
        {:error, FileNotFound.exception(path: invoice_file_name(invoice_number))}

      {:error, %Jason.DecodeError{} = e} ->
        {:error,
         Error.InvalidJson.exception(
           path: invoice_file_name(invoice_number),
           reason: e
         )}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, IoError.exception(operation: "load_invoice", reason: e)}
  end

  def load(invoice_number, year) do
    {:error,
     InvalidPath.exception(
       path: inspect({invoice_number, year}),
       reason: "invoice_number must be a string and year must be an integer"
     )}
  end

  @doc """
  Deletes an invoice file from disk.

  Returns :ok on success or {:error, exception} on failure.
  If the file doesn't exist, returns FileNotFound error.
  """
  def delete(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    with {:ok, path} <- invoice_path(invoice_number, year),
         :ok <- File.rm(path) do
      :ok
    else
      {:error, :enoent} ->
        {:error, FileNotFound.exception(path: invoice_file_name(invoice_number))}

      {:error, reason} ->
        Error.from_file_error(reason, invoice_file_name(invoice_number))
    end
  rescue
    e -> {:error, IoError.exception(operation: "delete_invoice", reason: e)}
  end

  def delete(invoice_number, year) do
    {:error,
     InvalidPath.exception(
       path: inspect({invoice_number, year}),
       reason: "invoice_number must be a string and year must be an integer"
     )}
  end

  @doc """
  Checks if an invoice file exists on disk.

  Returns boolean indicating file existence.
  """
  def exists?(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    case invoice_path(invoice_number, year) do
      {:ok, path} -> File.exists?(path)
    end
  end

  def exists?(_invoice_number, _year), do: false

  @doc """
  Saves all invoices from a ListInvoiceYear to disk.

  Creates year-specific directory and saves each invoice individually.
  If any invoice fails, the operation stops and returns the error.

  Returns :ok on success or {:error, exception} on failure.
  """
  def save_all(%ListInvoiceYear{} = list_year) do
    list_year.invoices
    |> Enum.reduce_while(:ok, fn {_number, invoice}, :ok ->
      case save(invoice) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  def save_all(data) do
    {:error,
     Error.EncodeFailed.exception(
       reason: :invalid_type,
       message: "Expected ListInvoiceYear struct, got #{inspect(data)}"
     )}
  end

  @doc """
  Loads all invoices for a specific year from disk.

  Scans the year-specific directory and loads all invoice files.
  Returns a map keyed by invoice number, suitable for building a ListInvoiceYear.

  Returns {:ok, invoices_map} on success or {:error, exception} on failure.
  If the year directory doesn't exist, returns {:ok, %{}} (empty map).
  """
  def load_all(year) when is_integer(year) do
    with {:ok, year_dir} <- year_directory(year),
         {:ok, files} <- File.ls(year_dir) do
      files
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.reduce_while({:ok, %{}}, fn file, {:ok, acc} ->
        number = extract_invoice_number(file)

        case load(number, year) do
          {:ok, invoice} -> {:cont, {:ok, Map.put(acc, number, invoice)}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    else
      {:error, :enoent} -> {:ok, %{}}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, IoError.exception(operation: "load_all", reason: e)}
  end

  def load_all(year) do
    {:error,
     InvalidYear.exception(
       year: year,
       reason: "year must be an integer"
     )}
  end

  @doc """
  Saves a ListInvoiceYear record to disk.

  Stores year metadata (year, next_id) separately from individual invoices.
  This enables quick lookup of next_id without loading all invoices.

  Returns :ok on success or {:error, exception} on failure.
  """
  def save_year_list(%ListInvoiceYear{} = list_year) do
    with {:ok, path} <- year_list_path(list_year.year),
         :ok <- ensure_dir(path),
         {:ok, encoded} <- Encoder.encode_list_invoice_year(list_year),
         json <- Jason.encode!(encoded),
         :ok <- File.write(path, json) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, IoError.exception(operation: "save_year_list", reason: e)}
  end

  def save_year_list(data) do
    {:error,
     Error.EncodeFailed.exception(
       reason: :invalid_type,
       message: "Expected ListInvoiceYear struct, got #{inspect(data)}"
     )}
  end

  @doc """
  Loads a ListInvoiceYear record from disk by year.

  Reads the year metadata file. The invoices map will be empty unless
  load_all/1 is called separately to populate individual invoices.

  Returns {:ok, ListInvoiceYear} on success or {:error, exception} on failure.
  """
  def load_year_list(year) when is_integer(year) do
    with {:ok, path} <- year_list_path(year),
         {:ok, contents} <- File.read(path),
         {:ok, data} <- Jason.decode(contents),
         {:ok, list_year} <- Decoder.decode_list_invoice_year(data) do
      {:ok, list_year}
    else
      {:error, :enoent} ->
        {:error, FileNotFound.exception(path: year_list_file_name(year))}

      {:error, %Jason.DecodeError{} = e} ->
        {:error,
         Error.InvalidJson.exception(
           path: year_list_file_name(year),
           reason: e
         )}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, IoError.exception(operation: "load_year_list", reason: e)}
  end

  def load_year_list(year) do
    {:error,
     InvalidYear.exception(
       year: year,
       reason: "year must be an integer"
     )}
  end

  @doc """
  Lists all years that have saved invoices.

  Scans the invoices directory and returns a sorted list of years.
  Returns {:ok, years_list} on success or {:error, exception} on failure.
  """
  def list_years do
    # Check both year list files and invoice year directories for backward compatibility
    years_from_files =
      case years_directory() do
        {:ok, years_dir} ->
          case File.ls(years_dir) do
            {:ok, files} ->
              files
              |> Enum.filter(&String.ends_with?(&1, ".json"))
              |> Enum.map(&String.replace_trailing(&1, ".json", ""))
              |> Enum.map(&String.to_integer/1)

            {:error, :enoent} ->
              []

            {:error, _} ->
              []
          end
      end

    # Also check invoice directories for years with saved invoices
    years_from_invoices =
      case invoices_directory() do
        {:ok, invoices_dir} ->
          case File.ls(invoices_dir) do
            {:ok, dirs} ->
              dirs
              |> Enum.filter(fn dir ->
                File.dir?(Path.join(invoices_dir, dir))
              end)
              |> Enum.map(&String.to_integer/1)

            {:error, :enoent} ->
              []

            {:error, _} ->
              []
          end
      end

    # Combine and deduplicate
    all_years =
      (years_from_files ++ years_from_invoices)
      |> Enum.uniq()
      |> Enum.sort(:desc)

    {:ok, all_years}
  rescue
    e -> {:error, IoError.exception(operation: "list_years", reason: e)}
  end

  @doc """
  Counts invoices in a specific year.

  Returns {:ok, count} on success or {:error, exception} on failure.
  """
  def count(year) when is_integer(year) do
    with {:ok, year_dir} <- year_directory(year),
         {:ok, files} <- File.ls(year_dir) do
      count = Enum.count(files, &String.ends_with?(&1, ".json"))
      {:ok, count}
    else
      {:error, :enoent} -> {:ok, 0}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, IoError.exception(operation: "count", reason: e)}
  end

  def count(year) do
    {:error,
     InvalidYear.exception(
       year: year,
       reason: "year must be an integer"
     )}
  end

  # Private path helpers

  defp storage_root do
    Application.get_env(:invoice_creation, :storage_root, default_storage_root())
  end

  defp default_storage_root do
    Path.join([:code.priv_dir(:invoice_creation), "storage"])
  end

  defp years_directory do
    {:ok, Path.join(storage_root(), "years")}
  end

  defp invoices_directory do
    {:ok, Path.join(storage_root(), "invoices")}
  end

  defp year_directory(year) when is_integer(year) do
    {:ok, Path.join([storage_root(), "invoices", Integer.to_string(year)])}
  end

  defp invoice_path(invoice_number, year) when is_binary(invoice_number) and is_integer(year) do
    {:ok,
     Path.join([
       storage_root(),
       "invoices",
       Integer.to_string(year),
       invoice_file_name(invoice_number)
     ])}
  end

  defp invoice_file_name(invoice_number) do
    "#{invoice_number}.json"
  end

  defp year_list_path(year) when is_integer(year) do
    {:ok, Path.join([storage_root(), "years", year_list_file_name(year)])}
  end

  defp year_list_file_name(year) do
    "#{year}.json"
  end

  defp ensure_dir(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()
  end

  defp extract_invoice_number(file_name) do
    String.replace_suffix(file_name, ".json", "")
  end
end
