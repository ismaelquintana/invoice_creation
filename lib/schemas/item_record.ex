defmodule InvoiceCreation.Schemas.ItemRecord do
  @moduledoc """
  Ecto schema for storing invoice line items in the database.

  This schema mirrors the Item domain model with database-specific constraints
  and relationships. All validation rules from the Item domain model are enforced
  at the database level through constraints.

  ## Fields

  - `description`: Item description (string, max 500 chars)
  - `units`: Number of units (positive integer, max 1,000,000)
  - `amount`: Unit amount in cents (positive integer, max 999,999,999)
  - `invoice_id`: Foreign key reference to InvoiceRecord
  - `invoice`: Association to parent InvoiceRecord

  ## Database Constraints

  - `description`: NOT NULL, max 500 characters, non-empty
  - `units`: NOT NULL, > 0, <= 1,000,000
  - `amount`: NOT NULL, > 0, <= 999,999,999
  - `invoice_id`: NOT NULL, foreign key reference
  """

  use Ecto.Schema
  import Ecto.Changeset

  @max_description_length 500
  @max_units 1_000_000
  @max_amount 999_999_999

  schema "items" do
    field(:description, :string)
    field(:units, :integer)
    field(:amount, :integer)

    belongs_to(:invoice, InvoiceCreation.Schemas.InvoiceRecord)

    timestamps()
  end

  @doc """
  Creates a changeset for an item based on domain model constraints.

  This changeset enforces all validation rules from the Item domain model
  to ensure database integrity.
  """
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:description, :units, :amount, :invoice_id])
    |> validate_required([:description, :units, :amount, :invoice_id])
    |> validate_length(:description, min: 1, max: @max_description_length)
    |> validate_number(:units, greater_than: 0)
    |> validate_number(:units, less_than_or_equal_to: @max_units)
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:amount, less_than_or_equal_to: @max_amount)
    |> foreign_key_constraint(:invoice_id)
  end

  @doc """
  Creates a changeset for creating a new item from a domain Item struct.
  """
  def from_item(item, invoice_id) do
    attrs = %{
      description: item.description,
      units: item.units,
      amount: item.amount,
      invoice_id: invoice_id
    }

    %__MODULE__{}
    |> changeset(attrs)
  end
end
