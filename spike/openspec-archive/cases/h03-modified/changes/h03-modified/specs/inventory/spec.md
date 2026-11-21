## MODIFIED Requirements

### Requirement: Alpha reservation
The system SHALL reserve stock and also log the reservation id.

#### Scenario: Reserve available stock
- **WHEN** a reservation is requested for an item with enough stock
- **THEN** the available count is reduced and the reservation id is logged

#### Scenario: Reservation id logged
- **WHEN** a reservation succeeds
- **THEN** its id is written to the log

#### Scenario: Reserve unavailable stock
- **WHEN** a reservation is requested for more than the available stock
- **THEN** the reservation is rejected

