# Agent-Mediated Withdrawal API

This flow is isolated from admin endpoints and is designed for customer and agent roles.

## Security Notes

- Verification code is generated as 6-character alphanumeric uppercase value.
- Plain verification code is returned once to customer at request creation.
- Database stores only:
  - `verification_code_hash` (bcrypt)
  - `code_lookup_hash` (peppered SHA-256 for indexed lookup)
- Customer account details are encrypted before persistence.

## Environment Variables

- `WITHDRAWAL_CODE_PEPPER` (required in production)
- `WITHDRAWAL_DATA_KEY` (required in production)

## Customer Endpoint

### POST `/api/v1/payments/withdraw`

Creates a pending withdrawal request assigned to a single active agent.

Request body:

```json
{
  "amount": 1000,
  "currency": "USD",
  "payment_method": "manual_agent",
  "account_details": "kpay-09123456789"
}
```

Response `data` includes transaction fields plus:

- `verification_code`: customer-facing 6-character code
- `assigned_agent_id`: agent assigned to this request
- `request_status`: initial request status (`pending`)

## Agent Endpoints

### GET `/api/v1/agent/withdrawals?status=pending&page=1&limit=20`

Returns only withdrawals assigned to authenticated agent.

### POST `/api/v1/agent/withdrawals/verify`

Approves withdrawal by customer code (agent must be assignee).

Request body:

```json
{
  "code": "A1B2C3"
}
```

On success:

- Customer wallet balance is deducted
- Transaction status is set to `completed`
- Withdrawal request status is set to `approved`
- Audit log record is created

## RBAC

- Customer uses `/payments/withdraw`
- Agent uses `/agent/*` endpoints only (`role = agent`)
- Admin endpoints remain separate and are not required for this flow
