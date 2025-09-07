# Travel VM / Dev Sync Runbook (Draft)

## Before Travel
- Create a fresh DB full backup on desk laptop.
- Build app publish artifacts.
- Push latest scripts to Git (this repo).

## On Travel Laptop
- Pull latest from Git.
- Restore DB from latest backup available to you.
- Run deploy script for publish artifacts (or rebuild if needed).
- Make improvements; commit and push.

## Upon Return
- Pull on desk laptop; reconcile changes.
- Snapshot working state.
