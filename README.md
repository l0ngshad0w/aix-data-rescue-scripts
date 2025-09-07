# AIX Data Rescue — Travel VM / Dev Sync Scripts

This repo holds **portable scripts and docs** to keep your SQL Express + Blazor developer environment in sync between your **desk** and **travel** laptops.  It is a sub‑project of **AIX Data Rescue** focused on reliable, repeatable **travel workflows**.

## Why this exists
- Keep code and scripts synced without moving giant VM images.
- Back up "good scripts" in a private, versioned place.
- Make it easy to restore DB and publish artifacts while traveling.
- Avoid committing secrets and oversized binaries.

## Folder structure
```text
/
├─ scripts/
│  ├─ powershell/      # Windows automation, packaging, IIS helpers
│  ├─ sql/             # T‑SQL DDL/DML, migrations, seed data
│  └─ bash/            # Linux/WSL helpers (optional)
├─ config/
│  └─ .env.example     # Sample env vars (copy to .env locally, never commit .env)
├─ tools/              # Small utilities used by scripts
├─ docs/               # Runbooks, checklists, SOPs, screenshots
├─ logs/               # Local run logs (ignored in Git)
└─ temp/               # Scratch/output (ignored in Git)
```

## Quick start
1. Clone this repo using **GitHub Desktop** (recommended) or `git clone`.
2. Copy `config/.env.example` to `.env`, update values for your machine.  **Do not commit `.env`.**
3. Run the scripts you need from `scripts/powershell` (Windows) or `scripts/bash` (WSL/Linux).
4. Commit changes to scripts and docs.  Push to back up and sync to other machines.

## Conventions
- **Commit messages:** use prefixes like `feat:`, `fix:`, `docs:`, `chore:`.
- **Secrets:** never commit keys, passwords, connection strings.  Use `.env` + a password manager.
- **Build artifacts:** do not commit compiled `publish/` outputs.  Rebuild them when needed.
- **SQL style:** tabs for indentation; keep DDL and DML separated by file.

## Travel workflow (high level)
- **Before travel (desk):**
  - Export today’s DB full backup and app publish locally.
  - Sync scripts to this repo (push).
- **While traveling:**
  - Pull latest from repo.
  - Restore DB and deploy publish using scripts.
  - Evolve scripts or schema here; commit and push.
- **On return:**
  - Pull changes on the desk machine and integrate.

> Keep this repo **lightweight**: scripts, SQL, docs.  No large VM images or sensitive data.

## Getting help
- If new to Git, use **GitHub Desktop** for a simple point‑and‑click flow.
- Keep **2FA** enabled on GitHub and prefer **SSH** remotes for pushes.

---

### Maintainer
Josh Hensley
