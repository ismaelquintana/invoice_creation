defmodule InvoiceCreation.Factory do
  @moduledoc """
  ExMachina factory for generating test data.

  This module provides convenient factory functions for creating test fixtures
  for invoices, items, and other domain objects.

  ## Usage

  Use the factory in your tests:

      defmodule MyTest do
        use InvoiceCreation.DataCase
        alias InvoiceCreation.Factory

        test "creates invoice" do
          invoice = Factory.build(:invoice)
          assert invoice.number =~ ~r/^\\d{4}-\\d{4}$/
        end

        test "creates invoice with items" do
          invoice = Factory.build(:invoice, items: [Factory.build(:item)])
          assert length(invoice.items) == 1
        end
      end

  ## Available Factories

  - `:invoice` - Creates an Invoice struct
  - `:item` - Creates an Item struct
  - `:list_invoice_year` - Creates a ListInvoiceYear struct
  """

  use ExMachina

  @doc """
  Builds an Invoice struct with sensible defaults.

  ## Options

    - `:number` - Invoice number (default: auto-generated from year)
    - `:date` - Invoice date (default: today)
    - `:bill_to` - Billing customer info (default: nil)
    - `:vendor_details` - Vendor info (default: nil)
    - `:items` - List of Item structs (default: empty list)
    - `:sale_amount` - Total sale amount (default: calculated from items)
    - `:vat` - VAT amount (default: 0)

  ## Examples

      iex> invoice = Factory.build(:invoice)
      iex> invoice.number =~ ~r/^\\d{4}-\\d{4}$/
      true

      iex> invoice = Factory.build(:invoice, bill_to: "Acme Corp")
      iex> invoice.bill_to
      "Acme Corp"
  """
  def invoice_factory do
    today = Date.utc_today()

    %Invoice{
      number: "#{today.year}-0001",
      date: today,
      bill_to: Faker.Company.name(),
      vendor_details: Faker.Company.name(),
      items: [],
      sale_amount: 0,
      vat: 0
    }
  end

  @doc """
  Builds an Item struct with sensible defaults.

  ## Options

    - `:description` - Item description (default: random service name)
    - `:units` - Number of units (default: 1)
    - `:amount` - Unit amount in cents (default: 10000)

  ## Examples

      iex> item = Factory.build(:item)
      iex> item.description
      # Some service description
  """
  def item_factory do
    %Item{
      description: Faker.Commerce.product_name(),
      units: Enum.random(1..100),
      amount: Enum.random(1000..100_000)
    }
  end

  @doc """
  Builds a ListInvoiceYear struct with sensible defaults.

  ## Options

    - `:year` - Year (default: current year)
    - `:invoices` - List of Invoice structs (default: empty list)
    - `:next_id` - Next invoice ID (default: 1)

  ## Examples

      iex> list = Factory.build(:list_invoice_year)
      iex> list.year == Date.utc_today().year
      true
  """
  def list_invoice_year_factory do
    %ListInvoiceYear{
      year: Date.utc_today().year,
      invoices: [],
      next_id: 1
    }
  end

  @doc """
  Builds an InvoiceRecord (Ecto schema) with sensible defaults.

  This creates database records suitable for testing the PostgreSQL adapter.
  """
  def invoice_record_factory do
    today = Date.utc_today()

    %InvoiceCreation.Schemas.InvoiceRecord{
      number: "#{today.year}-0001",
      date: today,
      bill_to: Faker.Company.name(),
      vendor_details: Faker.Company.name(),
      sale_amount: 0,
      vat: 0
    }
  end

  @doc """
  Builds an ItemRecord (Ecto schema) with sensible defaults.

  Requires an `invoice_id` to be provided as an option.
  """
  def item_record_factory do
    %InvoiceCreation.Schemas.ItemRecord{
      description: Faker.Commerce.product_name(),
      units: Enum.random(1..100),
      amount: Enum.random(1000..100_000),
      invoice_id: nil
    }
  end

  @doc """
  Builds a YearMetadataRecord (Ecto schema) with sensible defaults.
  """
  def year_metadata_record_factory do
    %InvoiceCreation.Schemas.YearMetadataRecord{
      year: Date.utc_today().year,
      invoice_count: 0,
      total_sale_amount: 0,
      total_vat: 0
    }
  end
end
