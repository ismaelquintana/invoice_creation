defmodule InvoiceCreation.Repo.Migrations.CreateYearMetadata do
  use Ecto.Migration

  def change do
    create table(:year_metadata) do
      add(:year, :integer, null: false)
      add(:invoice_count, :integer, null: false, default: 0)
      add(:total_sale_amount, :integer, null: false, default: 0)
      add(:total_vat, :integer, null: false, default: 0)

      timestamps()
    end

    # Create unique index on year for efficient lookups
    create(unique_index(:year_metadata, [:year]))

    # Add constraints to enforce valid years and non-negative amounts
    create(
      constraint(:year_metadata, :year_valid,
        check: "year >= 1900 AND year <= extract(year from CURRENT_DATE) + 100"
      )
    )

    create(constraint(:year_metadata, :invoice_count_non_negative, check: "invoice_count >= 0"))

    create(
      constraint(:year_metadata, :total_sale_amount_non_negative, check: "total_sale_amount >= 0")
    )

    create(constraint(:year_metadata, :total_vat_non_negative, check: "total_vat >= 0"))
  end
end
