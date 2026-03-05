# Persistence Layer - Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                             │
│                 (Invoice, Item, ListInvoiceYear)                │
└────────┬────────────────────────────────────────────────────────┘
         │
         │ Create/Update/Delete
         │
┌────────▼────────────────────────────────────────────────────────┐
│                 InvoiceRepository (Optional)                     │
│    Wrapper combining Invoice operations with Persistence         │
└────────┬────────────────────────────────────────────────────────┘
         │
         │ save/load/delete
         │
┌────────▼─────────────────┐         ┌──────────────────┐
│    InvoiceStorage        │         │  InvoiceStorage  │
│   (Main API Module)      │         │      .Error      │
│                          │         │                  │
│ - save/1                │         │ Error handling   │
│ - load/1                │         │ and reporting    │
│ - delete/1              │         │                  │
│ - save_all/1            │         └──────────────────┘
│ - load_all/1            │
│ - exists?/1             │
│ - list_years/0          │
│ - count/1               │
└────────┬────────────────┘
         │
    ┌────┴────┐
    │          │
┌───▼──────┐  ┌──────────┐
│ Encoder  │  │ Decoder  │
│          │  │          │
│JSON      │  │Parse JSON│
│encoding  │  │Validate  │
│Date ISO  │  │Construct │
│8601      │  │Rebuild   │
└───┬──────┘  └──────┬───┘
    │                │
    └────────┬───────┘
             │
        ┌────▼─────────────────────────────────────┐
        │        File System Operations            │
        │                                          │
        │  priv/storage/                          │
        │  ├── invoices/                          │
        │  │   ├── 2024/                          │
        │  │   │   ├── 2024-0001.json            │
        │  │   │   ├── 2024-0002.json            │
        │  │   │   └── ...                       │
        │  │   └── 2023/                         │
        │  │       └── ...                       │
        │  └── years/                            │
        │      ├── 2024.json                    │
        │      └── 2023.json                    │
        └────────────────────────────────────────┘
```

## Data Flow Diagram

### Save Flow

```
Invoice Struct
    │
    ├─ Validate (Invoice.new already validates)
    │
    ▼
InvoiceStorage.save/1
    │
    ├─ Encoder.encode_invoice/1
    │  │
    │  ├─ Convert Date to ISO8601 string
    │  └─ Convert to JSON
    │
    ▼
File.write/2
    │
    ├─ Create directories if needed
    ├─ Write JSON to file
    │
    ▼
:ok or {:error, reason}
```

### Load Flow

```
Invoice Number (String)
    │
    ▼
InvoiceStorage.load/1
    │
    ├─ File.read/1
    │  │
    │  ├─ Parse file path from number
    │  └─ Read JSON bytes
    │
    ▼
Decoder.decode_invoice/1
    │
    ├─ Jason.decode!/1
    │  └─ Parse JSON string
    │
    ├─ Parse Date from ISO8601 string
    │
    ├─ Parse Items list
    │
    ├─ Invoice.new/1 (Validation)
    │  │
    │  └─ Validates all fields
    │
    ▼
{:ok, Invoice.t()} or {:error, reason}
```

## Module Responsibilities

### InvoiceStorage

**Responsibilities:**
- High-level API for persistence operations
- Path management and file location
- Directory creation
- File I/O coordination
- Error translation

**Public Functions:**
```elixir
save/1                  # Save single invoice
load/1                  # Load single invoice
delete/1                # Delete invoice
exists?/1               # Check if invoice exists
save_all/1              # Save multiple invoices
load_all/1              # Load all invoices for year
save_year_list/1        # Save ListInvoiceYear
load_year_list/1        # Load ListInvoiceYear
list_years/0            # List years with invoices
count/1                 # Count invoices in year
```

### InvoiceStorage.Encoder

**Responsibilities:**
- Convert Invoice/Item structs to JSON
- Handle Date to ISO8601 serialization
- Error handling for encoding failures

**Public Functions:**
```elixir
encode_invoice/1            # Invoice -> JSON String
encode_list_invoice_year/1  # ListInvoiceYear -> JSON String
encode_item/1               # Item -> JSON String
```

### InvoiceStorage.Decoder

**Responsibilities:**
- Parse JSON to Invoice/Item structs
- Handle ISO8601 to Date deserialization
- Validation integration with Invoice.new/1
- Comprehensive error handling

**Public Functions:**
```elixir
decode_invoice/1            # JSON String -> Invoice
decode_list_invoice_year/1  # JSON String -> ListInvoiceYear
decode_item/1               # JSON String -> Item
```

### InvoiceStorage.Error

**Responsibilities:**
- Structured error representation
- Error categorization and context
- User-friendly error messages

**Error Types:**
```
:file_not_found           # Invoice file doesn't exist
:permission_denied        # Can't access file/directory
:disk_full                # No space to write
:invalid_path             # Invalid path construction
:encode_failed            # Encoding to JSON failed
:decode_failed            # Decoding from JSON failed
:invalid_json             # JSON syntax error
:invalid_invoice_data     # Validation failed after decode
:invalid_year             # Year validation failed
:io_error                 # Generic I/O error
:unknown_error            # Unexpected error
```

## State Transitions

### Invoice Lifecycle

```
┌────────────────┐
│  New Invoice   │
│  (In Memory)   │
└────────┬───────┘
         │
         │ InvoiceStorage.save()
         │
┌────────▼──────────────┐
│  Persisted Invoice    │
│  (JSON File)          │
└────────┬──────────────┘
         │
    ┌────┴────┬────────────────┐
    │          │                │
    │          │                │
InvoiceStorage. │          │
  load()        │          │
    │           │          │
    ▼           │          │
┌────────┐      │          │
│ Loaded │  InvoiceStorage.│  InvoiceStorage.
│Invoice │   delete()     │    update()
└────────┘                 │  (via reload)
                           │
                      ┌────▼─────────┐
                      │   Deleted    │
                      │ (File Removed)│
                      └──────────────┘
```

## Error Handling Strategy

### Error Recovery Hierarchy

```
Level 1: Structured Errors
├─ Error type categorization
├─ Contextual information
└─ User-friendly messages

Level 2: Error Pattern Matching
├─ Match on error.type
├─ Determine recovery strategy
└─ Log appropriately

Level 3: Retry Logic (Optional)
├─ Retry transient errors
├─ Exponential backoff
└─ Circuit breaker pattern

Level 4: Graceful Degradation
├─ Fallback to defaults
├─ Degrade functionality
└─ Notify user
```

### Error Classification

```
Recoverable Errors:
├─ :file_not_found        → Try again or create new
├─ :disk_full             → Free space and retry
└─ :io_error              → Retry with backoff

Non-Recoverable Errors:
├─ :invalid_json          → Corrupted file, manual intervention
├─ :invalid_invoice_data  → Schema mismatch, migration needed
├─ :permission_denied     → Fix permissions manually
└─ :invalid_path          → Code issue, fix and deploy
```

## Configuration Points

```
Application Configuration
│
├─ storage_root: Path
│  │
│  ├─ Default: priv/storage/
│  ├─ Test: System.tmp_dir/invoices_test/
│  └─ Custom: Application.get_env
│
└─ Optional: Future enhancements
   ├─ encryption: boolean
   ├─ compression: boolean
   ├─ backup_path: Path
   └─ retention_days: integer
```

## File Organization Logic

### Path Construction

```
invoice_number: "2024-0001"
    │
    ├─ Extract year: 2024
    │
    ├─ Build directory:
    │  storage_root/invoices/2024/
    │
    └─ Build path:
       storage_root/invoices/2024/2024-0001.json
```

### Year-Based Organization Benefits

```
Benefits:
├─ Aligned with ListInvoiceYear structure
├─ Easy to find invoices by year
├─ Simplifies archive/purge operations
├─ Natural directory hierarchy
├─ Good filesystem performance
└─ Simple backup strategies (per year)

Directory Size:
├─ ~50KB per year (100 invoices)
├─ ~500KB per year (1000 invoices)
├─ ~5MB per year (10,000 invoices)
└─ Scalable with additional sharding if needed
```

## Concurrency Model

```
Concurrent Operations (Safe):
├─ Multiple readers of same invoice
├─ Multiple readers of different invoices
├─ Multiple saves to different invoices
└─ List operations during reads

Serialized Operations (Single-threaded):
├─ Write to same invoice (last-write-wins)
└─ Directory operations

Recommended Pattern:
├─ Use GenServer for write serialization (if needed)
├─ Use ETS for caching (if needed)
└─ Use database for high-concurrency scenarios
```

## Integration Points

### With Invoice.new/1

```
Invoice.new(opts)
    │
    ├─ Validates input
    │
    ▼
{:ok, Invoice.t()} or {:error, Invoice.Error.t()}
    │
    └─ (Application decides to persist)
        │
        ▼
    InvoiceStorage.save(invoice)
        │
        └─ Store to filesystem
```

### With Invoice.update/1

```
InvoiceStorage.load(number)
    │
    ▼
{:ok, invoice}
    │
    ├─ Invoice.update(invoice, opts)
    │
    ▼
{:ok, updated_invoice}
    │
    ├─ InvoiceStorage.save(updated_invoice)
    │
    ▼
:ok
```

### With ListInvoiceYear

```
ListInvoiceYear.new(year: 2024)
    │
    ├─ Invoices map: %{}
    │
    ├─ Add invoices via ListInvoiceYear.add_invoice/2
    │
    ▼
InvoiceStorage.save_year_list(year_list)
    │
    └─ Persist to: storage_root/years/2024.json

Also save individual invoices:
    │
    ▼
InvoiceStorage.save_all([invoices...])
    │
    └─ Persist to: storage_root/invoices/2024/*.json
```

## Testing Architecture

```
Test Setup:
├─ Create temp storage directory
├─ Configure storage_root to temp
├─ Run tests with isolation
└─ Cleanup on exit

Test Patterns:
├─ Unit tests (encoder/decoder)
├─ Integration tests (full save/load)
├─ Error handling tests
├─ Edge case tests
└─ Concurrent access tests

Test Isolation:
├─ Each test gets unique storage dir
├─ No shared state between tests
├─ Cleanup via on_exit/1
└─ Can run tests in parallel
```

## Performance Characteristics

```
Operation           Complexity  Notes
────────────────────────────────────────────
save/1              O(n)        n = items in invoice
load/1              O(n)        n = items in invoice
delete/1            O(1)        Just remove file
exists?/1           O(1)        File.exists?
load_all/1          O(m*n)      m = invoices, n = items
list_years/0        O(k)        k = years with data
count/1             O(m*n)      m = invoices, n = items

Disk I/O:
├─ Sequential: Optimized
├─ Random: Native filesystem
└─ Batch: Minimize context switches
```

## Migration Path

```
Current State:
└─ Data in memory only

Step 1: Add Persistence Layer
├─ Save at application exit
└─ Load at startup

Step 2: Add Repository Pattern
├─ Wrap persistence operations
└─ Hide implementation details

Step 3: Add Caching
├─ Cache loaded invoices
└─ Lazy invalidation

Step 4: Add Database Backend
├─ Pluggable encoder/decoder
└─ Keep same API
```

## Future Enhancement Points

```
Encryption Layer:
└─ Wrap encoder/decoder for security

Compression Layer:
└─ Compress large batches

Versioning:
└─ Support multiple data formats

Streaming:
└─ Large batch operations

Search/Index:
└─ Fast invoice lookup

Cloud Storage:
└─ S3/GCS backend

Change Tracking:
└─ Audit log integration
```

---

This architecture provides:
- Clear separation of concerns
- Extensibility for future needs
- Robust error handling
- Production readiness
- Easy testing and maintenance
