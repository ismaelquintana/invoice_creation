defmodule ListInvoiceYear do
  @moduledoc """
  Manages a collection of invoices organized by year.

  Each year has its own auto-incrementing invoice sequence. The next_id
  field ensures that invoice numbers are unique within a year.

  ## Examples

      iex> {:ok, list} = ListInvoiceYear.new(year: 2024)
      iex> list.year
      2024
      iex> list.next_id
      0
  """
  defstruct year: nil, next_id: 0, invoices: %{}

  @typedoc """
  Type that represents ListInvoiceYear struct
  """
  @type t :: %__MODULE__{
          year: pos_integer() | nil,
          next_id: non_neg_integer(),
          invoices: %{String.t() => Invoice.t()}
        }

  @doc """
  Creates a new ListInvoiceYear with validation.

  ## Parameters
    - `opts` - Keyword list with optional `:year` and `:next_id`

  ## Returns
    - `{:ok, ListInvoiceYear.t()}` - If all validations pass
    - `{:error, String.t()}` - If validation fails

  ## Examples

      iex> {:ok, list} = ListInvoiceYear.new(year: 2024)
      iex> list.year
      2024

      iex> ListInvoiceYear.new(year: 0)
      {:error, "year must be a positive integer"}

      iex> ListInvoiceYear.new(next_id: -1)
      {:error, "next_id must be non-negative"}
  """
  @spec new(keyword()) :: {:ok, ListInvoiceYear.t()} | {:error, ListInvoiceYear.Error.t()}
  def new(opts \\ []) do
    with :ok <- validate_list_invoice_year(opts) do
      {:ok, struct(__MODULE__, opts)}
    end
  end

  @doc """
  Adds an invoice to the collection.

  The invoice year must match the collection year. The invoice number is
  auto-generated with the format: YYYY-NNNN

  ## Parameters
    - `list_invoice_year` - The collection to add the invoice to
    - `invoice` - The invoice to add

  ## Returns
    - `{:ok, ListInvoiceYear.t()}` - If invoice was successfully added
    - `{:error, String.t()}` - If validation fails

  ## Examples

      iex> {:ok, list} = ListInvoiceYear.new(year: 2024)
      iex> {:ok, invoice} = Invoice.new(date: ~D[2024-01-01])
      iex> {:ok, updated} = ListInvoiceYear.add_invoice(list, invoice)
      iex> updated.next_id
      1
      iex> map_size(updated.invoices)
      1
  """
  @spec add_invoice(ListInvoiceYear.t(), Invoice.t()) ::
          {:ok, ListInvoiceYear.t()} | {:error, String.t()}
  def add_invoice(list_invoice_year, invoice) do
    with :ok <- validate_for_add_invoice(list_invoice_year, invoice) do
      # Increment next_id before generating the number (so first is 0001, not 0000)
      next_sequence = list_invoice_year.next_id + 1
      invoice_number = generate_invoice_number(list_invoice_year, next_sequence)
      invoice_with_number = %Invoice{invoice | number: invoice_number}

      {:ok,
       %ListInvoiceYear{
         list_invoice_year
         | next_id: next_sequence,
           invoices: Map.put(list_invoice_year.invoices, invoice_number, invoice_with_number)
       }}
    end
  end

  @spec validate_list_invoice_year(keyword()) :: :ok | {:error, ListInvoiceYear.Error.t()}
  defp validate_list_invoice_year(opts) do
    year = Keyword.get(opts, :year)
    next_id = Keyword.get(opts, :next_id)

    cond do
      year != nil and (not is_integer(year) or year <= 0) ->
        {:error, ListInvoiceYear.Error.invalid_year(year)}

      next_id != nil and (not is_integer(next_id) or next_id < 0) ->
        {:error, ListInvoiceYear.Error.invalid_next_id(next_id)}

      true ->
        :ok
    end
  end

  @spec validate_for_add_invoice(ListInvoiceYear.t(), Invoice.t()) ::
          :ok | {:error, ListInvoiceYear.Error.t()}
  defp validate_for_add_invoice(list_invoice_year, invoice) do
    cond do
      invoice == nil ->
        {:error, ListInvoiceYear.Error.nil_invoice()}

      not match?(%Invoice{}, invoice) ->
        {:error, ListInvoiceYear.Error.invalid_invoice_type(invoice)}

      list_invoice_year.year == nil ->
        {:error, ListInvoiceYear.Error.year_not_set()}

      list_invoice_year.year != invoice.date.year ->
        {:error, ListInvoiceYear.Error.year_mismatch(invoice.date.year, list_invoice_year.year)}

      true ->
        :ok
    end
  end

  @spec generate_invoice_number(ListInvoiceYear.t(), pos_integer()) :: String.t()
  defp generate_invoice_number(list_invoice_year, next_sequence) do
    sequence = format_sequence(next_sequence)
    "#{list_invoice_year.year}-#{sequence}"
  end

  @spec format_sequence(non_neg_integer()) :: String.t()
  defp format_sequence(id) do
    id
    |> Integer.to_string()
    |> String.pad_leading(4, "0")
  end
end
