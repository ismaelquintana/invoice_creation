defmodule Item.Error do
  @moduledoc """
  Structured error handling for item operations.

  This module defines error types and helpers for item validation and operations.
  Errors contain semantic type information and contextual details for debugging.

  ## Error Types

  - `:invalid_description` - Description is empty or not a string
  - `:invalid_units` - Units is not positive integer
  - `:invalid_amount` - Amount is not positive integer
  - `:invalid_item` - Item has multiple invalid fields

  ## Examples

      iex> error = Item.Error.invalid_description("")
      iex> error.type
      :invalid_description

      iex> error = Item.Error.invalid_item([{:units, "must be positive integer (got 0)"}])
      iex> error.type
      :invalid_item
      iex> Item.Error.to_user_message(error)
      "Item is invalid: units must be positive integer (got 0)"
  """

  defstruct type: nil, message: nil, context: nil

  @type error_type ::
          :invalid_description
          | :invalid_units
          | :invalid_amount
          | :invalid_item
          | :description_too_long
          | :units_too_large
          | :amount_too_large

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          context: map()
        }

  @doc """
  Creates an error for invalid description.

  ## Parameters
    - `value` - The invalid description value

  ## Returns
    - Error struct with type `:invalid_description`
  """
  @spec invalid_description(any()) :: t()
  def invalid_description(value) do
    message =
      if value == "" do
        "Item description cannot be empty"
      else
        "Item description must be a string"
      end

    %Item.Error{
      type: :invalid_description,
      message: message,
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for invalid units.

  ## Parameters
    - `value` - The invalid units value

  ## Returns
    - Error struct with type `:invalid_units`
  """
  @spec invalid_units(any()) :: t()
  def invalid_units(value) do
    %Item.Error{
      type: :invalid_units,
      message: "Item units must be a positive integer",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for invalid amount.

  ## Parameters
    - `value` - The invalid amount value

  ## Returns
    - Error struct with type `:invalid_amount`
  """
  @spec invalid_amount(any()) :: t()
  def invalid_amount(value) do
    %Item.Error{
      type: :invalid_amount,
      message: "Item amount must be a positive integer",
      context: %{received: inspect(value)}
    }
  end

  @doc """
  Creates an error for item with multiple invalid fields.

  ## Parameters
    - `problems` - List of tuples {field_atom, error_message_string}
      Example: [{:units, "must be positive integer (got 0)"}, {:amount, "must be positive integer (got 0)"}]

  ## Returns
    - Error struct with type `:invalid_item` and field-level details in context
  """
  @spec invalid_item(list({atom(), String.t()})) :: t()
  def invalid_item(problems) when is_list(problems) do
    problem_messages = Enum.map(problems, fn {field, msg} -> "#{field} #{msg}" end)

    %Item.Error{
      type: :invalid_item,
      message: "Item is invalid",
      context: %{problems: problem_messages}
    }
  end

  @doc """
  Creates an error for description that is too long.

  ## Parameters
    - `length` - The actual length of the description
    - `max_length` - The maximum allowed length

  ## Returns
    - Error struct with type `:description_too_long`
  """
  @spec description_too_long(pos_integer(), pos_integer()) :: t()
  def description_too_long(length, max_length) do
    %Item.Error{
      type: :description_too_long,
      message: "Item description is too long",
      context: %{length: length, max_length: max_length}
    }
  end

  @doc """
  Creates an error for units that exceed maximum value.

  ## Parameters
    - `value` - The actual units value
    - `max_value` - The maximum allowed value

  ## Returns
    - Error struct with type `:units_too_large`
  """
  @spec units_too_large(pos_integer(), pos_integer()) :: t()
  def units_too_large(value, max_value) do
    %Item.Error{
      type: :units_too_large,
      message: "Item units exceeds maximum allowed value",
      context: %{value: value, max_value: max_value}
    }
  end

  @doc """
  Creates an error for amount that exceeds maximum value.

  ## Parameters
    - `value` - The actual amount value
    - `max_value` - The maximum allowed value

  ## Returns
    - Error struct with type `:amount_too_large`
  """
  @spec amount_too_large(pos_integer(), pos_integer()) :: t()
  def amount_too_large(value, max_value) do
    %Item.Error{
      type: :amount_too_large,
      message: "Item amount exceeds maximum allowed value",
      context: %{value: value, max_value: max_value}
    }
  end

  @doc """
  Combines the main message with context details for display.

  ## Parameters
    - `error` - Item.Error struct

  ## Returns
    - User-friendly error message as string

  ## Examples

      iex> error = Item.Error.invalid_units(0)
      iex> Item.Error.to_user_message(error)
      "Item units must be a positive integer (received: 0)"

      iex> error = Item.Error.invalid_item([{:units, "must be positive (got 0)"}])
      iex> Item.Error.to_user_message(error)
      "Item is invalid: units must be positive (got 0)"
  """
  @spec to_user_message(t()) :: String.t()
  def to_user_message(%Item.Error{message: message, context: context}) do
    case context do
      %{problems: problems} when is_list(problems) ->
        # For multiple field validation, list all problems
        problem_str = Enum.join(problems, ", ")
        "#{message}: #{problem_str}"

      %{length: length, max_length: max_length} ->
        # For length validation
        "#{message} (length: #{length}, max: #{max_length})"

      %{value: value, max_value: max_value} ->
        # For boundary validation
        "#{message} (value: #{value}, max: #{max_value})"

      %{received: received} ->
        # For single field validation, show what was received
        "#{message} (received: #{received})"

      _ ->
        # Fallback to just the message
        message
    end
  end
end
