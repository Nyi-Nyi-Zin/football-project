# Production API Deployment

The backend is prepared for a Docker-based deployment with managed PostgreSQL. The repository root contains `render.yaml`, which can be imported as a Render Blueprint from the `Nyi-Nyi-Zin/football-project` repository.

After the service is created, confirm that `GET /health` returns `{"status":"healthy"}` and copy the generated HTTPS service URL. The backend imports football fixtures from two free public providers on startup. OpenLigaDB supplies Bundesliga fixtures by default (`OPENLIGADB_LEAGUES=bl1`, `OPENLIGADB_SEASON=2026`), while TheSportsDB supplies major-league fixtures using its documented free key (`THESPORTSDB_API_KEY=123`). Both workers run every six hours by default and upsert provider IDs independently, so one provider outage does not stop the other.

The default TheSportsDB league IDs are `4328,4335,4334,4332,4480`, covering Premier League, LaLiga, Ligue 1, Serie A, and Champions League. You can override the provider configuration in Render environment variables:

```text
THESPORTSDB_API_KEY=123
THESPORTSDB_LEAGUE_IDS=4328,4335,4334,4332,4480
THESPORTSDB_SEASON=2026-2027
THESPORTSDB_SYNC_INTERVAL=6h
```

The Flutter web build must then be created with:

```bash
flutter build web --release \
  --base-href /football-project/ \
  --dart-define=API_BASE_URL=https://YOUR-BACKEND-HOST \
  --dart-define=WS_BASE_URL=wss://YOUR-BACKEND-HOST
```

The resulting `build/web` directory should be published to the repository's `gh-pages` branch. The backend migrations `000016_add_match_external_fields.sql` and `000017_restore_wallet_turnover_columns.sql` must complete before production use. The first aligns external fixture IDs with the match repository, and the second aligns wallet persistence with the GORM wallet model. `API_BASE_URL` must be the backend host without `/api/v1` because the Flutter client appends that path; `WS_BASE_URL` must use `wss://` for the HTTPS GitHub Pages site. The backend currently allows cross-origin requests and exposes `/health` for platform health checks.

Do not commit JWT secrets, database credentials, payment-provider keys, or odds-provider keys. Set them as encrypted environment variables in the hosting provider.
