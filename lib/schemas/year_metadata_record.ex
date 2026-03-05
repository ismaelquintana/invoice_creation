defmodule InvoiceCreation.Schemas.YearMetadataRecord do
  @moduledoc """
  Ecto schema for storing year metadata in the database.

  Tracks information about invoices by year to support efficient queries
  and year-based organization of invoices.

  ## Fields

  - `year`: The year (positive integer, >= 1900, <= current year + 100)
  - `invoice_count`: Number of invoices in that year (non-negative integer)
  - `total_sale_amount`: Total sale amount for the year in cents (non-negative)
  - `total_vat`: Total VAT for the year in cents (non-negative)

  ## Database Constraints

  - `year`: NOT NULL, unique, >= 1900, <= current year + 100
  - `invoice_count`: NOT NULL, >= 0
  - `total_sale_amount`: NOT NULL, >= 0
  - `total_vat`: NOT NULL, >= 0
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "year_metadata" do
    field(:year, :integer)
    field(:invoice_count, :integer, default: 0)
    field(:total_sale_amount, :integer, default: 0)
    field(:total_vat, :integer, default: 0)

    timestamps()
  end

  @doc """
  Creates a changeset for year metadata.
  """
  def changeset(metadata, attrs) do
    current_year = Date.utc_today().year

    metadata
    |> cast(attrs, [:year, :invoice_count, :total_sale_amount, :total_vat])
    |> validate_required([:year, :invoice_count, :total_sale_amount, :total_vat])
    |> validate_number(:year, greater_than_or_equal_to: 1900)
    |> validate_number(:year, less_than_or_equal_to: current_year + 100)
    |> validate_number(:invoice_count, greater_than_or_equal_to: 0)
    |> validate_number(:total_sale_amount, greater_than_or_equal_to: 0)
    |> validate_number(:total_vat, greater_than_or_equal_to: 0)
    |> unique_constraint(:year)
  end

  @doc """
  Creates a changeset for creating year metadata from a year integer.
  """
  def new(year) do
    attrs = %{
      year: year,
      invoice_count: 0,
      total_sale_amount: 0,
      total_vat: 0
    }

    %__MODULE__{}
    |> changeset(attrs)
  end
end
