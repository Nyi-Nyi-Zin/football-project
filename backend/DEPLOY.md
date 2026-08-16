# Production API Deployment

The backend is prepared for a Docker-based deployment with managed PostgreSQL. The repository root contains `render.yaml`, which can be imported as a Render Blueprint from the `Nyi-Nyi-Zin/football-project` repository.

After the service is created, confirm that `GET /health` returns `{"status":"healthy"}` and copy the generated HTTPS service URL. The backend automatically imports football fixtures from the keyless OpenLigaDB public API on startup. By default it imports the current Bundesliga season (`OPENLIGADB_LEAGUES=bl1`, `OPENLIGADB_SEASON=2026`) every six hours. You can override these values in Render environment variables; no API key is required for the default fixture feed.

The Flutter web build must then be created with:

```bash
flutter build web --release \
  --base-href /football-project/ \
  --dart-define=API_BASE_URL=https://YOUR-BACKEND-HOST \
  --dart-define=WS_BASE_URL=wss://YOUR-BACKEND-HOST
```

The resulting `build/web` directory should be published to the repository's `gh-pages` branch. The backend migration `000016_add_match_external_fields.sql` must complete before the fixture sync starts because the match repository uses the `external_id` column. `API_BASE_URL` must be the backend host without `/api/v1` because the Flutter client appends that path; `WS_BASE_URL` must use `wss://` for the HTTPS GitHub Pages site. The backend currently allows cross-origin requests and exposes `/health` for platform health checks.

Do not commit JWT secrets, database credentials, payment-provider keys, or odds-provider keys. Set them as encrypted environment variables in the hosting provider.
