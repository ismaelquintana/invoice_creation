defmodule InvoiceStorage.Error do
  @moduledoc """
  Structured error types for the invoice persistence layer.

  This module defines all possible error types that can be returned by the
  persistence layer, following the pattern established by Invoice.Error
  and Item.Error modules.

  Each error type includes context information for debugging and recovery.

  ## Error Types

  - `FileNotFound` - Invoice or metadata file not found on disk
  - `PermissionDenied` - Insufficient permissions to access file
  - `DiskFull` - No space available on storage device
  - `InvalidPath` - Path construction failed due to invalid input
  - `InvalidYear` - Year parameter invalid or missing
  - `IoError` - General I/O error (disk error, corruption, etc.)
  - `InvalidJson` - JSON file is malformed or corrupted
  - `DecodeFailed` - Deserialization to domain objects failed
  - `EncodeFailed` - Serialization from domain objects failed
  - `ValidationFailed` - Deserialized data fails domain validation

  ## Usage

  All storage functions return `{:error, exception}` on failure.
  Use `InvoiceStorage.Error.format_error/1` to convert to user-friendly messages:

      case InvoiceStorage.load("2024-0001", 2024) do
        {:ok, invoice} -> {:ok, invoice}
        {:error, reason} ->
          message = InvoiceStorage.Error.format_error(reason)
          {:error, message}
      end

  ## Examples

      # File not found
      {:error, %FileNotFound{path: "2024-0001.json"}}

      # Permission error
      {:error, %PermissionDenied{path: "priv/storage/invoices/2024/"}}

      # Invalid JSON data
      {:error, %InvalidJson{path: "2024-0001.json", reason: error}}

      # Validation failed during deserialization
      {:error, %ValidationFailed{reason: error, message: msg}}
  """

  defmodule FileNotFound do
    defexception [:path, :message]

    def message(%{message: msg}) when is_binary(msg) do
      msg
    end

    def message(%{path: path}) do
      "Invoice file not found: #{path}"
    end
  end

  defmodule PermissionDenied do
    defexception [:path, :message]

    def message(%{message: msg}) when is_binary(msg) do
      msg
    end

    def message(%{path: path}) do
      "Permission denied accessing: #{path}"
    end
  end

  defmodule DiskFull do
    defexception [:path, :message]

    def message(%{message: msg}) when is_binary(msg) do
      msg
    end

    def message(%{path: path}) do
      "Disk full while writing to: #{path}"
    end
  end

  defmodule InvalidPath do
    defexception [:path, :reason, :message]

    def message(%{message: msg}) when is_binary(msg) do
      msg
    end

    def message(%{path: path, reason: reason}) do
      "Invalid path #{path}: #{reason}"
    end

    def message(%{path: path}) do
      "Invalid path: #{path}"
    end
  end

  defmodule EncodeFailed do
    defexception [:data, :reason, :message]

    def message(%{message: msg}) when is_binary(msg) do
      msg
    end

    def message(%{reason: reason}) do
      "Failed to encode invoice data: #{inspect(reason)}"
    end

    def message(_) do
      "Failed to encode invoice data"
    end
  end

  defmodule DecodeFailed do
    defexception [:path, :reason, :message]

    def message(%{message: msg}) when is_binary(msg) do
      msg
    end

    def message(%{path: path, reason: reason}) do
      "Failed to decode #{path}: #{inspect(reason)}"
    end

    def message(%{path: path}) do
      "Failed to decode #{path}"
    end
  end

  defmodule InvalidJson do
    defexception [:path, :reason, :message]

    def message(%{message: msg}) when is_binary(msg) do
      msg
    end

    def message(%{path: path, reason: reason}) do
      "Invalid JSON in #{path}: #{inspect(reason)}"
    end

    def message(%{path: path}) do
      "Invalid JSON in #{path}"
    end
  end

  defmodule InvalidInvoiceData do
    defexception [:path, :errors, :message]

    def message(%{message: msg}) when is_binary(msg) do
      msg
    end

    def message(%{path: path, errors: errors}) do
      error_list = format_errors(errors)
      "Invalid invoice data in #{path}:\n#{error_list}"
    end

    def message(%{path: path}) do
      "Invalid invoice data in #{path}"
    end

    defp format_errors(errors) when is_list(errors) do
      errors
      |> Enum.map(&format_error/1)
      |> Enum.join("\n")
    end

    defp format_errors(error), do: inspect(error)

    defp format_error({field, reason}) when is_atom(field) and is_binary(reason) do
      "  - #{field}: #{reason}"
    end

    defp format_error(error) do
      "  - #{inspect(error)}"
    end
  end

  defmodule InvalidYear do
    defexception [:year, :reason, :message]

    def message(%{message: msg}) when is_binary(msg) do
      msg
    end

    def message(%{year: year, reason: reason}) do
      "Invalid year #{year}: #{reason}"
    end

    def message(%{year: year}) do
      "Invalid year: #{year}"
    end
  end

  defmodule IoError do
    defexception [:operation, :reason, :message]

    def message(%{message: msg}) when is_binary(msg) do
      msg
    end

    def message(%{operation: op, reason: reason}) do
      "IO error during #{op}: #{inspect(reason)}"
    end

    def message(%{operation: op}) do
      "IO error during #{op}"
    end
  end

  @doc """
  Normalizes Elixir file operation errors into storage error tuples.

  Converts :enoent, :eacces, :enospc, and other OS errors into appropriate
  error types with context information.
  """
  def from_file_error(:enoent, path) do
    {:error, FileNotFound.exception(path: path)}
  end

  def from_file_error(:eacces, path) do
    {:error, PermissionDenied.exception(path: path)}
  end

  def from_file_error(:enospc, path) do
    {:error, DiskFull.exception(path: path)}
  end

  def from_file_error(reason, _path) do
    {:error, IoError.exception(operation: "file_operation", reason: reason)}
  end

  @doc """
  Formats an error for user display.

  Converts an error tuple into a user-friendly message suitable for logging
  or displaying to end users.
  """
  def format_error({:error, %{__struct__: module} = error}) do
    module.message(error)
  end

  def format_error({:error, error}) when is_atom(error) do
    "Error: #{error}"
  end

  def format_error({:error, reason}) do
    "Error: #{inspect(reason)}"
  end

  def format_error(other) do
    inspect(other)
  end
end
