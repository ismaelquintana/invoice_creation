# COMPREHENSIVE TECHNICAL PLAN: DATABASE INTEGRATION & CSV SUPPORT
## Invoice Creation System - Database & Multi-Format Enhancement

**Document Version:** 1.0
**Date Created:** March 5, 2026
**Status:** Ready for Implementation

---

## EXECUTIVE SUMMARY

This plan provides a comprehensive roadmap for integrating database support (PostgreSQL and SQLite) and adding CSV import/export capabilities to the invoice_creation system. The system currently uses a file-based JSON storage with an adapter pattern, providing an excellent foundation for these extensions.

**Key Achievements Upon Completion:**
- Seamless database integration without breaking existing file-based API
- Support for both PostgreSQL (production) and SQLite (development/small deployments)
- CSV import/export with robust data validation
- Multi-format abstraction layer
- Zero migration downtime path
- Backward compatibility with existing file-based storage

---

## PART 1: DATABASE INTEGRATION

### 1.1 CURRENT ADAPTER PATTERN ANALYSIS

**Current Architecture:**
- Location: `lib/storage/adapter.ex` (286 lines)
- Implements behavior pattern (Elixir's protocol-like interface)
- Current implementation: `InvoiceStorage` (file-based, 436 lines)
- Template provided: `InvoiceStorage.DatabaseAdapterTemplate` (189 lines)

**Adapter Contract (10 required callbacks):**

```elixir
# Single operations
@callback save(invoice :: Invoice.t()) :: :ok | {:error, any()}
@callback load(invoice_number :: String.t(), year :: pos_integer()) 
  :: {:ok, Invoice.t()} | {:error, any()}
@callback exists?(invoice_number :: String.t(), year :: pos_integer()) :: boolean()
@callback delete(invoice_number :: String.t(), year :: pos_integer()) 
  :: :ok | {:error, any()}

# Bulk operations
@callback save_all(list_year :: ListInvoiceYear.t()) 
  :: :ok | {:error, any()}
@callback load_all(year :: pos_integer()) 
  :: {:ok, map()} | {:error, any()}

# Metadata
@callback save_year_list(list_year :: ListInvoiceYear.t()) 
  :: :ok | {:error, any()}
@callback load_year_list(year :: pos_integer()) 
  :: {:ok, ListInvoiceYear.t()} | {:error, any()}

# Discovery
@callback list_years() :: {:ok, [pos_integer()]} | {:error, any()}
@callback count(year :: pos_integer()) 
  :: {:ok, non_neg_integer()} | {:error, any()}
```

**Strengths of Current Pattern:**
- Clean separation of concerns
- Well-documented contract with guarantees (atomicity, idempotency, consistency)
- Error handling pattern is consistent
- Configuration-driven adapter selection
- No business logic in storage layer

**Limitations to Address:**
- No transaction support for complex operations
- No bulk operations optimization (need batching)
- No query/search capabilities
- No metadata queries (e.g., find by date range)

---

### 1.2 DATABASE LIBRARY OPTIONS FOR ELIXIR

#### Option 1: **Ecto + Postgrex (RECOMMENDED)**

**Pros:**
- Industry standard in Elixir (used by Phoenix, most Elixir projects)
- Excellent query builder with type safety
- Built-in migrations system
- Transaction support
- Connection pooling (via :db_connection)
- Rich ecosystem (ecto_sql, ecto_enum, etc.)
- Schema validation matches Invoice domain model
- Telemetry integration for monitoring
- Date/time handling is excellent

**Cons:**
- Heavier framework (but can be used standalone)
- Requires migrations setup
- Learning curve for newcomers

**Implementation:** `Ecto` (ORM) + `Postgrex` (PostgreSQL driver)

**Version Recommendation:**
```elixir
{:ecto, "~> 3.10"},      # Core ORM
{:ecto_sql, "~> 3.10"},  # SQL extensions
{:postgrex, "~> 0.18"}   # PostgreSQL driver
```

#### Option 2: **Raw Postgrex + Manual Mapping**

**Pros:**
- Minimal dependencies
- Full control over queries
- Better performance for simple operations
- Smaller learning curve

**Cons:**
- No built-in validation framework
- Manual query construction prone to errors
- No migrations
- Must handle connection pooling manually

**Not Recommended** - trade-off isn't worth it

#### Option 3: **SQLite + Ecto**

**Pros:**
- Perfect for development/testing
- File-based like current system
- No server to run
- Great for small deployments
- Same Ecto API as PostgreSQL

**Cons:**
- Limited concurrency
- No good connection pooling
- Not suitable for production

**Use Case:** Development, testing, optional fallback

**Version Recommendation:**
```elixir
{:ecto_sqlite3, "~> 0.13"}  # SQLite adapter for Ecto
```

#### Option 4: **Hybrid Approach (BEST FOR THIS PROJECT)**

Use Ecto with adapter flexibility:
- **Production:** Postgrex (PostgreSQL)
- **Development:** ecto_sqlite3 (SQLite) OR File adapter
- **Testing:** In-memory (optional, not recommended for invoice data)

---

### 1.3 SCHEMA DESIGN FOR BOTH DATABASES

#### Database-Agnostic Design Principles

The schema must support:
1. All fields from Invoice and Item structs
2. Year-based organization (matching current file structure)
3. Fast lookups by (invoice_number, year)
4. Metadata management (next_id per year)
5. Relationship preservation (items belong to invoices)

#### PostgreSQL Schema

**File: `priv/repo/migrations/TIMESTAMP_create_invoices_tables.exs`**

```sql
-- Years table (metadata)
CREATE TABLE years (
  year INT PRIMARY KEY NOT NULL,
  next_id INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Invoices table
CREATE TABLE invoices (
  id BIGSERIAL PRIMARY KEY,
  year INT NOT NULL REFERENCES years(year),
  invoice_number VARCHAR(20) NOT NULL,
  
  -- Core fields
  date DATE NOT NULL,
  bill_to TEXT,
  vendor_details TEXT,
  sale_amount INT NOT NULL DEFAULT 0,
  vat INT NOT NULL DEFAULT 0,
  
  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT invoice_number_year UNIQUE (year, invoice_number),
  CONSTRAINT valid_sale_amount CHECK (sale_amount >= 0),
  CONSTRAINT valid_vat CHECK (vat >= 0),
  CONSTRAINT valid_date CHECK (date <= CURRENT_DATE)
);

-- Items table
CREATE TABLE items (
  id BIGSERIAL PRIMARY KEY,
  invoice_id BIGINT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  
  -- Item fields
  description TEXT NOT NULL,
  units INT NOT NULL,
  amount INT NOT NULL,
  
  -- Position/order in invoice
  position INT NOT NULL,
  
  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT valid_units CHECK (units > 0),
  CONSTRAINT valid_amount CHECK (amount > 0)
);

-- Indexes for common queries
CREATE INDEX idx_invoices_year ON invoices(year);
CREATE INDEX idx_invoices_year_number ON invoices(year, invoice_number);
CREATE INDEX idx_invoices_date ON invoices(date);
CREATE INDEX idx_items_invoice_id ON items(invoice_id);
```

**Field Mappings:**

| Invoice Field | DB Column | Type | Notes |
|---|---|---|---|
| `date` | `invoices.date` | DATE | ISO 8601 compatible |
| `number` | `invoices.invoice_number` | VARCHAR(20) | Format: "YYYY-NNNN" |
| `bill_to` | `invoices.bill_to` | TEXT | Optional, max 500 chars |
| `vendor_details` | `invoices.vendor_details` | TEXT | Optional, max 500 chars |
| `sale_amount` | `invoices.sale_amount` | INT | Cents, non-negative |
| `vat` | `invoices.vat` | INT | Cents, non-negative |
| `items` | items table | — | One-to-many relationship |

#### SQLite Schema

**File: `priv/repo/migrations/TIMESTAMP_create_invoices_tables.exs` (SQLite variant)**

```sql
-- Years table (metadata)
CREATE TABLE years (
  year INTEGER PRIMARY KEY,
  next_id INTEGER NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Invoices table
CREATE TABLE invoices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  year INTEGER NOT NULL REFERENCES years(year),
  invoice_number TEXT NOT NULL,
  
  -- Core fields
  date TEXT NOT NULL,  -- ISO 8601 format
  bill_to TEXT,
  vendor_details TEXT,
  sale_amount INTEGER NOT NULL DEFAULT 0,
  vat INTEGER NOT NULL DEFAULT 0,
  
  -- Timestamps
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  UNIQUE(year, invoice_number),
  CHECK(sale_amount >= 0),
  CHECK(vat >= 0),
  CHECK(date <= DATE('now'))
);

-- Items table
CREATE TABLE items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  
  -- Item fields
  description TEXT NOT NULL,
  units INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  position INTEGER NOT NULL,
  
  -- Timestamps
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CHECK(units > 0),
  CHECK(amount > 0)
);

-- Indexes
CREATE INDEX idx_invoices_year ON invoices(year);
CREATE INDEX idx_invoices_year_number ON invoices(year, invoice_number);
CREATE INDEX idx_invoices_date ON invoices(date);
CREATE INDEX idx_items_invoice_id ON items(invoice_id);
```

**Key Differences from PostgreSQL:**
- Use DATETIME instead of TIMESTAMP
- INTEGER PRIMARY KEY for auto-increment
- TEXT for ISO 8601 dates (SQLite type affinity)
- Use `DATE('now')` instead of `CURRENT_DATE`

#### Ecto Schema Definitions

**File: `lib/storage/invoice_record.ex`**

```elixir
defmodule InvoiceStorage.InvoiceRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "invoices" do
    field :year, :integer
    field :invoice_number, :string
    field :date, :date
    field :bill_to, :string
    field :vendor_details, :string
    field :sale_amount, :integer, default: 0
    field :vat, :integer, default: 0
    
    has_many :items, InvoiceStorage.ItemRecord
    belongs_to :year_record, InvoiceStorage.YearRecord,
      foreign_key: :year,
      references: :year,
      type: :integer,
      define_field: false
    
    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :year, :invoice_number, :date, :bill_to, 
      :vendor_details, :sale_amount, :vat
    ])
    |> validate_required([
      :year, :invoice_number, :date, 
      :sale_amount, :vat
    ])
    |> validate_number(:sale_amount, greater_than_or_equal_to: 0)
    |> validate_number(:vat, greater_than_or_equal_to: 0)
    |> validate_length(:invoice_number, max: 20)
    |> validate_length(:bill_to, max: 500)
    |> validate_length(:vendor_details, max: 500)
    |> unique_constraint([:year, :invoice_number])
  end

  def from_invoice(%Invoice{} = invoice) do
    %__MODULE__{
      year: invoice.date.year,
      invoice_number: invoice.number,
      date: invoice.date,
      bill_to: invoice.bill_to,
      vendor_details: invoice.vendor_details,
      sale_amount: invoice.sale_amount,
      vat: invoice.vat,
      items: Enum.map(invoice.items, &InvoiceStorage.ItemRecord.from_item/1)
    }
  end

  def to_invoice(%__MODULE__{} = record) do
    {:ok,
     %Invoice{
       date: record.date,
       number: record.invoice_number,
       bill_to: record.bill_to,
       vendor_details: record.vendor_details,
       items: Enum.map(record.items, &InvoiceStorage.ItemRecord.to_item/1),
       sale_amount: record.sale_amount,
       vat: record.vat
     }}
  end
end
```

**File: `lib/storage/item_record.ex`**

```elixir
defmodule InvoiceStorage.ItemRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "items" do
    field :description, :string
    field :units, :integer
    field :amount, :integer
    field :position, :integer
    
    belongs_to :invoice, InvoiceStorage.InvoiceRecord
    
    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:description, :units, :amount, :position])
    |> validate_required([:description, :units, :amount, :position])
    |> validate_number(:units, greater_than: 0)
    |> validate_number(:amount, greater_than: 0)
    |> validate_length(:description, min: 1, max: 500)
  end

  def from_item(%Item{} = item, position \\ 0) do
    %__MODULE__{
      description: item.description,
      units: item.units,
      amount: item.amount,
      position: position
    }
  end

  def to_item(%__MODULE__{} = record) do
    {:ok,
     %Item{
       description: record.description,
       units: record.units,
       amount: record.amount
     }}
  end
end
```

**File: `lib/storage/year_record.ex`**

```elixir
defmodule InvoiceStorage.YearRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:year, :integer, autogenerate: false}
  schema "years" do
    field :next_id, :integer, default: 0
    has_many :invoices, InvoiceStorage.InvoiceRecord,
      foreign_key: :year,
      references: :year

    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:year, :next_id])
    |> validate_required([:year, :next_id])
    |> validate_number(:next_id, greater_than_or_equal_to: 0)
  end

  def from_list_invoice_year(%ListInvoiceYear{} = list) do
    %__MODULE__{
      year: list.year,
      next_id: list.next_id
    }
  end

  def to_list_invoice_year(%__MODULE__{} = record) do
    %ListInvoiceYear{
      year: record.year,
      next_id: record.next_id,
      invoices: %{}
    }
  end
end
```

---

### 1.4 MIGRATION STRATEGY

#### Phase 1: Dual-Write Period (0-2 weeks)

**Objective:** Ensure consistency between file and database systems

```
┌──────────────────────────────────────┐
│  Application Layer                   │
│  (Invoice, ListInvoiceYear)          │
└──────────────┬───────────────────────┘
               │
        ┌──────┴──────┐
        │             │
        v             v
    File System   Database
   (existing)     (new)
```

**Implementation Approach:**

1. **Add Ecto to dependencies** (no behavioral changes yet)
2. **Create database schemas** (Ecto definitions)
3. **Create migrations** (but don't run in production)
4. **Implement DatabaseAdapter** (implements `InvoiceStorage.Adapter`)
5. **Add "dual-write" middleware:**

```elixir
defmodule InvoiceStorage.DualWriteAdapter do
  @behaviour InvoiceStorage.Adapter
  
  def save(invoice) do
    with :ok <- primary_adapter().save(invoice),
         :ok <- secondary_adapter().save(invoice) do
      :ok
    else
      {:error, reason} ->
        # Log secondary write failure but continue
        Logger.warning("Dual write failed: #{inspect(reason)}")
        :ok
    end
  end
  
  # ... implement all callbacks
  
  defp primary_adapter, do: Application.get_env(:invoice_creation, :primary_adapter)
  defp secondary_adapter, do: Application.get_env(:invoice_creation, :secondary_adapter)
end
```

**Configuration During Phase 1:**
```elixir
config :invoice_creation,
  storage_adapter: InvoiceStorage.DualWriteAdapter,
  primary_adapter: InvoiceStorage.FileAdapter,
  secondary_adapter: InvoiceStorage.DatabaseAdapter,
  storage_config: [...]
```

6. **Verification:**
   - Both systems have identical data
   - No data loss during writes
   - Read operations validate both sources
   - Differences logged for manual reconciliation

**Duration:** 1-2 weeks of production runs

#### Phase 2: Read-From-Database Period (2-4 weeks)

**Objective:** Switch primary reads to database

**Configuration Change:**
```elixir
config :invoice_creation,
  storage_adapter: InvoiceStorage.DualWriteAdapter,
  primary_adapter: InvoiceStorage.DatabaseAdapter,
  secondary_adapter: InvoiceStorage.FileAdapter
```

**Validation:**
- Read operations work identically
- Performance is acceptable
- No data inconsistencies
- Easy rollback if needed

**Duration:** 2 weeks of validation

#### Phase 3: Full Migration (4-6 weeks)

**Objective:** Remove file-based adapter

```elixir
config :invoice_creation,
  storage_adapter: InvoiceStorage.DatabaseAdapter
```

**Clean-up:**
- Remove FileAdapter code (or keep as optional)
- Archive old file storage
- Update documentation

**Duration:** On go-live

#### Migration Scripts

**File: `priv/repo/migrations/TIMESTAMP_migrate_file_to_db.exs`**

```elixir
defmodule InvoiceStorage.Repo.Migrations.MigrateFileToDb do
  use Ecto.Migration

  def up do
    # This migration is run manually via:
    # Mix.Tasks.Invoke.run(["invoice_storage.migrate.files_to_db"])
    #
    # Data migration happens in Elixir code, not SQL
    :ok
  end

  def down do
    # Keep file backups, don't delete
    :ok
  end
end
```

**File: `lib/mix/tasks/invoice_storage.migrate.files_to_db.ex`**

```elixir
defmodule Mix.Tasks.InvoiceStorage.Migrate.FilesToDb do
  use Mix.Task

  @moduledoc """
  Migrates invoices from file system to database.
  
  Run with: mix invoice_storage.migrate.files_to_db
  """

  def run(_args) do
    # 1. Start Ecto repo
    # 2. Get all years from file system
    # 3. For each year:
    #    - Load all invoices
    #    - Insert into database with transaction
    #    - Log progress
    # 4. Verify counts match
    # 5. Create backup of original files
  end
end
```

---

### 1.5 CONNECTION POOLING REQUIREMENTS

#### PostgreSQL Connection Pool

**Configuration in `config/config.exs`:**

```elixir
config :invoice_creation, InvoiceStorage.Repo,
  url: System.get_env("DATABASE_URL") || "postgresql://user:password@localhost/invoices",
  
  # Connection pooling
  pool_size: 10,                    # Dev: 5, Prod: 20-50
  max_overflow: 5,                  # Allow 5 extra connections
  pool_timeout: 5000,               # Wait 5s for connection
  
  # Performance tuning
  timeout: 30000,                   # Query timeout 30s
  connect_timeout: 5000,            # Connection timeout 5s
  
  # Production settings (override in prod.exs)
  prepare: :named,                  # Named prepared statements
  ssl: true,                        # SSL for production
  
  # Replica/load balancing (optional)
  replicas: [
    [url: System.get_env("REPLICA_1_URL") || "..."]
  ]
```

**Production Override (`config/prod.exs`):**

```elixir
config :invoice_creation, InvoiceStorage.Repo,
  # Dynamic config from environment
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "20")),
  max_overflow: String.to_integer(System.get_env("DB_MAX_OVERFLOW", "10")),
  pool_timeout: String.to_integer(System.get_env("DB_POOL_TIMEOUT", "5000")),
  
  # SSL required in production
  ssl: true,
  ssl_opts: [verify: :verify_peer, cacerts: :public_key.cacerts_get()],
  
  # Connection recycling (close stale connections)
  idle_interval: 10_000,
  max_restarts: 3,
  max_seconds: 5
```

#### SQLite Connection Pool

**Configuration in `config/config.exs`:**

```elixir
config :invoice_creation, InvoiceStorage.Repo,
  database: "priv/invoice_data.db",
  
  # SQLite-specific
  journal_mode: :wal,               # Write-ahead logging for concurrency
  cache_size: -64000,               # 64MB cache
  foreign_keys: true,               # Enable FK constraints
  
  # Connection pooling (minimal for SQLite)
  pool_size: 5,
  timeout: 5000
```

**Development SQLite Configuration (`config/dev.exs`):**

```elixir
config :invoice_creation, InvoiceStorage.Repo,
  database: "priv/invoice_dev.db",
  echo: true,                       # SQL query logging
  stacktrace: true
```

**Testing SQLite Configuration (`config/test.exs`):**

```elixir
config :invoice_creation, InvoiceStorage.Repo,
  database: "priv/invoice_test.db",
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox
```

#### Connection Pool Monitoring

**Telemetry Configuration:**

```elixir
defmodule InvoiceStorage.TelemetryHandler do
  def attach_handlers do
    # Monitor connection pool
    :telemetry.attach(
      "invoice_storage.db.pool",
      [:db_connection, :pool],
      &handle_pool_telemetry/4,
      nil
    )
    
    # Monitor query performance
    :telemetry.attach(
      "invoice_storage.db.query",
      [:invoice_storage, :repo, :query],
      &handle_query_telemetry/4,
      nil
    )
  end
  
  def handle_pool_telemetry(event, measurements, metadata, _config) do
    Logger.debug("Pool event: #{inspect(event)}, measurements: #{inspect(measurements)}")
  end
  
  def handle_query_telemetry(_event, measurements, metadata, _config) do
    if measurements.queue_time + measurements.decode_time > 100 do
      Logger.warning(
        "Slow query: #{metadata.query}, took #{measurements.total_time}ms"
      )
    end
  end
end
```

---

### 1.6 TESTING APPROACH

#### Test Database Setup

**File: `config/test.exs`**

```elixir
import Config

config :invoice_creation, InvoiceStorage.Repo,
  database: "priv/invoice_test.db",
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 60_000

config :logger, level: :warning
```

#### Database Sandbox Testing

**File: `test/support/db_case.ex`**

```elixir
defmodule InvoiceStorage.DbCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto
      import Ecto.Query

      alias InvoiceStorage.Repo

      # Setup sandbox for this test
      setup tags do
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

        unless tags[:async] do
          Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
        end

        :ok
      end
    end
  end
end
```

#### Test Fixtures

**File: `test/support/factory.ex`**

```elixir
defmodule InvoiceStorage.Factory do
  import Ecto.Query

  def create_invoice_record(attrs \\ %{}) do
    invoice = create_invoice()
    record = InvoiceStorage.InvoiceRecord.from_invoice(invoice)
    
    InvoiceStorage.Repo.insert!(
      Map.merge(record, Map.new(attrs))
    )
  end

  def create_item_record(attrs \\ %{}) do
    item = create_item()
    invoice = create_invoice_record()
    record = InvoiceStorage.ItemRecord.from_item(item)
    
    InvoiceStorage.Repo.insert!(
      Map.merge(record, %{invoice_id: invoice.id}, Map.new(attrs))
    )
  end

  # ... more factory functions
end
```

#### Database Adapter Tests

**File: `test/storage/database_adapter_test.exs`**

```elixir
defmodule InvoiceStorage.DatabaseAdapterTest do
  use InvoiceStorage.DbCase, async: false

  alias InvoiceStorage.DatabaseAdapter

  describe "save/1" do
    test "saves invoice to database" do
      invoice = create_invoice()
      assert :ok = DatabaseAdapter.save(invoice)
      
      # Verify in database
      assert Repo.get_by(
        InvoiceStorage.InvoiceRecord,
        invoice_number: invoice.number,
        year: invoice.date.year
      )
    end
  end

  # ... more tests matching FileAdapter tests
end
```

#### Adapter Compatibility Tests

**File: `test/storage/adapter_compatibility_test.exs`**

```elixir
defmodule InvoiceStorage.AdapterCompatibilityTest do
  @moduledoc """
  Tests that all adapters behave identically.
  
  Run the same test suite against all adapters to ensure
  behavior compatibility.
  """

  defp adapters do
    [
      {:file, InvoiceStorage.FileAdapter},
      {:database, InvoiceStorage.DatabaseAdapter}
      # {:sqlite, InvoiceStorage.SqliteAdapter}  # when available
    ]
  end

  setup do
    # Setup for each adapter
    ...
  end

  describe "adapter behavior compatibility" do
    test "save and load round-trip", %{adapter: adapter} do
      invoice = create_invoice()
      
      assert :ok = adapter.save(invoice)
      assert {:ok, loaded} = adapter.load(invoice.number, invoice.date.year)
      
      assert invoice == loaded
    end
    
    # ... more compatibility tests
  end
end
```

---

## PART 2: CSV EXPORT/IMPORT

### 2.1 CURRENT EXPORT FORMAT ANALYSIS

**Current Export:** JSON files stored on disk
- Location: `priv/storage/invoices/YYYY/YYYY-NNNN.json`
- Format: Minified JSON
- Encoder: `InvoiceStorage.Encoder` (176 lines)

**Current JSON Structure:**

```json
{
  "date": "2024-03-05",
  "number": "2024-0001",
  "bill_to": "Acme Corp",
  "vendor_details": null,
  "items": [
    {
      "description": "Consulting",
      "units": 10,
      "amount": 500
    }
  ],
  "sale_amount": 5000,
  "vat": 1000
}
```

**Strengths:**
- Human-readable
- Easy to debug
- Complete representation
- ISO 8601 dates

**Limitations for CSV:**
- JSON nesting doesn't map well to tabular format
- Items are nested (need to flatten)
- Null values need careful handling

---

### 2.2 CSV STRUCTURE DESIGN

#### Design Decision: Denormalized Format

**Rationale:**
- Simplest for users (one CSV, all data)
- Easy import/export
- No need for multiple files
- Better for one-off migrations

#### Format 1: Invoices CSV (RECOMMENDED for exports)

**File: `invoices_export.csv`**

```csv
invoice_number,date,bill_to,vendor_details,sale_amount,vat,item_count,total_items_cost
2024-0001,2024-03-05,Acme Corp,,5000,1000,2,5000
2024-0002,2024-03-06,Tech Ltd,Tech House,10000,2000,3,10000
```

**Columns:**
- `invoice_number` (STRING): Format "YYYY-NNNN"
- `date` (DATE): ISO 8601 format
- `bill_to` (STRING): Optional, max 500 chars
- `vendor_details` (STRING): Optional, max 500 chars
- `sale_amount` (INTEGER): Cents, non-negative
- `vat` (INTEGER): Cents, non-negative
- `item_count` (INTEGER): Number of items (metadata)
- `total_items_cost` (INTEGER): Sum of item costs (validation)

**Export Use Case:** Summary view of invoices without items

#### Format 2: Detailed CSV (with items inline)

**File: `invoices_detailed_export.csv`**

```csv
invoice_number,date,bill_to,vendor_details,sale_amount,vat,item_description,item_units,item_amount,item_position
2024-0001,2024-03-05,Acme Corp,,5000,1000,Consulting,10,500,1
2024-0001,2024-03-05,Acme Corp,,5000,1000,Support,5,1000,2
2024-0002,2024-03-06,Tech Ltd,Tech House,10000,2000,Development,20,500,1
```

**Columns:** Same as invoices + item details
- `item_description` (STRING): Max 500 chars
- `item_units` (INTEGER): Positive integer
- `item_amount` (INTEGER): Cents, positive
- `item_position` (INTEGER): Order in invoice

**Export Use Case:** Complete data export with all details
**Import Use Case:** Bulk import with item restoration

**Advantages:**
- No duplicate invoice data per row
- Natural denormalization
- Easy to understand
- Excel-friendly

**Disadvantages:**
- Invoice data repeated for each item (increases file size)
- Need to parse carefully during import

#### Format 3: Split Format (Advanced)

**invoices.csv** (standalone):
```csv
invoice_number,date,bill_to,vendor_details,sale_amount,vat
2024-0001,2024-03-05,Acme Corp,,5000,1000
2024-0002,2024-03-06,Tech Ltd,Tech House,10000,2000
```

**items.csv** (relationship to invoices):
```csv
invoice_number,item_position,item_description,item_units,item_amount
2024-0001,1,Consulting,10,500
2024-0001,2,Support,5,1000
2024-0002,1,Development,20,500
```

**Advantages:**
- No redundancy
- Clean separation
- Database-like structure

**Disadvantages:**
- Two files to manage
- More complex import logic
- Not Excel-friendly for single view

**Recommendation:** Use Format 2 (detailed inline) for exports/imports

---

### 2.3 CSV STRUCTURE & HANDLING

#### CSV Library Recommendation: NimbleCSV

**Why NimbleCSV:**
- Lightweight (~200 lines)
- No dependencies
- Stream-based parsing
- Built by Plataformatec (reliable)
- Great for Elixir

**Alternative:** Ex CSV
- Richer features
- More popular
- Slightly heavier
- Good if you need streaming

**Recommendation:** NimbleCSV (start simple)

```elixir
{:nimble_csv, "~> 1.2"}
```

#### CSV Encoder (Export to CSV)

**File: `lib/storage/csv_encoder.ex`**

```elixir
defmodule InvoiceStorage.CsvEncoder do
  @moduledoc """
  CSV serialization for invoices and items.
  """

  import NimbleCSV.RFC4180, as: CSV

  alias Invoice
  alias ListInvoiceYear

  @doc """
  Encodes invoices to CSV format (detailed with items).
  
  Each item row contains full invoice data + item fields.
  Allows reconstruction of complete invoices on import.
  """
  def encode_to_csv(invoices) when is_list(invoices) do
    try do
      rows =
        invoices
        |> Enum.flat_map(&invoice_to_csv_rows/1)
        |> ensure_header()

      {:ok, CSV.dump_to_iodata(rows)}
    rescue
      e ->
        {:error,
         InvoiceStorage.Error.EncodeFailed.exception(
           reason: e,
           message: "Failed to encode invoices to CSV"
         )}
    end
  end

  def encode_to_csv(list_year = %ListInvoiceYear{}) do
    invoices = Map.values(list_year.invoices)
    encode_to_csv(invoices)
  end

  def encode_to_csv(invoice = %Invoice{}) do
    encode_to_csv([invoice])
  end

  defp invoice_to_csv_rows(%Invoice{} = invoice) do
    invoice.items
    |> Enum.with_index(1)
    |> Enum.map(fn {item, position} ->
      [
        invoice.number,
        Date.to_iso8601(invoice.date),
        invoice.bill_to,
        invoice.vendor_details,
        invoice.sale_amount,
        invoice.vat,
        item.description,
        item.units,
        item.amount,
        position
      ]
    end)
  end

  defp ensure_header(rows) do
    [header() | rows]
  end

  defp header do
    [
      "invoice_number",
      "date",
      "bill_to",
      "vendor_details",
      "sale_amount",
      "vat",
      "item_description",
      "item_units",
      "item_amount",
      "item_position"
    ]
  end
end
```

#### CSV Decoder (Import from CSV)

**File: `lib/storage/csv_decoder.ex`**

```elixir
defmodule InvoiceStorage.CsvDecoder do
  @moduledoc """
  CSV deserialization for importing invoices.
  
  Parses CSV, validates data, reconstructs Invoice structs with items.
  """

  import NimbleCSV.RFC4180, as: CSV

  alias Invoice
  alias Item
  alias InvoiceStorage.Error.DecodeFailed

  @doc """
  Decodes CSV data into Invoice structs.
  
  Reads CSV string/binary, reconstructs Invoice structs with items.
  Validates at each step.
  """
  def decode_from_csv(csv_data) when is_binary(csv_data) do
    try do
      rows = CSV.parse_string(csv_data)
      
      with {:ok, header} <- validate_header(rows),
           {:ok, data_rows} <- extract_data_rows(rows),
           {:ok, invoices} <- parse_rows_to_invoices(data_rows) do
        {:ok, invoices}
      else
        error -> error
      end
    rescue
      e ->
        {:error,
         DecodeFailed.exception(
           reason: e,
           message: "Failed to decode CSV"
         )}
    end
  end

  defp validate_header(rows) when is_list(rows) do
    case rows do
      [header | _rest] ->
        expected = required_columns()
        
        case header == expected do
          true -> {:ok, header}
          false ->
            {:error,
             DecodeFailed.exception(
               reason: :invalid_header,
               message: "CSV header doesn't match expected columns"
             )}
        end
      
      [] ->
        {:error,
         DecodeFailed.exception(
           reason: :empty_file,
           message: "CSV file is empty"
         )}
    end
  end

  defp extract_data_rows([_header | data_rows]), do: {:ok, data_rows}
  defp extract_data_rows([]), do: {:ok, []}

  defp parse_rows_to_invoices(rows) do
    rows
    |> Enum.reduce_while({:ok, %{}}, fn row, {:ok, acc} ->
      case parse_row(row) do
        {:ok, {invoice_number, item, invoice_data}} ->
          updated = add_to_invoice_map(acc, invoice_number, item, invoice_data)
          {:cont, {:ok, updated}}
        
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, invoice_map} -> build_invoices(invoice_map)
      error -> error
    end
  end

  defp parse_row(row) when is_list(row) and length(row) == 10 do
    [inv_num, date_str, bill_to, vendor_details, sale_amount_str, vat_str,
     item_desc, item_units_str, item_amount_str, item_pos_str] = row

    try do
      with {:ok, date} <- parse_date(date_str),
           {:ok, sale_amount} <- parse_integer(sale_amount_str),
           {:ok, vat} <- parse_integer(vat_str),
           {:ok, item_units} <- parse_integer(item_units_str),
           {:ok, item_amount} <- parse_integer(item_amount_str),
           {:ok, item_pos} <- parse_integer(item_pos_str),
           {:ok, item} <- Item.new(
             description: item_desc,
             units: item_units,
             amount: item_amount
           ) do
        invoice_data = %{
          number: inv_num,
          date: date,
          bill_to: clean_string(bill_to),
          vendor_details: clean_string(vendor_details),
          sale_amount: sale_amount,
          vat: vat
        }

        {:ok, {inv_num, item, invoice_data}}
      else
        error -> error
      end
    rescue
      e ->
        {:error,
         DecodeFailed.exception(
           reason: e,
           message: "Failed to parse row: #{inspect(row)}"
         )}
    end
  end

  defp parse_row(row) do
    {:error,
     DecodeFailed.exception(
       reason: :invalid_row_length,
       message: "Expected 10 columns, got #{length(row)}"
     )}
  end

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> {:ok, date}
      {:error, _} ->
        {:error,
         DecodeFailed.exception(
           reason: :invalid_date,
           message: "Invalid date format: #{date_str}"
         )}
    end
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {int, ""} -> {:ok, int}
      _ ->
        {:error,
         DecodeFailed.exception(
           reason: :invalid_integer,
           message: "Invalid integer: #{str}"
         )}
    end
  end

  defp clean_string(""), do: nil
  defp clean_string(str) when is_binary(str), do: String.trim(str)

  defp add_to_invoice_map(acc, invoice_number, item, invoice_data) do
    Map.update(acc, invoice_number, %{invoice_data | items: [item]}, fn existing ->
      Map.update(existing, :items, [item], fn items -> items ++ [item] end)
    end)
  end

  defp build_invoices(invoice_map) do
    invoices =
      invoice_map
      |> Enum.map(fn {_number, data} ->
        Invoice.new(data)
      end)
      |> Enum.reduce_while({:ok, []}, fn result, {:ok, acc} ->
        case result do
          {:ok, invoice} -> {:cont, {:ok, [invoice | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case invoices do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  end

  defp required_columns do
    [
      "invoice_number",
      "date",
      "bill_to",
      "vendor_details",
      "sale_amount",
      "vat",
      "item_description",
      "item_units",
      "item_amount",
      "item_position"
    ]
  end
end
```

---

### 2.4 CSV IMPORT PARSING STRATEGY

#### Import Workflow

```
CSV File
   │
   ├─ Read file
   │
   ├─ Parse CSV structure
   │  ├─ Validate header
   │  └─ Extract data rows
   │
   ├─ Parse each row
   │  ├─ Type conversion (strings to integers, dates)
   │  ├─ Item construction
   │  └─ Invoice reconstruction
   │
   ├─ Validate data
   │  ├─ Domain validation (Invoice.new)
   │  ├─ Item validation
   │  └─ Consistency checks
   │
   ├─ Store
   │  ├─ Begin transaction
   │  ├─ Save year metadata
   │  ├─ Save invoices
   │  └─ Commit or rollback
   │
   └─ Report results
      ├─ Success count
      ├─ Errors
      └─ Warnings
```

#### Import API

**File: `lib/storage/import.ex`**

```elixir
defmodule InvoiceStorage.Import do
  @moduledoc """
  CSV import functionality with validation and error reporting.
  """

  import NimbleCSV.RFC4180, as: CSV

  defmodule Result do
    defstruct [
      :status,              # :ok | :error | :partial
      :imported_count,      # Number of successful imports
      :failed_count,        # Number of failures
      :errors,              # List of {row_number, error_reason}
      :warnings,            # List of {row_number, warning}
      :invoices             # Successfully parsed invoices
    ]
  end

  @doc """
  Imports invoices from CSV file.
  
  Returns %Result with detailed information about import outcome.
  """
  def import_from_file(file_path, opts \\ []) do
    with {:ok, content} <- File.read(file_path) do
      import_from_string(content, opts)
    else
      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  @doc """
  Imports invoices from CSV string.
  
  Options:
    - validate_only: true  - Don't save, just validate
    - skip_errors: true    - Continue on error (partial import)
    - save_to_storage: true - Save to storage after import (default: true)
  """
  def import_from_string(csv_data, opts \\ []) do
    validate_only = Keyword.get(opts, :validate_only, false)
    skip_errors = Keyword.get(opts, :skip_errors, false)

    try do
      with {:ok, invoices} <- InvoiceStorage.CsvDecoder.decode_from_csv(csv_data),
           {:ok, result} <- validate_invoices(invoices, skip_errors),
           :ok <- maybe_save(result, validate_only) do
        {:ok, result}
      else
        {:error, reason} -> {:error, reason}
      end
    rescue
      e ->
        {:error, "Import failed: #{inspect(e)}"}
    end
  end

  defp validate_invoices(invoices, skip_errors) do
    result =
      invoices
      |> Enum.with_index(1)
      |> Enum.reduce(
        %Result{
          status: :ok,
          imported_count: 0,
          failed_count: 0,
          errors: [],
          warnings: [],
          invoices: []
        },
        fn {invoice, row_num}, acc ->
          case validate_invoice(invoice) do
            :ok ->
              %{acc | invoices: [invoice | acc.invoices], imported_count: acc.imported_count + 1}
            
            {:error, reason} when skip_errors ->
              %{
                acc
                | status: :partial,
                  failed_count: acc.failed_count + 1,
                  errors: [{row_num, reason} | acc.errors]
              }
            
            {:error, reason} ->
              raise "Row #{row_num}: #{inspect(reason)}"
          end
        end
      )

    status =
      cond do
        result.failed_count > 0 -> :partial
        result.imported_count > 0 -> :ok
        true -> :error
      end

    {:ok, %{result | status: status, invoices: Enum.reverse(result.invoices)}}
  end

  defp validate_invoice(%Invoice{} = invoice) do
    # All validation already done in CSV decoder
    # This is a safety check
    :ok
  end

  defp maybe_save(result, validate_only) when validate_only, do: {:ok, result}

  defp maybe_save(result, false) do
    # Save invoices to storage
    # Group by year for ListInvoiceYear construction
    result.invoices
    |> Enum.group_by(fn inv -> inv.date.year end)
    |> Enum.reduce_while(:ok, fn {year, invoices}, :ok ->
      list_year = ListInvoiceYear.new(year: year)
      # ... add invoices and save
      {:cont, :ok}
    end)
  end
end
```

---

### 2.5 DATA VALIDATION DURING CSV IMPORT

#### Validation Strategy

**Three-Layer Validation:**

1. **CSV Structure Validation** - Is it a valid CSV file?
2. **Field Validation** - Can we parse the fields correctly?
3. **Domain Validation** - Do the values satisfy business rules?

**File: `lib/storage/csv_validator.ex`**

```elixir
defmodule InvoiceStorage.CsvValidator do
  @moduledoc """
  Comprehensive validation for CSV import.
  """

  defmodule ValidationError do
    defexception [:row, :field, :message]

    def message(%{row: row, field: field, message: msg}) do
      "Row #{row}, field '#{field}': #{msg}"
    end
  end

  @doc """
  Validates invoice data parsed from CSV.
  
  Returns :ok or {:error, [%ValidationError]}
  """
  def validate_invoice(invoice, row_number) do
    errors = []
    |> validate_number(invoice, row_number)
    |> validate_date(invoice, row_number)
    |> validate_bill_to(invoice, row_number)
    |> validate_vendor_details(invoice, row_number)
    |> validate_sale_amount(invoice, row_number)
    |> validate_vat(invoice, row_number)
    |> validate_items(invoice, row_number)

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp validate_number(errors, %Invoice{number: number}, row) do
    cond do
      not is_binary(number) ->
        errors ++ [error(row, "invoice_number", "must be string")]

      byte_size(number) == 0 ->
        errors ++ [error(row, "invoice_number", "cannot be empty")]

      byte_size(number) > 20 ->
        errors ++ [error(row, "invoice_number", "max 20 characters")]

      not String.match?(number, ~r/^\d{4}-\d{4}$/) ->
        errors ++ [error(row, "invoice_number", "format must be YYYY-NNNN")]

      true ->
        errors
    end
  end

  defp validate_date(errors, %Invoice{date: date}, row) do
    cond do
      not is_struct(date, Date) ->
        errors ++ [error(row, "date", "invalid date")]

      Date.compare(date, Date.utc_today()) == :gt ->
        errors ++ [error(row, "date", "cannot be in future")]

      true ->
        errors
    end
  end

  defp validate_items(errors, %Invoice{items: items}, row) do
    case items do
      [] ->
        errors ++ [error(row, "items", "must have at least one item")]

      items when is_list(items) ->
        items
        |> Enum.with_index(1)
        |> Enum.reduce(errors, fn {item, idx}, acc ->
          validate_item(acc, item, row, idx)
        end)

      _ ->
        errors ++ [error(row, "items", "must be list")]
    end
  end

  defp validate_item(errors, %Item{} = item, row, item_idx) do
    errors
    |> validate_item_description(item, row, item_idx)
    |> validate_item_units(item, row, item_idx)
    |> validate_item_amount(item, row, item_idx)
  end

  defp error(row, field, message) do
    %ValidationError{row: row, field: field, message: message}
  end

  # ... more validation helpers
end
```

---

### 2.6 EDGE CASES HANDLING

#### Special Character Handling

**CSV Library Handling:**
- NimbleCSV uses RFC 4180 standard
- Automatically handles quoted fields with commas
- Escapes quotes as ""

**Examples:**

```csv
invoice_number,date,bill_to,...
2024-0001,2024-03-05,"Acme Corp, Inc.",...  # Commas in fields
2024-0002,2024-03-06,"O'Brien ""Ltd""",...  # Quotes in fields
2024-0003,2024-03-07,"Line 1
Line 2",...                                   # Multiline fields
```

**Multiline Field Handling:**

```elixir
defp handle_multiline(field) do
  # Preserve newlines in text fields
  String.replace(field, "\n", " ")  # or keep as-is for description
end
```

#### Encoding Issues

**Handle UTF-8 Encoding:**

```elixir
def import_from_file(file_path, opts \\ []) do
  with {:ok, content} <- File.read(file_path),
       {:ok, decoded} <- maybe_decode_encoding(content) do
    import_from_string(decoded, opts)
  end
end

defp maybe_decode_encoding(content) do
  case String.valid?(content) do
    true -> {:ok, content}
    false ->
      # Try common encodings
      case :iconv.convert('ISO-8859-1', 'UTF-8', content) do
        {:ok, decoded} -> {:ok, decoded}
        {:error, _} -> {:error, "Unsupported encoding"}
      end
  end
end
```

#### Missing/Empty Values

**Strategy:** Treat empty strings as nil for optional fields

```elixir
defp clean_string(""), do: nil
defp clean_string(nil), do: nil
defp clean_string(value) when is_binary(value), do: String.trim(value)

# In CSV decoder:
bill_to: clean_string(bill_to),
vendor_details: clean_string(vendor_details)
```

#### Duplicate Invoice Numbers

**Strategy:** Detect and reject duplicates within same CSV

```elixir
defp check_duplicates(invoices) do
  duplicates =
    invoices
    |> Enum.group_by(& &1.number)
    |> Enum.filter(fn {_num, list} -> length(list) > 1 end)
    |> Enum.map(&elem(&1, 0))

  case duplicates do
    [] -> :ok
    dups ->
      {:error,
       "Duplicate invoice numbers in import: #{Enum.join(dups, ", ")}"}
  end
end
```

#### Data Type Coercion

**Strategy:** Be strict - don't guess types

```elixir
defp parse_integer(str) when is_binary(str) do
  case Integer.parse(str) do
    {int, ""} ->
      {:ok, int}

    {_int, rest} ->
      {:error, "Not a pure integer, has: #{rest}"}

    :error ->
      {:error, "Not an integer"}
  end
end
```

---

### 2.7 CSV LIBRARY RECOMMENDATIONS

#### Recommended: NimbleCSV

**Pros:**
- Simple, focused library (~200 lines)
- No dependencies
- RFC 4180 compliant
- Stream support for large files
- Used in production by many projects

**Cons:**
- Basic feature set (no schema validation)
- Manual parsing required

**When to Use:**
- Import/export of invoices
- Simple tabular data

**Installation:**
```elixir
{:nimble_csv, "~> 1.2"}
```

#### Alternative: Ex CSV

**Pros:**
- Rich feature set
- Schema definition
- Error reporting
- More mature

**Cons:**
- Heavier
- More dependencies
- Overkill for our use case

**When to Use:**
- Complex multi-file imports
- Sophisticated schema validation
- Large-scale data pipelines

#### Why Not Others:

**CSV** - Unmaintained
**StreamData** - Not for CSV parsing, for property testing
**Excelion** - For XLSX, not CSV

---

## PART 3: FILE FORMAT ABSTRACTION

### 3.1 MULTI-FORMAT SYSTEM DESIGN

#### Encoder/Decoder Pattern (Current)

**Current Implementation:**
- `InvoiceStorage.Encoder` - JSON encoding
- `InvoiceStorage.Decoder` - JSON decoding
- `InvoiceStorage.CsvEncoder` - CSV encoding (new)
- `InvoiceStorage.CsvDecoder` - CSV decoding (new)

**Problem:** Hardcoded to specific formats

**Solution:** Abstract format layer

#### Format Abstraction Architecture

```
┌─────────────────────────────────────────────────┐
│          Storage API (InvoiceStorage)            │
│  - save/1, load/1, save_all/1, load_all/1, etc  │
└────────────────┬────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
   ┌────▼─────┐   ┌───────▼────┐
   │ Adapter   │   │ Format     │
   │ Pattern   │   │ Encoder    │
   │ (DB/File) │   │ Decoder    │
   └───────────┘   └────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
    ┌───▼──┐      ┌──────▼──┐     ┌───▼──┐
    │JSON  │      │ CSV     │     │XML   │ (future)
    │  +   │      │  +      │     │ +    │
    │File  │      │ Memory  │     │Attr  │
    └──────┘      └─────────┘     └──────┘
```

#### Format Behavior Definition

**File: `lib/storage/format.ex`**

```elixir
defmodule InvoiceStorage.Format do
  @moduledoc """
  Behavior definition for invoice format encoders/decoders.
  
  Allows support for multiple serialization formats (JSON, CSV, XML, etc.)
  without changing the storage adapter interface.
  """

  alias Invoice
  alias ListInvoiceYear

  @doc """
  Encodes an invoice to the target format.
  
  Returns {:ok, encoded_data} or {:error, reason}
  """
  @callback encode_invoice(Invoice.t()) ::
              {:ok, term()} | {:error, any()}

  @doc """
  Encodes multiple invoices to the target format.
  
  Returns {:ok, encoded_data} or {:error, reason}
  """
  @callback encode_invoices([Invoice.t()]) ::
              {:ok, term()} | {:error, any()}

  @doc """
  Encodes a ListInvoiceYear to the target format.
  
  Returns {:ok, encoded_data} or {:error, reason}
  """
  @callback encode_list_invoice_year(ListInvoiceYear.t()) ::
              {:ok, term()} | {:error, any()}

  @doc """
  Decodes data from the target format to an invoice.
  
  Returns {:ok, Invoice.t()} or {:error, reason}
  """
  @callback decode_invoice(term()) ::
              {:ok, Invoice.t()} | {:error, any()}

  @doc """
  Decodes data from the target format to multiple invoices.
  
  Returns {:ok, [Invoice.t()]} or {:error, reason}
  """
  @callback decode_invoices(term()) ::
              {:ok, [Invoice.t()]} | {:error, any()}

  @doc """
  Decodes data from the target format to a ListInvoiceYear.
  
  Returns {:ok, ListInvoiceYear.t()} | {:error, reason}
  """
  @callback decode_list_invoice_year(term()) ::
              {:ok, ListInvoiceYear.t()} | {:error, any()}

  @doc """
  Returns the file extension for this format.
  
  Example: "json", "csv"
  """
  @callback file_extension() :: String.t()

  @doc """
  Returns the MIME type for this format.
  
  Example: "application/json"
  """
  @callback mime_type() :: String.t()

  @doc """
  Gets a format encoder/decoder by name.
  
  Returns the module that implements InvoiceStorage.Format behavior.
  """
  @spec get_format(String.t()) :: {:ok, module()} | {:error, String.t()}
  def get_format(name) when is_binary(name) do
    case String.downcase(name) do
      "json" -> {:ok, InvoiceStorage.JsonFormat}
      "csv" -> {:ok, InvoiceStorage.CsvFormat}
      "xml" -> {:error, "XML format not yet implemented"}
      other -> {:error, "Unknown format: #{other}"}
    end
  end

  def get_format(_), do: {:error, "Format name must be string"}

  @spec list_formats() :: [module()]
  def list_formats do
    [InvoiceStorage.JsonFormat, InvoiceStorage.CsvFormat]
  end
end
```

#### JSON Format Implementation

**File: `lib/storage/formats/json_format.ex`**

```elixir
defmodule InvoiceStorage.JsonFormat do
  @behaviour InvoiceStorage.Format

  alias Invoice
  alias ListInvoiceYear
  alias InvoiceStorage.{Encoder, Decoder}

  def encode_invoice(%Invoice{} = invoice) do
    Encoder.encode_invoice(invoice)
  end

  def encode_invoices(invoices) when is_list(invoices) do
    try do
      encoded =
        invoices
        |> Enum.map(&Encoder.encode_invoice!/1)
        |> Jason.encode!()

      {:ok, encoded}
    rescue
      e -> {:error, e}
    end
  end

  def encode_list_invoice_year(%ListInvoiceYear{} = list) do
    Encoder.encode_list_invoice_year(list)
  end

  def decode_invoice(data) when is_map(data) do
    Decoder.decode_invoice(data)
  end

  def decode_invoice(data) when is_binary(data) do
    with {:ok, json} <- Jason.decode(data) do
      decode_invoice(json)
    end
  end

  def decode_invoices(data) when is_binary(data) do
    try do
      with {:ok, json} <- Jason.decode(data) do
        case json do
          list when is_list(list) ->
            list
            |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
              case decode_invoice(item) do
                {:ok, invoice} -> {:cont, {:ok, [invoice | acc]}}
                {:error, reason} -> {:halt, {:error, reason}}
              end
            end)
            |> case do
              {:ok, invoices} -> {:ok, Enum.reverse(invoices)}
              error -> error
            end

          _ -> {:error, "Expected JSON array"}
        end
      end
    rescue
      e -> {:error, e}
    end
  end

  def decode_list_invoice_year(data) when is_binary(data) do
    with {:ok, json} <- Jason.decode(data) do
      Decoder.decode_list_invoice_year(json)
    end
  end

  def file_extension, do: "json"
  def mime_type, do: "application/json"
end
```

#### CSV Format Implementation

**File: `lib/storage/formats/csv_format.ex`**

```elixir
defmodule InvoiceStorage.CsvFormat do
  @behaviour InvoiceStorage.Format

  alias Invoice
  alias ListInvoiceYear
  alias InvoiceStorage.{CsvEncoder, CsvDecoder}

  def encode_invoice(%Invoice{} = invoice) do
    # CSV doesn't naturally represent single invoices
    # Return CSV with just the invoice's items
    encode_invoices([invoice])
  end

  def encode_invoices(invoices) when is_list(invoices) do
    CsvEncoder.encode_to_csv(invoices)
  end

  def encode_list_invoice_year(%ListInvoiceYear{} = list) do
    encode_invoices(Map.values(list.invoices))
  end

  def decode_invoice(_data) do
    {:error, "Cannot decode single invoice from CSV, use decode_invoices"}
  end

  def decode_invoices(data) when is_binary(data) do
    CsvDecoder.decode_from_csv(data)
  end

  def decode_list_invoice_year(data) when is_binary(data) do
    with {:ok, invoices} <- decode_invoices(data) do
      # Group by year and build ListInvoiceYear
      # Note: CSV doesn't preserve year, so we need to infer or handle differently
      case invoices do
        [first | _rest] ->
          year = first.date.year
          list_year = %ListInvoiceYear{
            year: year,
            next_id: length(invoices),
            invoices: Enum.into(invoices, %{}, fn inv -> {inv.number, inv} end)
          }
          {:ok, list_year}

        [] ->
          {:error, "No invoices in CSV"}
      end
    end
  end

  def file_extension, do: "csv"
  def mime_type, do: "text/csv"
end
```

---

### 3.2 FORMAT SELECTION MECHANISM

#### Configuration-Driven Format Selection

**File: `config/config.exs`**

```elixir
import Config

config :invoice_creation,
  # Default format for exports
  export_format: "json",  # or "csv"
  
  # Supported formats
  supported_formats: ["json", "csv"],
  
  # Format-specific options
  json_opts: [
    pretty: false,
    indent: nil
  ],
  
  csv_opts: [
    delimiter: ",",
    headers: true
  ]
```

#### Format Selection at Runtime

**File: `lib/invoice_creation/export.ex`**

```elixir
defmodule InvoiceCreation.Export do
  @moduledoc """
  Export invoices in various formats.
  """

  @doc """
  Exports invoices to a file in the specified format.
  
  Options:
    - format: "json" | "csv" (default: application config)
    - pretty: true | false (for JSON)
  """
  def export_to_file(invoices, file_path, opts \\ []) do
    format = Keyword.get(opts, :format, default_export_format())

    with {:ok, format_mod} <- InvoiceStorage.Format.get_format(format),
         {:ok, data} <- format_mod.encode_invoices(invoices),
         :ok <- File.write(file_path, data) do
      {:ok, file_path}
    end
  end

  @doc """
  Exports invoices to a string in the specified format.
  """
  def export_to_string(invoices, opts \\ []) do
    format = Keyword.get(opts, :format, default_export_format())

    with {:ok, format_mod} <- InvoiceStorage.Format.get_format(format) do
      format_mod.encode_invoices(invoices)
    end
  end

  defp default_export_format do
    Application.get_env(:invoice_creation, :export_format, "json")
  end
end
```

#### Import with Format Detection

**File: `lib/invoice_creation/import.ex`**

```elixir
defmodule InvoiceCreation.Import do
  @moduledoc """
  Import invoices from various formats.
  """

  @doc """
  Imports invoices from a file, auto-detecting format.
  
  Detects format from file extension.
  """
  def import_from_file(file_path, opts \\ []) do
    with {:ok, format} <- detect_format(file_path),
         {:ok, content} <- File.read(file_path),
         {:ok, invoices} <- import_from_string(content, format, opts) do
      {:ok, invoices}
    end
  end

  @doc """
  Imports invoices from a string with explicit format.
  """
  def import_from_string(data, format, opts \\ []) do
    with {:ok, format_mod} <- InvoiceStorage.Format.get_format(format) do
      format_mod.decode_invoices(data)
    end
  end

  defp detect_format(file_path) do
    ext =
      file_path
      |> Path.extname()
      |> String.downcase()
      |> String.trim_leading(".")

    case ext do
      "json" -> {:ok, "json"}
      "csv" -> {:ok, "csv"}
      other -> {:error, "Unsupported file format: .#{other}"}
    end
  end
end
```

---

### 3.3 BACKWARD COMPATIBILITY CONSIDERATIONS

#### File Structure Compatibility

**Current File Structure:**
```
priv/storage/
├── invoices/
│   ├── 2024/
│   │   ├── 2024-0001.json
│   │   └── 2024-0002.json
│   └── 2023/
│       └── 2023-0001.json
└── years/
    ├── 2024.json
    └── 2023.json
```

**Proposed Structure (Compatible):**
```
priv/storage/
├── invoices/
│   ├── 2024/
│   │   ├── 2024-0001.json          ✓ Unchanged
│   │   └── 2024-0002.json          ✓ Unchanged
│   └── 2023/
│       └── 2023-0001.json          ✓ Unchanged
├── years/
│   ├── 2024.json                   ✓ Unchanged
│   └── 2023.json                   ✓ Unchanged
├── exports/                        ✓ New (optional)
│   └── invoices_2024_03_05.csv
└── imports/                        ✓ New (optional)
    └── staging_upload_123.csv
```

**No Breaking Changes:**
- All JSON files remain in exact same format
- FileAdapter continues to work unchanged
- New formats are opt-in
- Existing code unaffected

#### API Stability

**Current Public API (Unchanged):**
```elixir
InvoiceStorage.save/1
InvoiceStorage.load/2
InvoiceStorage.delete/2
InvoiceStorage.exists?/2
InvoiceStorage.save_all/1
InvoiceStorage.load_all/1
InvoiceStorage.save_year_list/1
InvoiceStorage.load_year_list/1
InvoiceStorage.list_years/0
InvoiceStorage.count/1
```

**New Public API (Additive):**
```elixir
InvoiceCreation.Export.export_to_file/3
InvoiceCreation.Export.export_to_string/2
InvoiceCreation.Import.import_from_file/2
InvoiceCreation.Import.import_from_string/3
InvoiceStorage.Format.get_format/1
InvoiceStorage.Format.list_formats/0
```

**Migration Path:**
1. Phase 1: Add new Format modules (non-breaking)
2. Phase 2: Add Export/Import modules (non-breaking)
3. Phase 3: Optionally switch database adapter (configurable)
4. Phase 4: Remove FileAdapter (only after successful migration)

#### Version Considerations

**Semantic Versioning:**
- Format support: Minor version bump (0.2.0)
- Database adapter: Minor version bump (0.2.0)
- Dropping file adapter: Major version bump (1.0.0)

---

## PART 4: IMPLEMENTATION SUMMARY

### 4.1 NEW DEPENDENCIES

```elixir
defp deps do
  [
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:faker, "~> 0.18.0", only: :test},
    
    # Database
    {:ecto, "~> 3.10"},
    {:ecto_sql, "~> 3.10"},
    {:postgrex, "~> 0.18"},
    {:ecto_sqlite3, "~> 0.13", optional: true},
    
    # CSV
    {:nimble_csv, "~> 1.2"},
    
    # JSON (already used, ensure it's explicit)
    {:jason, "~> 1.4"}
  ]
end
```

### 4.2 NEW MODULE STRUCTURE

**Database Layer:**
```
lib/storage/
├── adapter.ex                    (unchanged)
├── persistence.ex                (unchanged, file adapter)
├── database_adapter.ex           (new, PostgreSQL/SQLite)
├── postgres_adapter.ex           (optional, explicit)
├── sqlite_adapter.ex             (optional, SQLite specific)
├── database_adapter_template.ex  (keep as reference)
│
├── schemas/
│   ├── invoice_record.ex         (new, Ecto schema)
│   ├── item_record.ex            (new, Ecto schema)
│   ├── year_record.ex            (new, Ecto schema)
│   └── migration_helpers.ex      (new, common migration code)
│
└── database/
    ├── repo.ex                   (new, Ecto Repo)
    ├── migrations/
    │   └── TIMESTAMP_*.exs       (new, DB migrations)
    └── seeds.exs                 (new, optional seeds)
```

**Format Layer:**
```
lib/storage/
├── format.ex                     (new, behavior)
├── formats/
│   ├── json_format.ex            (new, wraps Encoder/Decoder)
│   └── csv_format.ex             (new, new functionality)
│
├── encoder.ex                    (unchanged, JSON specific)
├── decoder.ex                    (unchanged, JSON specific)
├── csv_encoder.ex                (new, CSV export)
├── csv_decoder.ex                (new, CSV import)
└── csv_validator.ex              (new, validation rules)
```

**Import/Export Layer:**
```
lib/
├── invoice_creation/
│   ├── export.ex                 (new, high-level export)
│   └── import.ex                 (new, high-level import)
```

**Testing Support:**
```
test/
├── support/
│   ├── db_case.ex                (new, database test helpers)
│   ├── factory.ex                (updated, add DB records)
│   └── csv_fixtures.ex           (new, sample CSV data)
│
├── storage/
│   ├── database_adapter_test.exs (new, DB adapter tests)
│   ├── adapter_compatibility_test.exs (new, cross-adapter tests)
│   ├── csv_encoder_test.exs      (new, CSV export tests)
│   ├── csv_decoder_test.exs      (new, CSV import tests)
│   ├── format_test.exs           (new, format behavior tests)
│   └── ... (existing tests unchanged)
│
└── invoice_creation/
    ├── export_test.exs           (new, export functionality)
    └── import_test.exs           (new, import functionality)
```

### 4.3 CONFIGURATION CHANGES

**Development (`config/dev.exs`):**
```elixir
import Config

config :invoice_creation, InvoiceStorage.Repo,
  database: "priv/invoice_dev.db",
  echo: true,
  stacktrace: true

config :invoice_creation,
  storage_adapter: InvoiceStorage.FileAdapter,
  export_format: "json",
  supported_formats: ["json", "csv"]
```

**Production (`config/prod.exs`):**
```elixir
import Config

config :invoice_creation, InvoiceStorage.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "20")),
  ssl: true

config :invoice_creation,
  storage_adapter: InvoiceStorage.DatabaseAdapter
```

**Test (`config/test.exs`):**
```elixir
import Config

config :invoice_creation, InvoiceStorage.Repo,
  database: "priv/invoice_test.db",
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox

config :invoice_creation,
  storage_adapter: InvoiceStorage.FileAdapter,
  storage_root: Path.join(System.tmp_dir!(), "invoice_test")
```

---

## PART 5: TIMELINE & EFFORT ESTIMATE

### Phase-by-Phase Timeline

#### Phase 1: Setup & Database Foundation (Weeks 1-2)

**Week 1:**
- [ ] Add Ecto dependencies
- [ ] Create Ecto schemas (InvoiceRecord, ItemRecord, YearRecord)
- [ ] Create database migrations
- [ ] Set up Repo configuration
- [ ] Database testing infrastructure (DbCase, Factory)

**Effort:** 16 hours
**Deliverable:** Database structure with schemas and tests

**Week 2:**
- [ ] Implement DatabaseAdapter (all 10 callbacks)
- [ ] Implement record conversion functions
- [ ] Unit tests for DatabaseAdapter
- [ ] Cross-adapter compatibility tests

**Effort:** 20 hours
**Deliverable:** Functional DatabaseAdapter with tests passing

#### Phase 2: Migration & Dual-Write (Weeks 3-4)

**Week 3:**
- [ ] Implement DualWriteAdapter
- [ ] Migration script (files_to_db)
- [ ] Integration tests for dual-write
- [ ] Data consistency verification tools

**Effort:** 12 hours
**Deliverable:** Dual-write system working, migration tooling ready

**Week 4:**
- [ ] Deploy to staging with dual-write
- [ ] Monitor for data inconsistencies
- [ ] Fix any issues found
- [ ] Documentation updates

**Effort:** 8 hours (mostly monitoring)
**Deliverable:** Verified dual-write in production

#### Phase 3: CSV Support (Weeks 5-6)

**Week 5:**
- [ ] Implement CsvEncoder (encode_to_csv)
- [ ] Implement CsvDecoder (decode_from_csv)
- [ ] CSV encoder/decoder tests
- [ ] Edge case handling (special chars, multiline)

**Effort:** 20 hours
**Deliverable:** CSV import/export working with tests

**Week 6:**
- [ ] Add NimbleCSV dependency
- [ ] Implement Export module (export_to_file, export_to_string)
- [ ] Implement Import module (import_from_file, import_from_string)
- [ ] Format detection logic
- [ ] End-to-end tests

**Effort:** 16 hours
**Deliverable:** Full import/export functionality

#### Phase 4: Format Abstraction (Week 7)

**Week 7:**
- [ ] Define Format behavior
- [ ] Implement JsonFormat wrapper
- [ ] Implement CsvFormat wrapper
- [ ] Format registry/discovery
- [ ] Tests for format abstraction

**Effort:** 12 hours
**Deliverable:** Multi-format abstraction complete

#### Phase 5: Validation & Polish (Week 8)

**Week 8:**
- [ ] Implement CsvValidator
- [ ] Comprehensive error handling
- [ ] Documentation (README, examples)
- [ ] Performance testing/optimization
- [ ] Final integration tests

**Effort:** 16 hours
**Deliverable:** Production-ready system

#### Phase 6: Cleanup & Database Switch (Week 9)

**Week 9:**
- [ ] Switch from DualWrite to DatabaseAdapter
- [ ] Remove FileAdapter (or make optional)
- [ ] Final production testing
- [ ] Archive old file storage
- [ ] Release notes

**Effort:** 8 hours
**Deliverable:** Live on database adapter

### Total Timeline

**Duration:** 9 weeks (54-56 days)
**Total Effort:** 104 hours (~2.6 weeks of full-time work)

**Recommended Schedule:**
- One developer: 9 weeks part-time (10-15 hrs/week)
- Two developers: 5 weeks parallel (5-8 hrs/week each)

### Critical Path Dependencies

```
Week 1 (Schemas)
    ↓
Week 2 (DatabaseAdapter)
    ↓
Week 3 (DualWrite + Migration)
    ↓
Week 4 (Production Validation)
    ↓
Week 5 (CSV Implementation)
    ↓
Week 6 (Import/Export)
    ↓
Week 7 (Format Abstraction)
    ↓
Week 8 (Validation & Testing)
    ↓
Week 9 (Cleanup & Switch)
```

### Parallel Work Streams (with 2 developers)

**Developer A (Database):**
- Weeks 1-4: Ecto setup, DatabaseAdapter, DualWrite
- Week 8: Testing & documentation

**Developer B (CSV/Format):**
- Week 1: Support tests setup
- Weeks 5-7: CSV implementation, Format abstraction
- Week 8: Validation & edge cases

**Both:**
- Week 9: Final integration & deployment

---

## PART 6: TESTING STRATEGY

### Unit Testing

**Coverage Target:** >90% of new code

**Database Adapter Tests:** 
- Test each callback independently
- Test transaction behavior
- Test error handling
- Mock database calls

**Format Tests:**
- Round-trip tests (encode → decode)
- Edge case handling
- Error scenarios
- Performance benchmarks

**CSV Tests:**
- Header validation
- Type coercion
- Special characters
- Multiline fields
- Missing values

### Integration Testing

**Adapter Compatibility:**
- Run same tests against FileAdapter and DatabaseAdapter
- Verify identical behavior
- Performance comparison

**Migration Testing:**
- Verify data integrity during migration
- Test with large datasets (1000+ invoices)
- Rollback scenarios

**Format Compatibility:**
- Export to CSV, import back, compare with original
- Export to JSON, verify with existing tests
- Cross-format consistency

### End-to-End Testing

**Complete Workflows:**
1. Create invoices
2. Export to CSV
3. Modify CSV externally
4. Import back
5. Verify data integrity

**Production Scenarios:**
- Dual-write consistency check
- Large batch imports
- Concurrent operations
- Storage failover

### Performance Testing

**Benchmark Suite:**

```elixir
defmodule InvoiceStorage.PerformanceTest do
  def benchmark_export do
    invoices = generate_invoices(10_000)
    
    {json_time, _} = :timer.tc(fn ->
      InvoiceStorage.JsonFormat.encode_invoices(invoices)
    end)
    
    {csv_time, _} = :timer.tc(fn ->
      InvoiceStorage.CsvFormat.encode_invoices(invoices)
    end)
    
    IO.puts("JSON: #{json_time}µs")
    IO.puts("CSV: #{csv_time}µs")
  end
  
  # Similar for import, database operations, etc.
end
```

**Target Performance:**
- JSON encode/decode: <100ms for 1000 invoices
- CSV encode/decode: <200ms for 1000 invoices
- Database save: <10ms per invoice
- Database load: <50ms per 100 invoices

### Regression Testing

**Test Suites to Keep:**
- All existing InvoiceStorage tests
- All Invoice/Item validation tests
- All ListInvoiceYear tests

**Compatibility Matrix:**

| Operation | FileAdapter | DatabaseAdapter | CSV Format |
|---|---|---|---|
| save/1 | ✓ | ✓ | — |
| load/2 | ✓ | ✓ | — |
| delete/2 | ✓ | ✓ | — |
| exists?/2 | ✓ | ✓ | — |
| save_all/1 | ✓ | ✓ | — |
| load_all/1 | ✓ | ✓ | — |
| export_to_csv | — | — | ✓ |
| import_from_csv | — | — | ✓ |

---

## PART 7: RISK MITIGATION

### Identified Risks & Mitigations

#### Risk 1: Data Loss During Migration

**Probability:** Medium
**Impact:** Critical

**Mitigation:**
1. Keep file backups throughout migration
2. Verify row counts match (invoices.count in files vs DB)
3. Run validation queries after migration
4. Keep FileAdapter as fallback for 1 month

**Contingency:**
- Roll back to file adapter if discrepancies found
- Restore from backup

#### Risk 2: Performance Degradation

**Probability:** Low
**Impact:** High

**Mitigation:**
1. Benchmark all critical paths
2. Index the database appropriately
3. Connection pooling configured properly
4. Query optimization before release

**Contingency:**
- Keep file adapter as high-speed fallback
- Implement caching layer if needed

#### Risk 3: CSV Import Data Corruption

**Probability:** Medium (users can provide bad CSV)
**Impact:** Medium

**Mitigation:**
1. Comprehensive validation before import
2. Rollback on any error
3. Detailed error reporting
4. Dry-run/validate-only mode
5. User documentation with examples

**Contingency:**
- Reject entire import on error
- Provide CSV template for users

#### Risk 4: Format Incompatibility

**Probability:** Low
**Impact:** Medium

**Mitigation:**
1. Round-trip tests (export → import)
2. Version-aware encoding
3. Comprehensive change logs
4. Backward compatibility in decoding

**Contingency:**
- Support multiple format versions
- Migration script for format upgrades

#### Risk 5: Database Connection Issues

**Probability:** Medium (network issues, pool exhaustion)
**Impact:** High

**Mitigation:**
1. Connection pool tuning
2. Timeout configuration
3. Retry logic with backoff
4. Circuit breaker pattern
5. Monitoring/alerting

**Contingency:**
- Fallback to file adapter
- Health check endpoints

### Testing for Risk Mitigation

**Chaos Engineering Tests:**
```elixir
defmodule InvoiceStorage.ChaosTest do
  test "handles database connection failures" do
    # Simulate connection failure
    # Verify graceful degradation
  end

  test "handles large CSV imports with partial failures" do
    # Import CSV with some invalid rows
    # Verify valid rows saved, invalid ones reported
  end

  test "survives network partition" do
    # Simulate network partition during save
    # Verify data consistency
  end
end
```

---

## PART 8: DEPLOYMENT STRATEGY

### Pre-Deployment Checklist

- [ ] All tests passing (>90% coverage)
- [ ] Database migrations prepared
- [ ] DualWrite adapter configured
- [ ] Monitoring set up (connection pool, query times)
- [ ] Backup strategy in place
- [ ] Rollback procedure documented
- [ ] Team trained on new system
- [ ] Documentation updated

### Deployment Steps

#### Stage 1: Staging Environment
1. Deploy with dual-write enabled
2. Run 1 week with normal traffic
3. Verify data consistency daily
4. Monitor performance metrics
5. Collect feedback

#### Stage 2: Canary Deployment
1. Deploy to 10% of production
2. Monitor closely (8 hours)
3. Gradually increase to 50%, then 100%
4. Ready to rollback at any point

#### Stage 3: Full Production
1. All users on DatabaseAdapter
2. Keep FileAdapter as fallback
3. Monitor for 1 week
4. Archive old files (keep backup)
5. Celebrate!

### Rollback Procedure

**If Critical Issue:**
```bash
# 1. Switch config to FileAdapter
# 2. Restart application
# 3. Data still in files, no data loss
# 4. Investigate issue
# 5. Plan retry
```

**Time to Rollback:** 2-5 minutes (application restart)

---

## PART 9: DOCUMENTATION PLAN

### Developer Documentation

1. **Architecture Guide** - How everything fits together
2. **Database Integration** - Setting up database, migrations
3. **Adding Custom Format** - Template for new format support
4. **CSV Import/Export Guide** - How to use CSV functionality
5. **API Reference** - All public functions documented
6. **Testing Guide** - How to test with new storage layers

### User Documentation

1. **CSV Template** - Example CSV format with filled data
2. **Import Guide** - Step-by-step CSV import instructions
3. **Export Guide** - How to export invoices
4. **Troubleshooting** - Common import errors & solutions
5. **FAQ** - Frequently asked questions

### Operations Documentation

1. **Deployment Guide** - How to deploy (with DualWrite, switching)
2. **Monitoring** - What metrics to watch
3. **Backup Strategy** - How to back up database
4. **Disaster Recovery** - How to recover from failures
5. **Performance Tuning** - How to optimize

---

## CONCLUSION

This comprehensive plan provides a complete roadmap for:

1. **Database Integration** - Add PostgreSQL/SQLite support without breaking existing file-based system
2. **CSV Support** - Import/export invoices in CSV format with robust validation
3. **Format Abstraction** - Support multiple serialization formats extensibly
4. **Production Readiness** - Risk mitigation, testing strategy, deployment plans

**Key Advantages:**
- Backward compatible (no breaking changes)
- Phased approach (reduce risk)
- Extensible design (easy to add new formats)
- Well-tested (comprehensive test strategy)
- Production-ready (monitoring, rollback plans)

**Next Steps:**
1. Review and approve this plan
2. Set up development environment (Ecto, dependencies)
3. Begin Week 1: Database foundation
4. Follow timeline and track progress
5. Execute deployment plan

**Questions?**
Contact the development team for clarification on any section.

---

**Document End**
