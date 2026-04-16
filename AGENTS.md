# GymMate MVP - Agent Instructions

## Architecture

This is a monorepo with three distinct components:

| Component | Path | Tech | Entry |
|-----------|------|------|-------|
| Backend | `gymmate_backend/` | Express.js + MongoDB | `index.js` (port 5050) |
| Mobile | `gymmate_mobile/` | Flutter | `lib/main.dart` |
| Admin | `gymmate_admin_vite/` | Vue 3 + Vuetify + Vite | `src/main.js` |

## Developer Commands

### Backend
```bash
cd gymmate_backend
npm run serve        # Start local server on port 5050
npm run lint         # Run ESLint
npm run lint:fix     # Fix ESLint issues
npm run seed:demo    # Seed demo data
npm run seed:qa      # Seed QA test data
```

### Mobile
```bash
cd gymmate_mobile
flutter run          # Run on connected device/simulator
flutter build ios    # Build iOS
flutter build web    # Build web
```

### Admin
```bash
cd gymmate_admin_vite
npm run dev          # Start dev server
npm run build        # Build for root (production)
npm run build:admin  # Build for /admin path
```

### Deploy
```bash
bash deploy/vercel/deploy_production.sh
```
Deploys backend first, then builds combined web artifact (Flutter web at `/`, admin at `/admin`, API rewrite to backend).

## Important Details

- **MongoDB**: Local default is `mongodb://127.0.0.1:27017/gymmate` (configured in `gymmate_backend/.env`)
- **JWT Secret**: Default `local-gymmate-secret` (development only)
- **Charts**: Mobile uses local fork at `gymmate_mobile/lib/forks/charts_flutter`
- **Admin base path**: Configurable via `VITE_PUBLIC_BASE` env var; use `build:admin` for `/admin/` prefix
- **Vercel routing**: `gymmate_backend/vercel.json` rewrites all routes to `/api/index.js`

## Linting Rules

Backend uses strict ESLint (`.eslintrc.js`):
- `no-var` (use const/let)
- `eqeqeq` (strict equality)
- `no-undef` (error level)

## Key Files

- `gymmate_backend/app.js` - Express app with all route registrations
- `gymmate_mobile/lib/main.dart` - Flutter app entry point
- `deploy/vercel/assemble_site.sh` - Builds combined Flutter + Admin artifact

## Existing Docs

- `deploy/vercel/README.md` - Deployment details
- `docs/codebase-graph.md` - Codebase knowledge graph
- `.claude/skills/` - Claude Code custom skills