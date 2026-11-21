## ADDED Requirements

### Requirement: Echo low-stock alert
The system SHALL raise an alert when stock falls below the threshold.

#### Scenario: Below threshold
- **WHEN** the available count drops below the threshold
- **THEN** an alert is raised

#### Scenario: At threshold
- **WHEN** the available count equals the threshold
- **THEN** no alert is raised


## REMOVED Requirements

### Requirement: Echo low-stock alert
**Reason**: r
**Migration**: m

