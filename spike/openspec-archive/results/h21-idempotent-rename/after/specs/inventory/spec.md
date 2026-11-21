# inventory Specification

## Purpose
Track stock levels for items so that callers can reserve and release stock without overselling.

## Requirements

### Requirement: Alpha reservation
The system SHALL reserve stock when a reservation is requested.

#### Scenario: Reserve available stock
- **WHEN** a reservation is requested for an item with enough stock
- **THEN** the available count is reduced by the reserved quantity

#### Scenario: Reserve unavailable stock
- **WHEN** a reservation is requested for more than the available stock
- **THEN** the reservation is rejected

### Requirement: Bravo cancellation
The system SHALL release a reservation when it is cancelled.

#### Scenario: Cancel reservation
- **WHEN** a reservation is cancelled
- **THEN** the reserved quantity returns to the available count

### Requirement: Charlie audit log
The system SHALL write an audit entry for every stock change.

#### Scenario: Audit entry written
- **WHEN** the available count changes
- **THEN** an audit entry with the old and new count is stored

### Requirement: Delta export
The system SHALL export the stock table as CSV on request.

#### Scenario: Export requested
- **WHEN** an export is requested
- **THEN** a CSV file with one row per item is produced
