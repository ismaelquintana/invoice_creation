# Database Integration & CSV Export - Implementation Roadmap

## Overview
Implement PostgreSQL adapter with Ecto, comprehensive testing, and CSV export functionality over 3 phases.

## Phase 1: PostgreSQL Foundation & CSV Export (Weeks 1-4)

### Goals
- Production-ready PostgreSQL adapter
- Database schema and migrations
- Full test infrastructure
- CSV export functionality

### Tasks

#### 1.1 Dependencies & Configuration (Day 1)
- [ ] Add Ecto, Postgrex, and CSV libraries to `mix.exs`
- [ ] Create config files for dev/test/prod databases
- [ ] Set up Ecto repo configuration
- [ ] Create database setup scripts

#### 1.2 Database Schema & Migrations (Days 2-3)
- [ ] Design and create Ecto schemas for:
  - InvoiceRecord
  - ItemRecord
  - YearMetadataRecord
- [ ] Create migration files
- [ ] Add indexes for performance
- [ ] Add constraints for validation

#### 1.3 PostgreSQL Adapter Implementation (Days 4-5)
- [ ] Implement `PostgresAdapter` module
- [ ] Implement all 10 adapter callbacks
- [ ] Add proper error handling
- [ ] Document configuration

#### 1.4 Test Infrastructure (Days 6-7)
- [ ] Create `DataCase` test helper
- [ ] Set up test database
- [ ] Create factory for test data
- [ ] Add seed data for testing

#### 1.5 CSV Export Module (Days 8-9)
- [ ] Create `InvoiceStorage.Formats.CSV` module
- [ ] Implement `export_invoices_to_csv/2` (single year)
- [ ] Implement `export_all_invoices_to_csv/0` (all years)
- [ ] Handle items in CSV format
- [ ] Create comprehensive tests

#### 1.6 Integration & Testing (Days 10)
- [ ] Integration tests for all adapter functions
- [ ] Round-trip data integrity tests
- [ ] Performance benchmarks
- [ ] Documentation and examples

---

## Phase 2: SQLite & CSV Import (Weeks 5-8)

### Goals
- Lightweight SQLite adapter
- CSV import with validation
- Data migration utilities

### Tasks

#### 2.1 SQLite Adapter (Days 1-3)
- [ ] Implement `SqliteAdapter` module
- [ ] SQLite-specific schema handling
- [ ] Connection pooling for SQLite
- [ ] Integration tests

#### 2.2 CSV Import Module (Days 4-6)
- [ ] Create `InvoiceStorage.Formats.CSV.Decoder`
- [ ] Implement CSV parsing with validation
- [ ] Handle data type conversions
- [ ] Error reporting for invalid rows
- [ ] Comprehensive tests

#### 2.3 Format Abstraction Layer (Days 7-8)
- [ ] Create `InvoiceStorage.Format` behavior
- [ ] Implement CSV and JSON as formats
- [ ] Format registry and dispatcher
- [ ] Configuration-driven format selection

#### 2.4 Migration Tools (Days 9-10)
- [ ] JSON → PostgreSQL migrator
- [ ] PostgreSQL → CSV exporter
- [ ] Backup and restore utilities
- [ ] Migration verification tools

---

## Phase 3: Optimization & Polish (Weeks 9+)

### Goals
- Performance optimization
- Admin utilities
- Comprehensive documentation

### Tasks

#### 3.1 Performance (Days 1-2)
- [ ] Query optimization
- [ ] Batch operation optimization
- [ ] Connection pooling tuning
- [ ] Caching strategies

#### 3.2 Admin Tools (Days 3-4)
- [ ] Database status checker
- [ ] Data integrity verification
- [ ] Backup and restore commands
- [ ] Migration status tracker

#### 3.3 Documentation & Examples (Days 5-6)
- [ ] Database integration guide
- [ ] CSV format specifications
- [ ] Migration guide (JSON→DB)
- [ ] Performance tuning guide
- [ ] Troubleshooting guide

#### 3.4 Monitoring & Logging (Days 7+)
- [ ] Query logging and metrics
- [ ] Performance monitoring
- [ ] Error logging and alerts
- [ ] Audit trail for important operations

---

## Technology Stack

### Libraries to Add
```elixir
# Database
{:ecto, "~> 3.10"},
{:ecto_sql, "~> 3.10"},
{:postgrex, "~> 0.17"},

# CSV
{:csv, "~> 3.2"},

# Testing
{:ex_machina, "~> 2.7"},     # Factory library
```

### Architecture

```
lib/
├── storage/
│   ├── adapter.ex                          # Behavior (existing)
│   ├── file_adapter.ex                     # JSON file storage (existing)
│   ├── postgres_adapter.ex                 # NEW
│   ├── sqlite_adapter.ex                   # Phase 2
│   ├── persistence.ex                      # Dispatcher (modified)
│   └── formats/
│       ├── format.ex                       # Behavior (NEW)
│       ├── json/
│       │   ├── encoder.ex                  # (existing)
│       │   └── decoder.ex                  # (existing)
│       └── csv/
│           ├── encoder.ex                  # NEW
│           └── decoder.ex                  # Phase 2
│
├── database/                               # NEW
│   ├── repo.ex                             # Ecto repo
│   └── schemas/
│       ├── invoice.ex                      # NEW
│       ├── item.ex                         # NEW
│       └── year_metadata.ex                # NEW
│
├── database_migrations/                    # NEW
│   └── *.exs migration files
│
test/
├── storage/
│   ├── postgres_adapter_test.exs           # NEW
│   ├── csv_export_test.exs                 # NEW
│   └── ...
├── support/
│   ├── data_case.ex                        # NEW
│   └── factory.ex                          # NEW
└── ...

config/
├── config.exs                              # (modified)
├── dev.exs                                 # NEW
├── test.exs                                # NEW
└── prod.exs                                # NEW
```

---

## Configuration Examples

### Development (PostgreSQL)
```elixir
config :invoice_creation,
  storage_adapter: InvoiceStorage.PostgresAdapter,
  storage_config: [
    repo: InvoiceCreation.Repo
  ]

config :invoice_creation, InvoiceCreation.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  database: "invoice_creation_dev",
  stacktrace: true,
  show_sensitive_data_on_dev: true
```

### Testing (SQLite in-memory for speed, PostgreSQL for integration)
```elixir
config :invoice_creation, InvoiceCreation.Repo,
  database: ":memory:",
  pool: Ecto.Adapters.SQL.Sandbox
```

### Production (PostgreSQL with connection pooling)
```elixir
config :invoice_creation, InvoiceCreation.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  hostname: System.fetch_env!("DB_HOST"),
  database: System.fetch_env!("DB_NAME"),
  pool_size: 10,
  socket_options: [:inet6],
  ssl: true
```

---

## Database Schema (PostgreSQL)

### invoices table
```sql
CREATE TABLE invoices (
  id BIGSERIAL PRIMARY KEY,
  invoice_number VARCHAR(20) NOT NULL,
  year INTEGER NOT NULL,
  date DATE NOT NULL CHECK (date <= CURRENT_DATE),
  bill_to VARCHAR(500),
  vendor_details VARCHAR(500),
  sale_amount BIGINT NOT NULL CHECK (sale_amount >= 0) CHECK (sale_amount <= 999999999),
  vat BIGINT NOT NULL CHECK (vat >= 0) CHECK (vat <= 999999),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(invoice_number, year),
  INDEX idx_year (year),
  INDEX idx_date (date),
  FOREIGN KEY (year) REFERENCES year_metadata(year)
);
```

### items table
```sql
CREATE TABLE items (
  id BIGSERIAL PRIMARY KEY,
  invoice_id BIGINT NOT NULL,
  description VARCHAR(500) NOT NULL,
  units INTEGER NOT NULL CHECK (units > 0) CHECK (units <= 1000000),
  amount BIGINT NOT NULL CHECK (amount > 0) CHECK (amount <= 999999999),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
  INDEX idx_invoice_id (invoice_id)
);
```

### year_metadata table
```sql
CREATE TABLE year_metadata (
  year INTEGER PRIMARY KEY,
  next_id INTEGER NOT NULL DEFAULT 1 CHECK (next_id > 0),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## CSV Export Format

### invoices.csv (Phase 1)
```
invoice_number,date,bill_to,vendor_details,vat,sale_amount
2024-0001,2024-03-05,Acme Corp,123 Business St,42,1000
2024-0002,2024-03-10,TechCorp Inc,456 Tech Ave,100,5000
```

### items.csv (Phase 1 - optional separate export)
```
invoice_number,date,item_description,units,amount,total_cost
2024-0001,2024-03-05,Service A,2,100,200
2024-0001,2024-03-05,Service B,3,200,600
2024-0002,2024-03-10,Product X,5,500,2500
```

### Combined format (optional alternative)
All in one file with blank line separators between invoices

---

## Testing Strategy

### Unit Tests
- Individual adapter functions
- CSV encoder/decoder
- Data validation
- Error handling

### Integration Tests
- Full workflow: create → save → load → delete
- CSV export → CSV import round-trip
- Multiple years handling
- Concurrent operations

### Performance Tests
- Bulk insert/load (1000+ invoices)
- Query performance
- Memory usage

### Test Coverage Goal
- Minimum 90% code coverage
- All error paths tested
- All edge cases covered

---

## Success Criteria

### Phase 1
- ✅ PostgreSQL adapter passes all tests
- ✅ CSV export creates valid files
- ✅ Data round-trip integrity verified
- ✅ Configuration documented
- ✅ 90%+ test coverage

### Phase 2
- ✅ SQLite adapter implemented
- ✅ CSV import with validation
- ✅ Migration utilities working
- ✅ All formats abstracted
- ✅ Documentation complete

### Phase 3
- ✅ Performance benchmarks meeting targets
- ✅ Admin tools functional
- ✅ Comprehensive documentation
- ✅ Production-ready monitoring

---

## Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Ecto learning curve | Medium | Medium | Use well-documented examples, pair programming |
| Migration data loss | Low | High | Comprehensive backup before migration, dry-run |
| Performance issues | Medium | Medium | Early benchmarking, query optimization |
| SQLite limitations | Low | Low | Start with PostgreSQL, evaluate SQLite later |
| CSV format incompatibility | Low | Medium | Define spec early, test with external tools |

---

## Deliverables

### Phase 1
- PostgreSQL adapter module (500+ lines)
- Database schemas and migrations
- CSV export module (300+ lines)
- Test suite (800+ lines)
- Configuration guide
- 30+ passing tests

### Phase 2
- SQLite adapter module (400+ lines)
- CSV import module (500+ lines)
- Migration utilities (300+ lines)
- Test suite (600+ lines)
- Format abstraction (200+ lines)
- 25+ passing tests

### Phase 3
- Admin CLI tools
- Performance benchmarks and reports
- Comprehensive documentation (10,000+ words)
- Monitoring and logging
- Troubleshooting guides

---

## Timeline Summary

```
Phase 1: Oct (Weeks 1-4)   - PostgreSQL + CSV Export
Phase 2: Nov (Weeks 5-8)   - SQLite + CSV Import
Phase 3: Dec (Weeks 9+)    - Optimization & Polish

Total: 9-12 weeks for full implementation
Can deliver Phase 1 in 4 weeks for early production use
```

---

## Next Steps

1. **Immediate:** Set up dependencies and database configuration
2. **Week 1:** Complete schema design and migrations
3. **Week 2:** Implement PostgreSQL adapter
4. **Week 3:** Implement CSV export
5. **Week 4:** Comprehensive testing and documentation
6. **Review:** Evaluate Phase 1, plan Phase 2 refinements

Ready to begin Phase 1 implementation! 🚀
