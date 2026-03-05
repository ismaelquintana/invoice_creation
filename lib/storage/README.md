# Invoice Storage Module

Complete persistence layer for storing and retrieving invoices to/from disk.

## Quick Start

```elixir
# Save an invoice
{:ok, invoice} = Invoice.new(number: "2024-0001", ...)
:ok = InvoiceStorage.save(invoice)

# Load an invoice
{:ok, invoice} = InvoiceStorage.load("2024-0001", 2024)

# Load all invoices for a year
{:ok, invoices} = InvoiceStorage.load_all(2024)

# List years with invoices
{:ok, years} = InvoiceStorage.list_years()
```

## Modules

- **InvoiceStorage** - Main API (save, load, delete, exists, etc.)
- **InvoiceStorage.Encoder** - JSON serialization
- **InvoiceStorage.Decoder** - JSON deserialization with validation
- **InvoiceStorage.Error** - 10 structured error types

## Storage Location

Invoices are stored in `priv/storage/` organized by year:

```
priv/storage/
├── invoices/
│   ├── 2024/
│   │   ├── 2024-0001.json
│   │   ├── 2024-0002.json
│   │   └── ...
│   └── ...
└── years/
    ├── 2024.json
    └── ...
```

## Configuration

Default configuration works out of the box. Optional configuration in `config/config.exs`:

```elixir
config :invoice_creation, :storage_root,
  Path.join([:code.priv_dir(:invoice_creation), "storage"])
```

## API Functions

### InvoiceStorage

```elixir
# Single invoice operations
save(invoice)                  # Save invoice to disk
load(number, year)             # Load invoice from disk
delete(number, year)           # Delete invoice from disk
exists?(number, year)          # Check if invoice exists

# Bulk operations
save_all(list_invoice_year)    # Save all invoices in year
load_all(year)                 # Load all invoices for year

# Year management
save_year_list(list_year)      # Save year metadata
load_year_list(year)           # Load year metadata
list_years()                   # List all years
count(year)                    # Count invoices in year
```

### InvoiceStorage.Encoder

```elixir
encode_invoice(invoice)              # Encode to map
encode_item(item)                    # Encode to map
encode_list_invoice_year(list_year)  # Encode to map
```

### InvoiceStorage.Decoder

```elixir
decode_invoice(map)              # Decode and validate
decode_item(map)                 # Decode and validate
decode_list_invoice_year(map)    # Decode and validate
decode_date(iso8601_string)      # Parse ISO 8601 date
```

## Error Handling

All functions return `{:ok, result}` or `{:error, exception}`:

```elixir
case InvoiceStorage.load("2024-0001", 2024) do
  {:ok, invoice} -> 
    {:ok, invoice}
  {:error, %InvoiceStorage.Error.FileNotFound{}} -> 
    {:error, "Invoice not found"}
  {:error, error} -> 
    {:error, InvoiceStorage.Error.format_error({:error, error})}
end
```

## Error Types

- `FileNotFound` - Invoice file not found
- `PermissionDenied` - Access denied
- `DiskFull` - Out of disk space
- `InvalidPath` - Invalid file path
- `EncodeFailed` - JSON encoding failed
- `DecodeFailed` - JSON decoding failed
- `InvalidJson` - Malformed JSON
- `InvalidInvoiceData` - Validation failed
- `InvalidYear` - Invalid year parameter
- `IoError` - I/O operation error

## Testing

Run all storage tests:

```bash
mix test test/storage/
```

Run specific test suite:

```bash
mix test test/storage/persistence_test.exs
mix test test/storage/encoder_test.exs
mix test test/storage/decoder_test.exs
```

## Data Integrity

All data survives a complete serialize/deserialize cycle:

```elixir
original_invoice
→ InvoiceStorage.Encoder.encode_invoice/1
→ Jason.encode!/1
→ Jason.decode!/1
→ InvoiceStorage.Decoder.decode_invoice/1
= equivalent invoice
```

## Dependencies

- **Jason** - JSON encoding/decoding (already in project)
- **Elixir 1.12+** - Standard library

## See Also

- [PERSISTENCE_IMPLEMENTATION.md](../../PERSISTENCE_IMPLEMENTATION.md) - Complete guide
- [PERSISTENCE_QUICK_START.md](../../PERSISTENCE_QUICK_START.md) - Quick reference
