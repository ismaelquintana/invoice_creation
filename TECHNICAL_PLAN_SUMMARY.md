# Technical Plan Summary - Quick Reference

**Full Document:** See `COMPREHENSIVE_TECHNICAL_PLAN.md` (72KB, 2895 lines)

---

## At a Glance

### What's Being Done
1. **Database Integration** - Add PostgreSQL/SQLite support
2. **CSV Support** - Import/export invoices in CSV format
3. **Format Abstraction** - Support multiple serialization formats
4. **Zero-Downtime Migration** - Gradual transition from file-based to database

### Key Numbers
- **Total Effort:** 104 hours (~2.6 weeks full-time, or 9 weeks part-time)
- **Phased Approach:** 9 weeks with clear milestones
- **No Breaking Changes:** Fully backward compatible
- **Test Coverage Target:** >90% of new code

---

## Part 1: DATABASE INTEGRATION

### Database Choice
- **Production:** PostgreSQL via Ecto + Postgrex
- **Development:** SQLite via Ecto + ecto_sqlite3
- **Reason:** Industry standard, excellent ORM, built-in migrations

### Adapter Pattern
The existing `InvoiceStorage.Adapter` behavior already supports:
- `save/1`, `load/2`, `delete/2`, `exists?/2`
- `save_all/1`, `load_all/1`
- `save_year_list/1`, `load_year_list/1`
- `list_years/0`, `count/1`

### New Ecto Schemas
- `InvoiceRecord` - Maps Invoice struct to database
- `ItemRecord` - Maps Item struct to database items table
- `YearRecord` - Tracks year metadata (next_id)

### Migration Strategy
**Phase 1 (Weeks 1-4):** Dual-Write
- Write to both file system and database
- Verify data consistency
- Test for 1-2 weeks

**Phase 2 (Weeks 4-8):** Switch Reads
- Read from database instead of files
- Keep file-based fallback
- Test for 2 weeks

**Phase 3 (Weeks 8-9):** Full Migration
- Remove file adapter (or keep as optional)
- Archive old files
- Go live

### Database Schema
**Tables:**
- `years` - year metadata (year, next_id)
- `invoices` - invoice data (invoice_number, date, bill_to, vendor_details, sale_amount, vat)
- `items` - line items with positions

**Indexes:** 
- (year, invoice_number) - composite primary lookup
- year - for year-based queries
- invoice_id - for item relationships

### Dependencies
```elixir
{:ecto, "~> 3.10"},
{:ecto_sql, "~> 3.10"},
{:postgrex, "~> 0.18"},
{:ecto_sqlite3, "~> 0.13", optional: true}
```

---

## Part 2: CSV EXPORT/IMPORT

### CSV Format (Recommended)
**Denormalized format with items inline:**
```
invoice_number,date,bill_to,vendor_details,sale_amount,vat,item_description,item_units,item_amount,item_position
2024-0001,2024-03-05,Acme Corp,,5000,1000,Consulting,10,500,1
2024-0001,2024-03-05,Acme Corp,,5000,1000,Support,5,1000,2
```

**Why:**
- Single file (no multiple CSVs)
- Excel-friendly
- Easy to understand
- Complete data representation

### CSV Library
**NimbleCSV** (recommended)
- Lightweight (~200 lines)
- No dependencies
- RFC 4180 compliant
- Stream-based parsing

Alternative: ElixirCSV (richer features, if needed later)

### Implementation
- `CsvEncoder` - Converts Invoice structs to CSV rows
- `CsvDecoder` - Parses CSV back to Invoice structs
- `CsvValidator` - Three-layer validation
  1. CSV structure (valid RFC 4180)
  2. Field parsing (strings to correct types)
  3. Domain validation (business rules)

### Validation Features
- Header validation
- Type coercion (strings → integers, dates)
- Special character handling (quotes, commas, multiline)
- Encoding detection (UTF-8 fallback)
- Duplicate detection
- Partial import support (skip errors, validate-only modes)

### Edge Cases Handled
- Commas in fields (quoted)
- Quotes in fields (escaped as "")
- Multiline fields
- Missing/empty values → nil
- Non-UTF-8 encodings
- Duplicate invoice numbers

---

## Part 3: FILE FORMAT ABSTRACTION

### Format Behavior
New behavior `InvoiceStorage.Format`:
- `encode_invoice/1` - Single invoice
- `encode_invoices/1` - Multiple invoices
- `encode_list_invoice_year/1` - Full year data
- `decode_invoice/1` - Parse to invoice
- `decode_invoices/1` - Parse to invoices list
- `decode_list_invoice_year/1` - Parse to year
- `file_extension/0` - e.g., "json", "csv"
- `mime_type/0` - e.g., "application/json"

### Format Implementations
- `JsonFormat` - Wraps existing Encoder/Decoder
- `CsvFormat` - New format support

### Format Discovery
```elixir
InvoiceStorage.Format.get_format("json")  # {:ok, InvoiceStorage.JsonFormat}
InvoiceStorage.Format.get_format("csv")   # {:ok, InvoiceStorage.CsvFormat}
InvoiceStorage.Format.list_formats()      # [JsonFormat, CsvFormat]
```

### High-Level API
```elixir
InvoiceCreation.Export.export_to_file(invoices, "invoices.csv", format: "csv")
InvoiceCreation.Export.export_to_string(invoices, format: "json")
InvoiceCreation.Import.import_from_file("data.csv")
InvoiceCreation.Import.import_from_string(csv_data, format: "csv")
```

### Backward Compatibility
- No changes to existing `InvoiceStorage` API
- File structure unchanged (same JSON files in same locations)
- All new APIs are additive (no removals)
- FileAdapter continues to work unchanged

---

## Implementation Timeline

### Phase 1: Database Foundation (Weeks 1-2)
- Add Ecto dependencies
- Create Ecto schemas
- Database migrations
- Testing infrastructure
**Deliverable:** Database structure ready

### Phase 2: Database Adapter (Weeks 3-4)
- Implement DatabaseAdapter
- DualWriteAdapter for safe rollout
- Migration script
**Deliverable:** Dual-write system working

### Phase 3: CSV Support (Weeks 5-6)
- CsvEncoder/CsvDecoder
- Validation framework
- Import/Export APIs
**Deliverable:** CSV import/export working

### Phase 4: Format Abstraction (Week 7)
- Format behavior definition
- JsonFormat wrapper
- CsvFormat implementation
- Format registry
**Deliverable:** Multi-format abstraction complete

### Phase 5: Validation & Polish (Week 8)
- Comprehensive error handling
- Documentation
- Performance optimization
**Deliverable:** Production-ready system

### Phase 6: Cleanup & Go-Live (Week 9)
- Switch from DualWrite to DatabaseAdapter
- Archive old files
- Release
**Deliverable:** Live on database

---

## Testing Strategy

### Unit Tests
- Database adapter tests (matching FileAdapter tests)
- CSV encoder/decoder tests
- Format behavior tests
- Validator tests

### Integration Tests
- Adapter compatibility (file vs database)
- Migration integrity
- Round-trip testing (export → import)

### End-to-End Tests
- Complete workflows (create → export → import)
- Production scenarios (large batches, concurrent ops)
- Failover scenarios (connection issues)

### Coverage Target
- >90% of new code
- Adapter compatibility matrix
- Performance benchmarks

---

## Risk Mitigation

### Risk 1: Data Loss During Migration
**Mitigation:** Keep file backups, verify row counts, validation queries

### Risk 2: Performance Degradation
**Mitigation:** Database indexing, connection pooling, benchmarking

### Risk 3: CSV Import Data Corruption
**Mitigation:** Comprehensive validation, rollback on error, dry-run mode

### Risk 4: Format Incompatibility
**Mitigation:** Round-trip tests, version-aware encoding

### Risk 5: Database Connection Issues
**Mitigation:** Connection pool tuning, retry logic, circuit breaker

---

## New Dependencies

```elixir
defp deps do
  [
    # Database
    {:ecto, "~> 3.10"},
    {:ecto_sql, "~> 3.10"},
    {:postgrex, "~> 0.18"},
    {:ecto_sqlite3, "~> 0.13", optional: true},
    
    # CSV
    {:nimble_csv, "~> 1.2"},
    
    # JSON (existing, make explicit)
    {:jason, "~> 1.4"},
    
    # Existing
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:faker, "~> 0.18.0", only: :test}
  ]
end
```

---

## Configuration Changes

### Development
```elixir
config :invoice_creation,
  storage_adapter: InvoiceStorage.FileAdapter,
  export_format: "json"

config :invoice_creation, InvoiceStorage.Repo,
  database: "priv/invoice_dev.db",
  echo: true
```

### Production
```elixir
config :invoice_creation,
  storage_adapter: InvoiceStorage.DatabaseAdapter

config :invoice_creation, InvoiceStorage.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "20")),
  ssl: true
```

---

## Key Decisions

### Why Ecto?
- Industry standard in Elixir
- Excellent migration system
- Transaction support
- Same API for PostgreSQL and SQLite
- Built-in validation patterns
- Telemetry/monitoring integration

### Why NimbleCSV?
- Lightweight (no bloat)
- No dependencies
- RFC 4180 compliant
- Stream support
- Sufficient for our use case

### Why Denormalized CSV Format?
- Single file (simplicity)
- Excel-friendly
- Complete data in one row (no multiple CSVs)
- Easy to understand

### Why Dual-Write First?
- Zero downtime migration
- Easy rollback
- Confidence in correctness
- Time to detect issues

---

## Success Criteria

1. All tests passing (>90% coverage)
2. Database adapter works identically to file adapter
3. CSV import/export works without data loss
4. Performance acceptable (benchmarks pass)
5. Zero data loss during migration
6. Production deployment successful
7. Full documentation in place

---

## Next Steps

1. **Review & Approve** this plan
2. **Set up environment** (Ecto, dependencies)
3. **Start Week 1** - Database foundation
4. **Track progress** against timeline
5. **Execute deployment** plan

---

## Questions?

See `COMPREHENSIVE_TECHNICAL_PLAN.md` for detailed sections on:
- Schema design (pages ~200-400)
- Connection pooling (pages ~500-700)
- CSV structure details (pages ~900-1200)
- Edge case handling (pages ~1300-1500)
- Testing approach (pages ~1700-2000)
- Risk mitigation (pages ~2100-2400)
- Deployment strategy (pages ~2500-2700)

---

**Document:** COMPREHENSIVE_TECHNICAL_PLAN.md (2895 lines, 72KB)  
**Created:** March 5, 2026  
**Status:** Ready for Implementation
