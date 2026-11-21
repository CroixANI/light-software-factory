# billing Specification

## Purpose
Produce invoices for completed orders so that customers are charged exactly once per order.

## Requirements

### Requirement: Invoice creation
The system SHALL create one invoice per completed order.

#### Scenario: Order completed
- **WHEN** an order is completed
- **THEN** exactly one invoice is created for it

### Requirement: Refund
The system SHALL refund a cancelled invoice.

#### Scenario: Cancelled
- **WHEN** an invoice is cancelled
- **THEN** the amount is refunded
