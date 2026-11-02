# CreateAI (micro:bit ml-trainer) — Docker

Multi-stage image: builds https://github.com/microbit-foundation/ml-trainer with Node 24 / npm 11,
then serves the static `dist/` with nginx (SPA fallback, long cache for `/assets/`, `/healthz`).

## Run

```bash
docker compose up -d --build
```

Open http://localhost:8090

## Build args

| Arg | Default | Purpose |
| --- | --- | --- |
| `GIT_REPO` | upstream repo | Build a fork instead |
| `GIT_REF` | `main` | Branch, tag (e.g. `v0.7.0`) or commit to build |
| `BASE_URL` | `/` | Sub-path when served behind a reverse proxy, e.g. `/createai/` (keep trailing slash) |
| `VITE_SENTRY_DSN` | empty | Optional Sentry error reporting |

```bash
docker build -t createai-microbit --build-arg GIT_REF=main .
docker run -d -p 8090:80 --restart unless-stopped createai-microbit
```

Notes:
- This is the open-source (unbranded) build; the official micro:bit theme package is private.
- WebUSB / Web Bluetooth only work in a secure context: serve it over HTTPS (or `localhost`).
