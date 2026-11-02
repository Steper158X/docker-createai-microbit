# CreateAI (micro:bit ml-trainer) — offline Docker

[ภาษาไทย](README.th.md)

One image that runs **without internet**: the CreateAI app
([microbit-foundation/ml-trainer](https://github.com/microbit-foundation/ml-trainer))
plus a self-hosted **MakeCode for micro:bit** with the machine-learning extension
bundled. Internet is needed only while building.

```bash
docker compose up -d --build      # first build takes ~10-15 min
```

Open http://localhost:8090 (MakeCode is at `/makecode/`).

To move it to a machine with no internet:

```bash
docker save createai-microbit:offline -o createai-offline.tar
docker load -i createai-offline.tar
docker run -d -p 8090:80 --restart unless-stopped createai-microbit:offline
```

## How it works

| Stage | What it does |
| --- | --- |
| `makecode` | [makecode/build-makecode.sh](makecode/build-makecode.sh): builds `pxt-microbit` with `pxt staticpkg`, adds `pxt-microbit-ml` + `pxt-microbit-ml-runner` as bundled packages (instead of GitHub extensions) and a `createaiprj` template so the C++ native image of the CreateAI project is compiled at build time into `hexcache/`. Telemetry is disabled. |
| `app` | Builds ml-trainer with [patches/ml-trainer-self-hosted-makecode.patch](patches/ml-trainer-self-hosted-makecode.patch), which adds opt-in `VITE_MAKECODE_URL`, `VITE_MAKECODE_RENDER_BLOCKS_URL` and `VITE_MAKECODE_ML_EXTENSION` settings, then removes the microbit.org cookie/analytics script. |
| runtime | nginx serves the app at `/` and MakeCode at `/makecode/`. |

## Build args

| Arg | Default | Purpose |
| --- | --- | --- |
| `GIT_REF` | `main` | ml-trainer branch/tag/commit |
| `GIT_REPO` | upstream | Build a fork |
| `BASE_URL` | `/` | Sub-path behind a reverse proxy, e.g. `/createai/` (trailing slash) |
| `PXT_MICROBIT_REF` | `v9.0.12` | MakeCode for micro:bit version (stable) |
| `ML_EXT_REF` / `ML_RUNNER_REF` | `v1.0.16` / `v0.4.8` | Must match the extension version ml-trainer uses (`src/makecode/utils.ts`) |

If you bump `GIT_REF` and ml-trainer moves to a newer ML extension, bump
`ML_EXT_REF` (and the runner version from that extension's `pxt.json`) to match.

## Limitations offline

- Links to microbit.org (project ideas, lessons, user guide, support) need internet.
- In MakeCode, only the bundled extensions work. Adding other GitHub extensions, or
  extensions with C++ beyond core/radio/microphone/machine-learning, needs the cloud
  compiler. Sharing projects and opening shared links also needs internet.
- WebUSB/Web Bluetooth need a secure context: open it via `localhost` or serve it over
  HTTPS (put a reverse proxy with a certificate in front for classroom LANs).
- Unbranded open-source build (the official micro:bit theme package is private).
