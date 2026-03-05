defmodule ListInvoiceYear.Error do
  @moduledoc """
  Structured error handling for ListInvoiceYear operations.

  This module defines error types and helpers for invoice year list validation and operations.
  Errors contain semantic type information and contextual details for debugging.

  ## Error Types

  - `:invalid_year` - Year is not a positive integer
  - `:invalid_next_id` - Next ID is negative
  - `:year_not_set` - Year must be set before adding invoices
  - `:year_mismatch` - Invoice year does not match list year
  - `:nil_invoice` - Invoice parameter is nil
  - `:invalid_invoice_type` - Invoice is not an Invoice struct

  ## Examples

      iex> error = ListInvoiceYear.Error.invalid_year(0)
      iex> error.type
      :invalid_year

      iex> error = ListInvoiceYear.Error.year_mismatch(2025, 2024)
      iex> error.type
      :year_mismatch
      iex> ListInvoiceYear.Error.to_user_message(error)
      "Invoice year 2025 does not match list year 2024"
  """

  defstruct type: nil, message: nil, context: nil

  @type error_type ::
          :invalid_year
          | :invalid_next_id
          | :year_not_set
          | :year_mismatch
          | :nil_invoice
          | :invalid_invoice_type

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          context: map()
        }

  @doc """
  Creates an error for invalid year.

  ## Parameters
    - `value` - The invalid year value

  ## Returns
    - Error struct with type `:invalid_year`
  """
  @spec invalid_year(any()) :: t()
  def invalid_year(value) do
    %ListInvoiceYear.Error{
      type: :invalid_year,
      message: "ListInvoiceYear year must be a positive integer",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for invalid next_id.

  ## Parameters
    - `value` - The invalid next_id value

  ## Returns
    - Error struct with type `:invalid_next_id`
  """
  @spec invalid_next_id(any()) :: t()
  def invalid_next_id(value) do
    %ListInvoiceYear.Error{
      type: :invalid_next_id,
      message: "ListInvoiceYear next_id must be non-negative",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error when year is not set before adding invoice.

  ## Returns
    - Error struct with type `:year_not_set`
  """
  @spec year_not_set() :: t()
  def year_not_set do
    %ListInvoiceYear.Error{
      type: :year_not_set,
      message: "ListInvoiceYear year must be set before adding invoices",
      context: %{}
    }
  end

  @doc """
  Creates an error for year mismatch between invoice and list.

  ## Parameters
    - `invoice_year` - The invoice's year
    - `list_year` - The list's year

  ## Returns
    - Error struct with type `:year_mismatch`
  """
  @spec year_mismatch(pos_integer(), pos_integer()) :: t()
  def year_mismatch(invoice_year, list_year) do
    %ListInvoiceYear.Error{
      type: :year_mismatch,
      message: "Invoice year #{invoice_year} does not match list year #{list_year}",
      context: %{invoice_year: invoice_year, list_year: list_year}
    }
  end

  @doc """
  Creates an error for nil invoice.

  ## Returns
    - Error struct with type `:nil_invoice`
  """
  @spec nil_invoice() :: t()
  def nil_invoice do
    %ListInvoiceYear.Error{
      type: :nil_invoice,
      message: "Invoice cannot be nil",
      context: %{}
    }
  end

  @doc """
  Creates an error for invoice that is not an Invoice struct.

  ## Parameters
    - `value` - The invalid invoice value

  ## Returns
    - Error struct with type `:invalid_invoice_type`
  """
  @spec invalid_invoice_type(any()) :: t()
  def invalid_invoice_type(value) do
    %ListInvoiceYear.Error{
      type: :invalid_invoice_type,
      message: "Invoice must be an Invoice struct",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Converts an error struct to a user-friendly message string.

  Combines the main message with context details for display.

  ## Parameters
    - `error` - ListInvoiceYear.Error struct

  ## Returns
    - User-friendly error message as string

  ## Examples

      iex> error = ListInvoiceYear.Error.invalid_year(0)
      iex> ListInvoiceYear.Error.to_user_message(error)
      "ListInvoiceYear year must be a positive integer (received: 0)"

      iex> error = ListInvoiceYear.Error.year_mismatch(2025, 2024)
      iex> ListInvoiceYear.Error.to_user_message(error)
      "Invoice year 2025 does not match list year 2024"
  """
  @spec to_user_message(t()) :: String.t()
  def to_user_message(%ListInvoiceYear.Error{message: message, context: context}) do
    case context do
      %{received: received} ->
        # For validation errors, show what was received
        "#{message} (received: #{received})"

      _ ->
        # Fallback to just the message (includes year mismatch details)
        message
    end
  end
end
