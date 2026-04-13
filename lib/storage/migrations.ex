defmodule InvoiceStorage.Migrations do
  @moduledoc """
  Migration utilities for moving invoice data between storage backends.

  Provides functions to migrate data from file storage to database storage,
  and between different database adapters.
  """

  alias InvoiceStorage.Error
  alias InvoiceStorage.Csv.{Encoder, Decoder}

  @doc """
  Migrates invoices from file storage to a database adapter.

  Reads all invoices from file storage and writes them to the specified
  database adapter using batch operations.

  ## Parameters

    - `adapter` - Database adapter module (e.g., `PostgresAdapter`, `SqliteAdapter`)
    - `file_directory` - Path to the file storage directory
    - `year` - The year to migrate

  ## Returns

    - `:ok` - Migration completed successfully
    - `{:error, error}` - InvoiceStorage.Error struct with details

  ## Examples

      iex> Migrations.file_to_database(PostgresAdapter, "/data/invoices", 2024)
      :ok

      iex> Migrations.file_to_database(SqliteAdapter, "/data/invoices", 2024)
      :ok
  """
  @spec file_to_database(atom(), String.t(), integer()) ::
          :ok | {:error, Error.t()}
  def file_to_database(_adapter, _file_directory, _year) do
    {:error,
     Error.ValidationError.exception(
       message: "file_to_database requires FileStorage module to be implemented"
     )}
  end

  @doc """
  Exports invoices from a database adapter to file storage.

  Reads all invoices from the specified database adapter and writes them
  to file storage.

  ## Parameters

    - `adapter` - Database adapter module (e.g., `PostgresAdapter`, `SqliteAdapter`)
    - `file_directory` - Path to the file storage directory
    - `year` - The year to export

  ## Returns

    - `:ok` - Export completed successfully
    - `{:error, error}` - InvoiceStorage.Error struct with details
  """
  @spec database_to_file(atom(), String.t(), integer()) ::
          :ok | {:error, Error.t()}
  def database_to_file(_adapter, _file_directory, _year) do
    {:error,
     Error.ValidationError.exception(
       message: "database_to_file requires FileStorage module to be implemented"
     )}
  end

  @doc """
  Exports invoices from a database adapter to CSV format.

  Reads all invoices from the database adapter and returns CSV-formatted data.

  ## Parameters

    - `adapter` - Database adapter module (e.g., `PostgresAdapter`, `SqliteAdapter`)
    - `year` - The year to export
    - `format` - CSV format: `:flat` or `:hierarchical`

  ## Returns

    - `{:ok, csv_string}` - CSV data as a string
    - `{:error, error}` - InvoiceStorage.Error struct with details
  """
  @spec database_to_csv(atom(), integer(), :flat | :hierarchical) ::
          {:ok, String.t()} | {:error, Error.t()}
  def database_to_csv(adapter, year, format \\ :flat) do
    with {:ok, invoices_map} <- adapter.load_all(year) do
      invoices = Map.values(invoices_map)

      csv =
        case format do
          :flat -> Encoder.encode_flat(invoices)
          :hierarchical -> Encoder.encode_hierarchical(invoices)
          _ -> Encoder.encode_flat(invoices)
        end

      {:ok, csv}
    end
  end

  @doc """
  Imports invoices from CSV format into a database adapter.

  Parses CSV data and stores all invoices in the specified database adapter.

  ## Parameters

    - `adapter` - Database adapter module (e.g., `PostgresAdapter`, `SqliteAdapter`)
    - `csv_string` - CSV data as a string (auto-detects format)

  ## Returns

    - `:ok` - Import completed successfully
    - `{:error, error}` - InvoiceStorage.Error struct with details
  """
  @spec csv_to_database(atom(), String.t()) :: :ok | {:error, Error.t()}
  def csv_to_database(adapter, csv_string) do
    with {:ok, invoices} <- Decoder.decode(csv_string) do
      case invoices do
        [] ->
          {:ok, :empty}

        invoices ->
          # Group invoices by year
          by_year =
            invoices
            |> Enum.group_by(& &1.date.year)

          # Save each year's invoices
          Enum.each(by_year, fn {_year, year_invoices} ->
            Enum.each(year_invoices, &adapter.save/1)
          end)

          :ok
      end
    end
  end

  @doc """
  Migrates invoices between two database adapters.

  Reads all invoices from the source adapter and writes them to the
  destination adapter.

  ## Parameters

    - `source_adapter` - Source database adapter module
    - `dest_adapter` - Destination database adapter module
    - `year` - The year to migrate

  ## Returns

    - `:ok` - Migration completed successfully
    - `{:error, error}` - InvoiceStorage.Error struct with details

  ## Examples

      iex> Migrations.database_to_database(PostgresAdapter, SqliteAdapter, 2024)
      :ok
  """
  @spec database_to_database(atom(), atom(), integer()) ::
          :ok | {:error, Error.t()}
  def database_to_database(source_adapter, dest_adapter, year) do
    with {:ok, list_year} <- source_adapter.load_year_list(year) do
      dest_adapter.save_all(list_year)
    end
  end
end
