# que-schema

Enables **schema.rb** compatibility for the [que](https://github.com/que-rb/que) job queue gem. With this gem, you can use Rails' default `:ruby` schema format instead of being forced to `structure.sql`.

## Why

Que's migrations create PostgreSQL-specific objects (PL/pgSQL functions, triggers, UNLOGGED tables, storage options) that ActiveRecord's schema dumper doesn't represent in `schema.rb` by default. Apps using Que have typically had to set `config.active_record.schema_format = :sql` and maintain `structure.sql`. This gem patches the schema dump/load pipeline so all of Que's constructs round-trip through `schema.rb` with **zero changes** to your existing Que migrations.

## Installation

Add to your Gemfile:

```ruby
gem "que-schema"
```

No configuration required. Keep using `schema.rb` (the default). If you were on `structure.sql` only for Que, you can switch back to `:ruby` and run `db:schema:dump`; the dump will include Que's schema via custom DSL calls.

## How it works

- **Dump:** The gem prepends into `ActiveRecord::SchemaDumper`. When it sees the `que_jobs` table (and reads the Que schema version from the table comment), it emits `que_define_schema(version: N)` after table definitions (tables must exist first because Que's functions reference the `public.que_jobs` type). Any `que_*` table detected as UNLOGGED via `pg_class` is written as `que_create_unlogged_table` instead of `create_table`. GIN indexes on `que_*` tables are detected dynamically and suppressed from the normal table dumps (they are recreated by `que_define_schema`). Fillfactor settings on `que_*` tables are also suppressed.
- **Load:** `db:schema:load` runs your `schema.rb`. The gem adds `que_define_schema(version:)` and `que_create_unlogged_table` to the schema context. `que_define_schema` runs the stored SQL for that version (functions, triggers, indexes, fillfactor, table comment). `que_create_unlogged_table` is implemented as `create_table` + `ALTER TABLE ... SET UNLOGGED`.

No monkey-patching of Que; everything is done by extending ActiveRecord.

## Supported Que versions

- **Que migration version 7** is supported (current).

Support for older migration versions (e.g. 5, 6) can be added later by adding SQL assets under `lib/que_schema/sql/v5`, etc.

## Requirements

- Rails 6.0+
- PostgreSQL (Que is PostgreSQL-only)
- Ruby >= 2.7

## Limitations

- **PostgreSQL only.** The gem does nothing on SQLite/MySQL; it only runs when the adapter is PostgreSQL.
- **UNLOGGED table:** `que_lockers` is created as UNLOGGED. If you run `db:schema:load` against a non-PostgreSQL database, that call would fail (expected).

## Development

### Tests

Uses RSpec. Requires a running PostgreSQL. The test database (`que_schema_test`) is created automatically if it doesn't exist.

```bash
bundle install
bundle exec rake
```

You can set `DATABASE_URL` to point to a different PostgreSQL instance:

```bash
export DATABASE_URL=postgresql://user:pass@host:5432/que_schema_test
bundle exec rake
```

### Adding support for a new Que migration version

1. Add a directory `lib/que_schema/sql/v<N>/` with `functions.sql`, `triggers.sql`, and optionally `down.sql`.
2. Copy the exact `CREATE FUNCTION` / `CREATE TRIGGER` SQL from [que-rb/que](https://github.com/que-rb/que) for that version; use `CREATE OR REPLACE` and `DROP TRIGGER IF EXISTS` for idempotency.
3. Extend the schema dumper version detection if the new version uses a different table comment or detection method.

## License

MIT.
