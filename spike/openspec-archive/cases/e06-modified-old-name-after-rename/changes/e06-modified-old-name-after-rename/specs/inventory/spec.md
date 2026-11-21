## RENAMED Requirements

- FROM: `### Requirement: Bravo release`
- TO: `### Requirement: Bravo cancellation`

## MODIFIED Requirements

### Requirement: Bravo release
The system SHALL release a reservation when it is cancelled or expires.

#### Scenario: Cancel reservation
- **WHEN** a reservation is cancelled
- **THEN** the reserved quantity returns to the available count

#### Scenario: Expired reservation
- **WHEN** a reservation passes its expiry time
- **THEN** the reserved quantity returns to the available count

