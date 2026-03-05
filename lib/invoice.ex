defmodule Invoice do
  @moduledoc """
  Represents an invoice with line items.

  An invoice tracks billing information, items, and financial totals.
  Dates and numbers are auto-generated but can be overridden.

  ## Validation Rules

  - `date`: Must be today or in the past (max 10 years old)
  - `number`: String, max 20 characters
  - `bill_to`: Optional string, max 500 characters
  - `vendor_details`: Optional string, max 500 characters
  - `vat`: Non-negative integer, max 999,999
  - `sale_amount`: Non-negative integer, max 999,999,999

  ## Examples

      iex> {:ok, invoice} = Invoice.new(bill_to: "Acme Corp")
      iex> invoice.bill_to
      "Acme Corp"
  """

  # Validation constraints
  @max_number_length 20
  @max_bill_to_length 500
  @max_vendor_details_length 500
  @max_vat 999_999
  @max_sale_amount 999_999_999
  # 10 years
  @max_invoice_age_days 3650
  defstruct date: Date.utc_today(),
            number: "#{Date.utc_today().year}-0001",
            bill_to: nil,
            vendor_details: nil,
            items: [],
            sale_amount: 0,
            vat: 0

  @typedoc """
  Type that represents Invoice struct
  """
  @type t :: %__MODULE__{
          date: Date.t(),
          number: String.t(),
          bill_to: String.t() | nil,
          vendor_details: String.t() | nil,
          items: [Item.t()],
          sale_amount: non_neg_integer(),
          vat: non_neg_integer()
        }

  @doc """
  Creates a new invoice with validation.

  ## Parameters
    - `opts` - Keyword list with optional `:date`, `:number`, `:bill_to`, `:vendor_details`, `:vat`

  ## Returns
    - `{:ok, Invoice.t()}` - If all validations pass
    - `{:error, String.t()}` - If validation fails

  ## Examples

      iex> {:ok, invoice} = Invoice.new()
      iex> invoice.items
      []

      iex> {:ok, invoice} = Invoice.new(bill_to: "Customer Inc.")
      iex> invoice.bill_to
      "Customer Inc."

      iex> Invoice.new(vat: -10)
      {:error, "vat must be non-negative"}
  """
  @spec new(keyword()) :: {:ok, Invoice.t()} | {:error, Invoice.Error.t()}
  def new(opts \\ []) do
    with :ok <- validate_invoice(opts) do
      {:ok, struct(__MODULE__, opts)}
    end
  end

  @doc """
  Updates an invoice with validation.

  ## Parameters
    - `invoice` - The invoice to update
    - `opts` - Keyword list with fields to update

  ## Returns
    - `{:ok, Invoice.t()}` - If all validations pass
    - `{:error, String.t()}` - If validation fails
  """
  @spec update(Invoice.t(), keyword()) :: {:ok, Invoice.t()} | {:error, Invoice.Error.t()}
  def update(invoice, opts) do
    with :ok <- validate_invoice(opts) do
      {:ok, struct(invoice, opts)}
    end
  end

  @doc """
  Adds an item to the invoice.

  ## Parameters
    - `invoice` - The invoice to add the item to
    - `item` - The item to add

  ## Returns
    - `{:ok, Invoice.t()}` - If item was successfully added
    - `{:error, String.t()}` - If validation fails

  ## Examples

      iex> {:ok, item} = Item.new(description: "Service", units: 2, amount: 100)
      iex> {:ok, invoice} = Invoice.new()
      iex> {:ok, updated} = Invoice.add_item(invoice, item)
      iex> length(updated.items)
      1
      iex> updated.sale_amount
      200
  """
  @spec add_item(Invoice.t(), Item.t()) :: {:ok, Invoice.t()} | {:error, Invoice.Error.t()}
  def add_item(invoice, item) do
    with :ok <- validate_item_for_invoice(item) do
      cost = calculate_item_cost(item)

      {:ok,
       %Invoice{
         invoice
         | items: [item | invoice.items],
           sale_amount: invoice.sale_amount + cost
       }}
    end
  end

  @doc """
  Adds multiple items to an invoice.

  ## Parameters
    - `invoice` - The invoice to add items to
    - `items` - List of items to add

  ## Returns
    - `{:ok, Invoice.t()}` - If all items were successfully added
    - `{:error, String.t()}` - If any validation fails

  ## Examples

      iex> {:ok, item1} = Item.new(description: "Service 1", units: 2, amount: 100)
      iex> {:ok, item2} = Item.new(description: "Service 2", units: 3, amount: 50)
      iex> {:ok, invoice} = Invoice.new()
      iex> {:ok, updated} = Invoice.add_list_items(invoice, [item1, item2])
      iex> length(updated.items)
      2
      iex> updated.sale_amount
      350
  """
  @spec add_list_items(Invoice.t(), [Item.t()]) ::
          {:ok, Invoice.t()} | {:error, Invoice.Error.t()}
  def add_list_items(invoice, items) when is_list(items) do
    Enum.reduce_while(items, {:ok, invoice}, fn item, {:ok, acc} ->
      case add_item(acc, item) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def add_list_items(_invoice, items) do
    {:error, Invoice.Error.invalid_items_list(items)}
  end

  @spec validate_invoice(keyword()) :: :ok | {:error, Invoice.Error.t()}
  defp validate_invoice(opts) do
    date = Keyword.get(opts, :date)
    number = Keyword.get(opts, :number)
    bill_to = Keyword.get(opts, :bill_to)
    vendor_details = Keyword.get(opts, :vendor_details)
    vat = Keyword.get(opts, :vat)
    sale_amount = Keyword.get(opts, :sale_amount)

    with :ok <- validate_date(date),
         :ok <- validate_number(number),
         :ok <- validate_bill_to(bill_to),
         :ok <- validate_vendor_details(vendor_details),
         :ok <- validate_vat(vat) do
      validate_sale_amount(sale_amount)
    end
  end

  @spec validate_date(any()) :: :ok | {:error, Invoice.Error.t()}
  defp validate_date(nil), do: :ok

  defp validate_date(date) when not is_struct(date, Date) do
    {:error, Invoice.Error.invalid_date(date)}
  end

  defp validate_date(date) do
    cond do
      Date.compare(date, Date.utc_today()) == :gt ->
        {:error, Invoice.Error.date_in_future(date)}

      date_too_old?(date) ->
        min_date = Date.add(Date.utc_today(), -@max_invoice_age_days)
        {:error, Invoice.Error.date_too_old(date, min_date)}

      true ->
        :ok
    end
  end

  @spec validate_number(any()) :: :ok | {:error, Invoice.Error.t()}
  defp validate_number(nil), do: :ok

  defp validate_number(number) when not is_binary(number) do
    {:error, Invoice.Error.invalid_number(number)}
  end

  defp validate_number(number) do
    if byte_size(number) > @max_number_length do
      {:error, Invoice.Error.number_too_long(byte_size(number), @max_number_length)}
    else
      :ok
    end
  end

  @spec validate_bill_to(any()) :: :ok | {:error, Invoice.Error.t()}
  defp validate_bill_to(nil), do: :ok

  defp validate_bill_to(bill_to) when not is_binary(bill_to) do
    {:error, Invoice.Error.invalid_bill_to(bill_to)}
  end

  defp validate_bill_to(bill_to) do
    if byte_size(bill_to) > @max_bill_to_length do
      {:error, Invoice.Error.bill_to_too_long(byte_size(bill_to), @max_bill_to_length)}
    else
      :ok
    end
  end

  @spec validate_vendor_details(any()) :: :ok | {:error, Invoice.Error.t()}
  defp validate_vendor_details(nil), do: :ok

  defp validate_vendor_details(vendor_details) when not is_binary(vendor_details) do
    {:error, Invoice.Error.invalid_vendor_details(vendor_details)}
  end

  defp validate_vendor_details(vendor_details) do
    if byte_size(vendor_details) > @max_vendor_details_length do
      {:error,
       Invoice.Error.vendor_details_too_long(
         byte_size(vendor_details),
         @max_vendor_details_length
       )}
    else
      :ok
    end
  end

  @spec validate_vat(any()) :: :ok | {:error, Invoice.Error.t()}
  defp validate_vat(nil), do: :ok

  defp validate_vat(vat) when not is_integer(vat) or vat < 0 do
    {:error, Invoice.Error.invalid_vat(vat)}
  end

  defp validate_vat(vat) do
    if vat > @max_vat do
      {:error, Invoice.Error.vat_too_large(vat, @max_vat)}
    else
      :ok
    end
  end

  @spec validate_sale_amount(any()) :: :ok | {:error, Invoice.Error.t()}
  defp validate_sale_amount(nil), do: :ok

  defp validate_sale_amount(sale_amount)
       when not is_integer(sale_amount) or sale_amount < 0 do
    {:error, Invoice.Error.invalid_sale_amount(sale_amount)}
  end

  defp validate_sale_amount(sale_amount) do
    if sale_amount > @max_sale_amount do
      {:error, Invoice.Error.sale_amount_too_large(sale_amount, @max_sale_amount)}
    else
      :ok
    end
  end

  @spec date_too_old?(Date.t()) :: boolean()
  defp date_too_old?(date) do
    min_date = Date.add(Date.utc_today(), -@max_invoice_age_days)
    Date.compare(date, min_date) == :lt
  end

  @spec validate_item_for_invoice(Item.t()) :: :ok | {:error, Invoice.Error.t()}
  defp validate_item_for_invoice(item) do
    case item do
      nil ->
        {:error, Invoice.Error.nil_item()}

      %Item{description: desc, units: units, amount: amount} ->
        # Collect all field problems
        problems = collect_item_problems(desc, units, amount)

        case problems do
          [] -> :ok
          _ -> {:error, Invoice.Error.invalid_item(problems)}
        end

      _ ->
        {:error, Invoice.Error.invalid_item_type(item)}
    end
  end

  @spec collect_item_problems(any(), any(), any()) :: list({atom(), String.t()})
  defp collect_item_problems(desc, units, amount) do
    []
    |> collect_description_problem(desc)
    |> collect_units_problem(units)
    |> collect_amount_problem(amount)
  end

  defp collect_description_problem(problems, desc) do
    cond do
      not is_binary(desc) ->
        problems ++ [{:description, "must be a string"}]

      byte_size(desc) == 0 ->
        problems ++ [{:description, "cannot be empty"}]

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

      true ->
        problems
    end
  end

  @spec calculate_item_cost(Item.t()) :: non_neg_integer()
  defp calculate_item_cost(%Item{amount: amount, units: units}) do
    amount * units
  end
end
