# billing Specification

## Purpose
Produce invoices for completed orders so that customers are charged exactly once per order.

## Requirements

### Requirement: Invoice creation
The system SHALL create exactly one invoice per completed order and email it.

#### Scenario: Order completed
- **WHEN** an order is completed
- **THEN** exactly one invoice is created and emailed
