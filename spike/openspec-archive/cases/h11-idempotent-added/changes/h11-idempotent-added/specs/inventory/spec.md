## ADDED Requirements

### Requirement: Alpha reservation
The system SHALL reserve stock when a reservation is requested.

#### Scenario: Reserve available stock
- **WHEN** a reservation is requested for an item with enough stock
- **THEN** the available count is reduced by the reserved quantity

#### Scenario: Reserve unavailable stock
- **WHEN** a reservation is requested for more than the available stock
- **THEN** the reservation is rejected

