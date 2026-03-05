defmodule Invoice.Error do
  @moduledoc """
  Structured error handling for invoice operations.

  This module defines error types and helpers for invoice validation and operations.
  Errors contain semantic type information and contextual details for debugging.

  ## Error Types

  - `:nil_item` - Item parameter is nil
  - `:invalid_item_type` - Item is not an Item struct
  - `:invalid_item` - Item has invalid fields (description/units/amount)
  - `:invalid_date` - Date field is not a Date struct
  - `:invalid_number` - Number field is not a string
  - `:invalid_bill_to` - Bill to field is not a string
  - `:invalid_vendor_details` - Vendor details field is not a string
  - `:invalid_vat` - VAT is negative or not integer
  - `:invalid_sale_amount` - Sale amount is negative or not integer
  - `:invalid_items_list` - Items parameter is not a list

  ## Examples

      iex> error = Invoice.Error.nil_item()
      iex> error.type
      :nil_item

      iex> error = Invoice.Error.invalid_item([{:units, "must be positive integer (got 0)"}])
      iex> error.type
      :invalid_item
      iex> to_user_message(error)
      "Item is invalid: units must be positive integer (got 0)"
  """

  defstruct type: nil, message: nil, context: nil

  @type error_type ::
          :nil_item
          | :invalid_item_type
          | :invalid_item
          | :invalid_date
          | :invalid_number
          | :invalid_bill_to
          | :invalid_vendor_details
          | :invalid_vat
          | :invalid_sale_amount
          | :invalid_items_list
          | :number_too_long
          | :bill_to_too_long
          | :vendor_details_too_long
          | :vat_too_large
          | :sale_amount_too_large
          | :date_in_future
          | :date_too_old

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          context: map()
        }

  @doc """
  Creates an error for nil item.

  ## Returns
    - Error struct with type `:nil_item`
  """
  @spec nil_item() :: t()
  def nil_item do
    %Invoice.Error{
      type: :nil_item,
      message: "Item cannot be nil",
      context: %{}
    }
  end

  @doc """
  Creates an error for item that is not an Item struct.

  ## Returns
    - Error struct with type `:invalid_item_type`
  """
  @spec invalid_item_type(any()) :: t()
  def invalid_item_type(value) do
    %Invoice.Error{
      type: :invalid_item_type,
      message: "Item must be an Item struct",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for item with invalid fields.

  ## Parameters
    - `problems` - List of tuples {field_atom, error_message_string}
      Example: [{:units, "must be positive integer (got 0)"}, {:amount, "must be positive integer (got 0)"}]

  ## Returns
    - Error struct with type `:invalid_item` and field-level details in context
  """
  @spec invalid_item(list({atom(), String.t()})) :: t()
  def invalid_item(problems) when is_list(problems) do
    problem_messages = Enum.map(problems, fn {field, msg} -> "#{field} #{msg}" end)

    %Invoice.Error{
      type: :invalid_item,
      message: "Item is invalid",
      context: %{problems: problem_messages}
    }
  end

  @doc """
  Creates an error for invalid date field.

  ## Returns
    - Error struct with type `:invalid_date`
  """
  @spec invalid_date(any()) :: t()
  def invalid_date(value) do
    %Invoice.Error{
      type: :invalid_date,
      message: "Invoice date must be a Date struct",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for invalid number field.

  ## Returns
    - Error struct with type `:invalid_number`
  """
  @spec invalid_number(any()) :: t()
  def invalid_number(value) do
    %Invoice.Error{
      type: :invalid_number,
      message: "Invoice number must be a string",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for invalid bill_to field.

  ## Returns
    - Error struct with type `:invalid_bill_to`
  """
  @spec invalid_bill_to(any()) :: t()
  def invalid_bill_to(value) do
    %Invoice.Error{
      type: :invalid_bill_to,
      message: "Bill to must be a string",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for invalid vendor_details field.

  ## Returns
    - Error struct with type `:invalid_vendor_details`
  """
  @spec invalid_vendor_details(any()) :: t()
  def invalid_vendor_details(value) do
    %Invoice.Error{
      type: :invalid_vendor_details,
      message: "Vendor details must be a string",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for invalid VAT field.

  ## Parameters
    - `value` - The invalid VAT value

  ## Returns
    - Error struct with type `:invalid_vat`
  """
  @spec invalid_vat(any()) :: t()
  def invalid_vat(value) do
    %Invoice.Error{
      type: :invalid_vat,
      message: "Invoice VAT must be non-negative integer",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for invalid sale_amount field.

  ## Parameters
    - `value` - The invalid sale amount value

  ## Returns
    - Error struct with type `:invalid_sale_amount`
  """
  @spec invalid_sale_amount(any()) :: t()
  def invalid_sale_amount(value) do
    %Invoice.Error{
      type: :invalid_sale_amount,
      message: "Invoice sale amount must be non-negative integer",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for items parameter that is not a list.

  ## Returns
    - Error struct with type `:invalid_items_list`
  """
  @spec invalid_items_list(any()) :: t()
  def invalid_items_list(value) do
    %Invoice.Error{
      type: :invalid_items_list,
      message: "Items must be a list",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for number that is too long.

  ## Parameters
    - `length` - The actual length
    - `max_length` - The maximum allowed length

  ## Returns
    - Error struct with type `:number_too_long`
  """
  @spec number_too_long(pos_integer(), pos_integer()) :: t()
  def number_too_long(length, max_length) do
    %Invoice.Error{
      type: :number_too_long,
      message: "Invoice number is too long",
      context: %{length: length, max_length: max_length}
    }
  end

  @doc """
  Creates an error for bill_to that is too long.

  ## Parameters
    - `length` - The actual length
    - `max_length` - The maximum allowed length

  ## Returns
    - Error struct with type `:bill_to_too_long`
  """
  @spec bill_to_too_long(pos_integer(), pos_integer()) :: t()
  def bill_to_too_long(length, max_length) do
    %Invoice.Error{
      type: :bill_to_too_long,
      message: "Bill to is too long",
      context: %{length: length, max_length: max_length}
    }
  end

  @doc """
  Creates an error for vendor_details that is too long.

  ## Parameters
    - `length` - The actual length
    - `max_length` - The maximum allowed length

  ## Returns
    - Error struct with type `:vendor_details_too_long`
  """
  @spec vendor_details_too_long(pos_integer(), pos_integer()) :: t()
  def vendor_details_too_long(length, max_length) do
    %Invoice.Error{
      type: :vendor_details_too_long,
      message: "Vendor details is too long",
      context: %{length: length, max_length: max_length}
    }
  end

  @doc """
  Creates an error for VAT that exceeds maximum value.

  ## Parameters
    - `value` - The actual VAT value
    - `max_value` - The maximum allowed value

  ## Returns
    - Error struct with type `:vat_too_large`
  """
  @spec vat_too_large(pos_integer(), pos_integer()) :: t()
  def vat_too_large(value, max_value) do
    %Invoice.Error{
      type: :vat_too_large,
      message: "Invoice VAT exceeds maximum allowed value",
      context: %{value: value, max_value: max_value}
    }
  end

  @doc """
  Creates an error for sale_amount that exceeds maximum value.

  ## Parameters
    - `value` - The actual sale amount value
    - `max_value` - The maximum allowed value

  ## Returns
    - Error struct with type `:sale_amount_too_large`
  """
  @spec sale_amount_too_large(pos_integer(), pos_integer()) :: t()
  def sale_amount_too_large(value, max_value) do
    %Invoice.Error{
      type: :sale_amount_too_large,
      message: "Invoice sale amount exceeds maximum allowed value",
      context: %{value: value, max_value: max_value}
    }
  end

  @doc """
  Creates an error for invoice date in the future.

  ## Parameters
    - `date` - The future date

  ## Returns
    - Error struct with type `:date_in_future`
  """
  @spec date_in_future(Date.t()) :: t()
  def date_in_future(date) do
    %Invoice.Error{
      type: :date_in_future,
      message: "Invoice date cannot be in the future",
      context: %{date: inspect(date)}
    }
  end

  @doc """
  Creates an error for invoice date that is too old.

  ## Parameters
    - `date` - The old date
    - `min_date` - The minimum allowed date

  ## Returns
    - Error struct with type `:date_too_old`
  """
  @spec date_too_old(Date.t(), Date.t()) :: t()
  def date_too_old(date, min_date) do
    %Invoice.Error{
      type: :date_too_old,
      message: "Invoice date is too old",
      context: %{date: inspect(date), min_date: inspect(min_date)}
    }
  end

  @doc """
  Combines the main message with context details for display.

  ## Parameters
    - `error` - Invoice.Error struct

  ## Returns
    - User-friendly error message as string

  ## Examples

      iex> error = Invoice.Error.invalid_item([{:units, "must be positive (got 0)"}])
      iex> Invoice.Error.to_user_message(error)
      "Item is invalid: units must be positive (got 0)"

      iex> error = Invoice.Error.invalid_vat(-10)
      iex> Invoice.Error.to_user_message(error)
      "Invoice VAT must be non-negative integer (received: -10)"
  """
  @spec to_user_message(t()) :: String.t()
  def to_user_message(%Invoice.Error{message: message, context: context}) do
    case context do
      %{problems: problems} when is_list(problems) ->
        # For item validation, list all field problems
        problem_str = Enum.join(problems, ", ")
        "#{message}: #{problem_str}"

      %{length: length, max_length: max_length} ->
        # For length validation
        "#{message} (length: #{length}, max: #{max_length})"

      %{value: value, max_value: max_value} ->
        # For boundary validation
        "#{message} (value: #{value}, max: #{max_value})"

      %{date: date, min_date: min_date} ->
        # For date range validation
        "#{message} (date: #{date}, min: #{min_date})"

      %{date: date} ->
        # For future date validation
        "#{message} (date: #{date})"

      %{received: received} ->
        # For type/range validation, show what was received
        "#{message} (received: #{received})"

      _ ->
        # Fallback to just the message
        message
    end
  end
end
