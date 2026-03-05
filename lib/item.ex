defmodule Item do
  @moduledoc """
  Represents a line item in an invoice.

  All fields are required when creating an item. This struct ensures that items
  always have valid description, units, and amount values.

  ## Validation Rules

  - `description`: Required, non-empty string, max 500 characters
  - `units`: Positive integer, max 1,000,000
  - `amount`: Positive integer, max 999,999,999 (cents)

  ## Examples

      iex> {:ok, item} = Item.new(description: "Consulting", units: 10, amount: 100)
      iex> item.description
      "Consulting"

      iex> Item.new(description: "Invalid")
      {:error, %Item.Error{type: :invalid_item, ...}}
  """

  # Validation constraints
  @max_description_length 500
  @max_units 1_000_000
  @max_amount 999_999_999
  defstruct description: "", units: 0, amount: 0

  @type t :: %__MODULE__{
          description: String.t(),
          units: pos_integer(),
          amount: pos_integer()
        }

  @doc """
  Creates a new item with validation.

  ## Parameters
    - `opts` - Keyword list with `:description`, `:units`, and `:amount`

  ## Returns
    - `{:ok, Item.t()}` - If all validations pass
    - `{:error, String.t()}` - If validation fails

  ## Examples

      iex> Item.new(description: "Service", units: 5, amount: 150)
      {:ok, %Item{description: "Service", units: 5, amount: 150}}

      iex> Item.new(description: "", units: 5, amount: 150)
      {:error, "description cannot be empty"}

      iex> Item.new(description: "Service", units: 0, amount: 150)
      {:error, "units must be a positive integer"}

      iex> Item.new(description: "Service", units: 5, amount: -10)
      {:error, "amount must be a positive integer"}
  """
  @spec new(keyword()) :: {:ok, Item.t()} | {:error, Item.Error.t()}
  def new(opts \\ []) do
    with :ok <- validate_item(opts) do
      {:ok, struct(__MODULE__, opts)}
    end
  end

  @doc """
  Updates an item with validation.

  ## Parameters
    - `item` - The item to update
    - `opts` - Keyword list with fields to update

  ## Returns
    - `{:ok, Item.t()}` - If all validations pass
    - `{:error, String.t()}` - If validation fails
  """
  @spec update(Item.t(), keyword()) :: {:ok, Item.t()} | {:error, Item.Error.t()}
  def update(item, opts) do
    # Merge current item values with update options for validation
    merged_opts =
      item
      |> Map.from_struct()
      |> Map.merge(Map.new(opts))
      |> Enum.to_list()

    with :ok <- validate_item(merged_opts) do
      {:ok, struct(item, opts)}
    end
  end

  @spec validate_item(keyword()) :: :ok | {:error, Item.Error.t()}
  defp validate_item(opts) do
    description = Keyword.get(opts, :description, "")
    units = Keyword.get(opts, :units, 0)
    amount = Keyword.get(opts, :amount, 0)

    # Collect all field problems
    problems = collect_item_problems(description, units, amount)

    case problems do
      [] -> :ok
      _ -> {:error, Item.Error.invalid_item(problems)}
    end
  end

  @spec collect_item_problems(any(), any(), any()) :: list({atom(), String.t()})
  defp collect_item_problems(description, units, amount) do
    []
    |> collect_description_problem(description)
    |> collect_units_problem(units)
    |> collect_amount_problem(amount)
  end

  defp collect_description_problem(problems, description) do
    cond do
      not is_binary(description) ->
        problems ++ [{:description, "must be a string"}]

      byte_size(description) == 0 ->
        problems ++ [{:description, "cannot be empty"}]

      byte_size(description) > @max_description_length ->
        problems ++ [{:description, "cannot exceed #{@max_description_length} characters"}]

      true ->
        problems
    end
  end

  defp collect_units_problem(problems, units) do
    cond do
      not is_integer(units) ->
        problems ++ [{:units, "must be a positive integer"}]

      units <= 0 ->
        problems ++ [{:units, "must be positive integer (got #{units})"}]

      units > @max_units ->
        problems ++ [{:units, "cannot exceed #{@max_units} (got #{units})"}]

      true ->
        problems
    end
  end

  defp collect_amount_problem(problems, amount) do
    cond do
      not is_integer(amount) ->
        problems ++ [{:amount, "must be a positive integer"}]

      amount <= 0 ->
        problems ++ [{:amount, "must be positive integer (got #{amount})"}]

      amount > @max_amount ->
        problems ++ [{:amount, "cannot exceed #{@max_amount} (got #{amount})"}]

      true ->
        problems
    end
  end
end
