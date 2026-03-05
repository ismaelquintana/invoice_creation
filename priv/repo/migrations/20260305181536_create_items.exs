defmodule InvoiceCreation.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add(:description, :string, null: false, size: 500)
      add(:units, :integer, null: false)
      add(:amount, :integer, null: false)
      add(:invoice_id, references(:invoices, on_delete: :delete_all), null: false)

      timestamps()
    end

    # Create indexes for common queries
    create(index(:items, [:invoice_id]))

    # Add constraints to enforce domain validation rules
    create(constraint(:items, :units_positive, check: "units > 0"))

    create(constraint(:items, :units_max, check: "units <= 1000000"))

    create(constraint(:items, :amount_positive, check: "amount > 0"))

    create(constraint(:items, :amount_max, check: "amount <= 999999999"))

    create(constraint(:items, :description_not_empty, check: "length(description) > 0"))
  end
end
