defmodule InvoiceCreation.Schemas.InvoiceRecord do
  @moduledoc """
  Ecto schema for storing invoices in the database.

  This schema mirrors the Invoice domain model with database-specific constraints
  and relationships. All validation rules from the Invoice domain model are enforced
  at the database level through constraints.

  ## Fields

  - `number`: Invoice number (string, max 20 chars)
  - `date`: Invoice date (must be today or in the past, max 10 years old)
  - `bill_to`: Billing customer information (optional, max 500 chars)
  - `vendor_details`: Vendor information (optional, max 500 chars)
  - `sale_amount`: Total sale amount in cents (non-negative, max 999,999,999)
  - `vat`: Value Added Tax in cents (non-negative, max 999,999)
  - `items`: Association to ItemRecord records (one-to-many)

  ## Database Constraints

  - `number`: NOT NULL, max 20 characters
  - `date`: NOT NULL, must be <= today, must be >= 10 years ago
  - `sale_amount`: NOT NULL, >= 0, <= 999,999,999
  - `vat`: NOT NULL, >= 0, <= 999,999
  """

  use Ecto.Schema
  import Ecto.Changeset

  @max_number_length 20
  @max_bill_to_length 500
  @max_vendor_details_length 500
  @max_vat 999_999
  @max_sale_amount 999_999_999
  @max_invoice_age_days 3650

  schema "invoices" do
    field(:number, :string)
    field(:date, :date)
    field(:bill_to, :string)
    field(:vendor_details, :string)
    field(:sale_amount, :integer, default: 0)
    field(:vat, :integer, default: 0)

    has_many(:items, InvoiceCreation.Schemas.ItemRecord,
      foreign_key: :invoice_id,
      on_delete: :delete_all
    )

    timestamps()
  end

  @doc """
  Creates a changeset for an invoice based on domain model constraints.

  This changeset enforces all validation rules from the Invoice domain model
  to ensure database integrity.
  """
  def changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [:number, :date, :bill_to, :vendor_details, :sale_amount, :vat])
    |> validate_required([:number, :date, :sale_amount, :vat])
    |> validate_length(:number, max: @max_number_length)
    |> validate_length(:bill_to, max: @max_bill_to_length)
    |> validate_length(:vendor_details, max: @max_vendor_details_length)
    |> validate_number(:sale_amount, greater_than_or_equal_to: 0)
    |> validate_number(:sale_amount, less_than_or_equal_to: @max_sale_amount)
    |> validate_number(:vat, greater_than_or_equal_to: 0)
    |> validate_number(:vat, less_than_or_equal_to: @max_vat)
    |> validate_invoice_date()
  end

  @doc """
  Creates a changeset for creating a new invoice from a domain Invoice struct.
  """
  def from_invoice(invoice) do
    attrs = %{
      number: invoice.number,
      date: invoice.date,
      bill_to: invoice.bill_to,
      vendor_details: invoice.vendor_details,
      sale_amount: invoice.sale_amount,
      vat: invoice.vat
    }

    %__MODULE__{}
    |> changeset(attrs)
  end

  # Private validation function for invoice date
  # Date must be today or in the past, and not more than 10 years old
  defp validate_invoice_date(changeset) do
    validate_change(changeset, :date, fn :date, date ->
      today = Date.utc_today()

      cond do
        Date.compare(date, today) == :gt ->
          [date: "cannot be in the future"]

        date_too_old?(date) ->
          min_date = Date.add(today, -@max_invoice_age_days)
          [date: "cannot be older than 10 years (minimum: #{min_date})"]

        true ->
          []
      end
    end)
  end

  defp date_too_old?(date) do
    min_date = Date.add(Date.utc_today(), -@max_invoice_age_days)
    Date.compare(date, min_date) == :lt
  end
end
