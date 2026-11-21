## added requirements

### Requirement: Echo low-stock alert
The system SHALL raise an alert when stock falls below the threshold.

#### Scenario: Below threshold
- **WHEN** the available count drops below the threshold
- **THEN** an alert is raised

#### Scenario: At threshold
- **WHEN** the available count equals the threshold
- **THEN** no alert is raised

## ADD Requirements

### Requirement: Foxtrot stock import
The system SHALL import stock levels from a CSV file.

#### Scenario: Import file
- **WHEN** a CSV file is imported
- **THEN** the stock levels are replaced by the file contents
