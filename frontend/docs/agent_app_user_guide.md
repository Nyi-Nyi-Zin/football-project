# Agent App User Guide

## Run Agent App

Use the dedicated entrypoint:

```bash
flutter run -t lib/agent_main.dart
```

## Login

- Sign in using an account with role `agent`.
- Non-agent users are redirected back to login.

## Process Withdrawals

1. Open `Agent Withdrawals`.
2. Review assigned requests in the list.
3. Ask customer for their 6-character verification code.
4. Enter code and tap `Verify & Approve`.
5. System approves request and deducts customer funds automatically.

## Status Filters

- `Pending`: requests waiting for code verification
- `Approved`: processed requests
- `Rejected`: requests rejected through alternate flow

## Security Rules

- Agent can only see requests assigned to that agent.
- Verification succeeds only if code matches an assigned pending request.
- Every approval action is audit logged server-side.
