# CHANGELOG



## [0.1.3] - 2026-04-01

### Added

- Automatic que-scheduler schema management when que-scheduler gem is present (2bf5b3b)

## [0.1.2] - 2026-03-09

### Added

- Suppress Que-managed functions and triggers in schema dump (629c074)

### Fixed

- Duplicate trigger errors during db:schema:load (629c074)

### Changed

- SchemaDumper prepend timing for correct ancestor order (629c074)
