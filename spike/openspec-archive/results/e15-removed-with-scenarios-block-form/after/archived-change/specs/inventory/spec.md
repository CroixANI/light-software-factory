## REMOVED Requirements

### Requirement: Charlie audit log
The system SHALL write an audit entry for every stock change.

#### Scenario: Audit entry written
- **WHEN** the available count changes
- **THEN** an audit entry with the old and new count is stored

