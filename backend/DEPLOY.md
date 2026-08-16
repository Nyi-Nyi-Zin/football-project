# Production API Deployment

The backend is prepared for a Docker-based deployment with managed PostgreSQL. The repository root contains `render.yaml`, which can be imported as a Render Blueprint from the `Nyi-Nyi-Zin/football-project` repository.

After the service is created, confirm that `GET /health` returns `{"status":"healthy"}` and copy the generated HTTPS service URL. The Flutter web build must then be created with:

```bash
flutter build web --release \
  --base-href /football-project/ \
  --dart-define=API_BASE_URL=https://YOUR-BACKEND-HOST/api/v1 \
  --dart-define=WS_BASE_URL=wss://YOUR-BACKEND-HOST
```

The resulting `build/web` directory should be published to the repository's `gh-pages` branch. `API_BASE_URL` must include `/api/v1`; `WS_BASE_URL` must use `wss://` for the HTTPS GitHub Pages site. The backend currently allows cross-origin requests and exposes `/health` for platform health checks.

Do not commit JWT secrets, database credentials, payment-provider keys, or odds-provider keys. Set them as encrypted environment variables in the hosting provider.
