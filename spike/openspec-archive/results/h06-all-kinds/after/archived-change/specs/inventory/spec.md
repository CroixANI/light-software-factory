## ADDED Requirements

### Requirement: Echo low-stock alert
The system SHALL raise an alert when stock falls below the threshold.

#### Scenario: Below threshold
- **WHEN** the available count drops below the threshold
- **THEN** an alert is raised

#### Scenario: At threshold
- **WHEN** the available count equals the threshold
- **THEN** no alert is raised

### Requirement: Foxtrot stock import
The system SHALL import stock levels from a CSV file.

#### Scenario: Import file
- **WHEN** a CSV file is imported
- **THEN** the stock levels are replaced by the file contents


## MODIFIED Requirements

### Requirement: Bravo cancellation
The system SHALL release a reservation when it is cancelled or expires.

#### Scenario: Cancel reservation
- **WHEN** a reservation is cancelled
- **THEN** the reserved quantity returns to the available count

#### Scenario: Expired reservation
- **WHEN** a reservation passes its expiry time
- **THEN** the reserved quantity returns to the available count

### Requirement: Delta export
The system SHALL export the stock table as CSV or JSON on request.

#### Scenario: Export requested
- **WHEN** an export is requested
- **THEN** a CSV file with one row per item is produced


## REMOVED Requirements

### Requirement: Charlie audit log
**Reason**: Audit moves to a central service.
**Migration**: Read audit entries from the central service.


## RENAMED Requirements

- FROM: `### Requirement: Bravo release`
- TO: `### Requirement: Bravo cancellation`
