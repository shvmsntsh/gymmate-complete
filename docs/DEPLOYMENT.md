# Deployment

Production uses Vercel with a separate backend deployment and a combined frontend artifact.

| App | Production URL |
| --- | --- |
| Member web | `https://gymmatemvp.vercel.app` |
| Admin web | `https://gymmatemvp.vercel.app/admin` |
| Backend API | `https://gymmate-backend.vercel.app` |

## Standard Production Deploy

From the repo root:

```bash
bash deploy/vercel/deploy_production.sh
```

The script deploys the backend first, then builds the combined frontend artifact:

- Flutter web member app at `/`.
- Vue admin app at `/admin`.
- API rewrite to the backend.

## Local Build Commands

Backend:

```bash
cd gymmate_backend
npm run serve
npm test
```

Admin:

```bash
cd gymmate_admin_vite
npm run dev
npm run build
npm run build:admin
```

Flutter:

```bash
cd gymmate_mobile
flutter build web
```

## Generated Artifacts

Do not commit generated deploy or graph artifacts:

- `deploy/vercel/output/`
- `graphify-out/cache/`

The `.vercel` directories are local deployment links and are intentionally gitignored.

## Deployment QA

Before production deploys, run the focused checks that match the change:

```bash
cd gymmate_backend && npm test
cd gymmate_admin_vite && npm run build
git diff --check
```

For UI changes, also verify `/` and `/admin` visually after deployment. Do not deploy from a dirty branch unless the changed files are intentional.
