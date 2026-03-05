# Persistence Layer - Quick Start Guide

## Overview

This document provides a quick reference for implementing the persistence layer for the invoice_creation project. For comprehensive details, see `PERSISTENCE_LAYER_ANALYSIS.md`.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Format** | JSON | Human-readable, standard, excellent Elixir support |
| **Storage Location** | `priv/storage/` | Standard Elixir practice, release-safe |
| **Organization** | Year-based subdirs | Aligns with ListInvoiceYear structure |
| **Dependencies** | None (Jason optional) | Keep it simple, lean |
| **Error Type** | Structured errors | Consistent with existing code patterns |

## Directory Structure

```
lib/storage/
├── persistence.ex       # Main API (InvoiceStorage module)
├── encoder.ex          # JSON encoding
├── decoder.ex          # JSON decoding
└── errors.ex           # InvoiceStorage.Error module

test/storage/
├── persistence_test.exs
├── encoder_test.exs
└── decoder_test.exs

priv/storage/
└── invoices/           # Created at runtime
    └── 2024/
        ├── 2024-0001.json
        ├── 2024-0002.json
        └── ...
```

## Core API

### Single Invoice Operations

```elixir
# Save
:ok = InvoiceStorage.save(invoice)

# Load
{:ok, invoice} = InvoiceStorage.load("2024-0001")

# Delete
:ok = InvoiceStorage.delete("2024-0001")

# Check existence
exists? = InvoiceStorage.exists?("2024-0001")
```

### Batch Operations

```elixir
# Save multiple
:ok = InvoiceStorage.save_all([invoice1, invoice2, invoice3])

# Load all for a year
{:ok, invoices} = InvoiceStorage.load_all(2024)
```

### Year List Operations

```elixir
# Save year list
:ok = InvoiceStorage.save_year_list(year_list)

# Load year list
{:ok, year_list} = InvoiceStorage.load_year_list(2024)
```

### Utility Operations

```elixir
# List all years with invoices
{:ok, years} = InvoiceStorage.list_years()

# Count invoices in a year
{:ok, count} = InvoiceStorage.count(2024)
```

## Error Handling

```elixir
case InvoiceStorage.load("2024-0001") do
  {:ok, invoice} ->
    # Process invoice
  {:error, error} ->
    case error.type do
      :file_not_found -> "Invoice not found"
      :permission_denied -> "Access denied"
      :decode_failed -> "Data corrupted"
      :invalid_json -> "Invalid JSON"
      :invalid_invoice_data -> "Validation failed"
      :io_error -> "Unexpected IO error"
    end
end
```

## Configuration

```elixir
# config/config.exs

import Config

config :invoice_creation, :storage_root,
  Path.join([:code.priv_dir(:invoice_creation), "storage"])

# Override for tests
if config_env() == :test do
  config :invoice_creation, :storage_root,
    Path.join(System.tmp_dir!(), "invoice_test_storage")
end
```

## Integration Patterns

### Pattern 1: Repository Wrapper

```elixir
defmodule InvoiceRepository do
  def create(opts) do
    with {:ok, invoice} <- Invoice.new(opts),
         :ok <- InvoiceStorage.save(invoice) do
      {:ok, invoice}
    end
  end

  def get(number), do: InvoiceStorage.load(number)

  def update(number, updates) do
    with {:ok, invoice} <- InvoiceStorage.load(number),
         {:ok, updated} <- Invoice.update(invoice, updates),
         :ok <- InvoiceStorage.save(updated) do
      {:ok, updated}
    end
  end
end
```

### Pattern 2: Manual Save

```elixir
{:ok, invoice} = Invoice.new(bill_to: "Client")
{:ok, invoice} = Invoice.add_item(invoice, item)
:ok = InvoiceStorage.save(invoice)
```

### Pattern 3: With Error Handling

```elixir
case InvoiceStorage.save(invoice) do
  :ok -> 
    Logger.info("Saved invoice #{invoice.number}")
    {:ok, invoice}
  {:error, error} ->
    Logger.error("Failed to save: #{error.message}")
    {:error, error}
end
```

## Testing

### Setup

```elixir
setup [:setup_storage]

def setup_storage(_context) do
  temp_dir = System.tmp_dir!()
  storage_dir = Path.join(temp_dir, "invoice_test_#{System.unique_integer()}")
  File.mkdir_p!(storage_dir)
  
  on_exit(fn -> File.rm_rf(storage_dir) end)
  
  Application.put_env(:invoice_creation, :storage_root, storage_dir)
  {:ok, storage_dir: storage_dir}
end
```

### Example Test

```elixir
test "save and load invoice", %{storage_dir: _dir} do
  {:ok, item} = Item.new(description: "Service", units: 2, amount: 100)
  {:ok, invoice} = Invoice.new(bill_to: "Acme")
  {:ok, invoice} = Invoice.add_item(invoice, item)
  
  :ok = InvoiceStorage.save(invoice)
  {:ok, loaded} = InvoiceStorage.load(invoice.number)
  
  assert loaded.bill_to == invoice.bill_to
  assert loaded.sale_amount == invoice.sale_amount
end
```

## JSON Format Example

```json
{
  "date": "2024-03-15",
  "number": "2024-0001",
  "bill_to": "Acme Corp",
  "vendor_details": "123 Business St",
  "items": [
    {
      "description": "Consulting Service",
      "units": 10,
      "amount": 150
    }
  ],
  "sale_amount": 1500,
  "vat": 315
}
```

## Implementation Checklist

- [ ] Create `lib/storage/` directory
- [ ] Implement `InvoiceStorage` module (persistence.ex)
- [ ] Implement `InvoiceStorage.Encoder` (encoder.ex)
- [ ] Implement `InvoiceStorage.Decoder` (decoder.ex)
- [ ] Implement `InvoiceStorage.Error` (errors.ex)
- [ ] Add storage configuration to `config/config.exs`
- [ ] Create test helpers in `test/support/`
- [ ] Write comprehensive tests
- [ ] Update main `mix.exs` to ensure Jason is available (optional)
- [ ] Document in project README

## Dependencies

The persistence layer uses:
- **Elixir stdlib:** File, Path, Date, Application, Enum
- **Optional:** Jason (for JSON) - likely already in your project

Check if Jason is available:
```elixir
mix deps | grep jason
```

If not present, add to `mix.exs`:
```elixir
{:jason, "~> 1.4"}
```

## Production Considerations

1. **Disk Space:** Monitor available disk space before saving large batches
2. **Permissions:** Ensure application has read/write permissions to priv/ directory
3. **Backups:** Implement backup strategy for data directory
4. **Concurrency:** The implementation is safe for concurrent reads
5. **Data Integrity:** JSON format ensures data portability
6. **Migration:** Easy to migrate to other formats due to encoder/decoder separation

## Common Patterns

### Atomic Update

```elixir
def atomic_update(number, updates) do
  with {:ok, invoice} <- InvoiceStorage.load(number),
       {:ok, updated} <- Invoice.update(invoice, updates),
       :ok <- InvoiceStorage.save(updated) do
    {:ok, updated}
  else
    {:error, error} -> {:error, error}
  end
end
```

### Batch Process

```elixir
def process_year(year) do
  with {:ok, invoices} <- InvoiceStorage.load_all(year) do
    invoices
    |> Enum.filter(&should_process?/1)
    |> Enum.map(&process_invoice/1)
    |> InvoiceStorage.save_all()
  end
end
```

### Safe Load with Default

```elixir
def load_or_default(number, default \\ nil) do
  InvoiceStorage.load(number)
  |> case do
    {:ok, invoice} -> invoice
    {:error, _} -> default
  end
end
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| File not found | Invoice never saved | Check invoice.number format |
| Permission denied | Wrong directory permissions | Check priv/ directory permissions |
| Invalid JSON | Corrupted file | Delete file and re-save |
| Decode failed | Schema mismatch | Ensure Invoice/Item structures match |

## Next Steps

1. Read `PERSISTENCE_LAYER_ANALYSIS.md` for complete implementation details
2. Copy code examples from section 9.1 of the analysis
3. Adapt to your project structure
4. Write comprehensive tests
5. Test with various data sizes and scenarios
6. Document in project README

---

For detailed information on all aspects of the persistence layer, see the complete analysis document.
