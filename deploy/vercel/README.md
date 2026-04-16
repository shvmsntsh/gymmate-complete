# GymMate Vercel Production Deploy

Production targets:

- Web and mobile web shell: `https://gymmatemvp.vercel.app`
- Admin web app: `https://gymmatemvp.vercel.app/admin`
- Backend API: `https://gymmate-backend.vercel.app`

Linked Vercel projects:

- Root `.vercel/project.json` deploys `gymmate_mvp`.
- `gymmate_backend/.vercel/project.json` deploys `gymmate-backend`.

Use the production deploy script from the repo root:

```bash
bash deploy/vercel/deploy_production.sh
```

The script deploys the backend first, then runs `deploy/vercel/assemble_site.sh`
to rebuild the combined web artifact under `deploy/vercel/output`, and finally
deploys that artifact to the root production project.

The combined web artifact serves Flutter web at `/`, admin at `/admin`, and
rewrites `/api/*` plus `/health` to `https://gymmate-backend.vercel.app`.

If the Vercel CLI is not installed, the script falls back to:

```bash
npx --yes vercel@latest
```

If the CLI asks for login, complete the Vercel device login in the browser and
rerun the same script.
