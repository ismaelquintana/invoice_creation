defmodule InvoiceCreation.Repo.Migrations.CreateInvoices do
  use Ecto.Migration

  def change do
    create table(:invoices) do
      add(:number, :string, null: false, size: 20)
      add(:date, :date, null: false)
      add(:bill_to, :string, size: 500)
      add(:vendor_details, :string, size: 500)
      add(:sale_amount, :integer, null: false, default: 0)
      add(:vat, :integer, null: false, default: 0)

      timestamps()
    end

    # Create indexes for common queries
    create(index(:invoices, [:date]))
    create(index(:invoices, [:number]))
    create(index(:invoices, [fragment("extract(year from date)")]))

    # Add constraints to enforce domain validation rules
    create(constraint(:invoices, :sale_amount_non_negative, check: "sale_amount >= 0"))

    create(constraint(:invoices, :sale_amount_max, check: "sale_amount <= 999999999"))

    create(constraint(:invoices, :vat_non_negative, check: "vat >= 0"))

    create(constraint(:invoices, :vat_max, check: "vat <= 999999"))

    create(constraint(:invoices, :date_not_future, check: "date <= CURRENT_DATE"))

    create(
      constraint(:invoices, :date_not_too_old,
        check: "date >= CURRENT_DATE - interval '3650 days'"
      )
    )
  end
end
