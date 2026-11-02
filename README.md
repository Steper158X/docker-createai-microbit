# CreateAI (micro:bit ml-trainer) — offline Docker

[ภาษาไทย](README.th.md)

One image that runs **without internet**: the CreateAI app
([microbit-foundation/ml-trainer](https://github.com/microbit-foundation/ml-trainer))
plus a self-hosted **MakeCode for micro:bit** with the machine-learning extension
bundled. Internet is needed only while building.

```bash
docker compose up -d --build      # first build takes ~10-15 min
```

Open http://localhost:8090 on this machine (MakeCode is at `/makecode/`). Other machines on
the LAN need the HTTPS address to use WebUSB / Web Bluetooth, see [WebUSB (HTTPS)](#webusb-https).

To move it to a machine with no internet:

```bash
docker save createai-microbit:offline -o createai-offline.tar
```

Then on the offline machine:

```bash
docker load -i createai-offline.tar
```

```bash
docker run -d -p 8090:80 -p 8443:443 -e CREATEAI_TLS_HOSTS=192.168.1.10 \
  -v createai-tls:/tls --restart unless-stopped createai-microbit:offline
```

## How it works

| Stage | What it does |
| --- | --- |
| `makecode` | [makecode/build-makecode.sh](makecode/build-makecode.sh): builds `pxt-microbit` with `pxt staticpkg`, adds `pxt-microbit-ml` + `pxt-microbit-ml-runner` as bundled packages (instead of GitHub extensions) and a `createaiprj` template so the C++ native image of the CreateAI project is compiled at build time into `hexcache/`. Telemetry is disabled. |
| `app` | Builds ml-trainer with [patches/ml-trainer-self-hosted-makecode.patch](patches/ml-trainer-self-hosted-makecode.patch), which adds opt-in `VITE_MAKECODE_URL`, `VITE_MAKECODE_RENDER_BLOCKS_URL` and `VITE_MAKECODE_ML_EXTENSION` settings, then removes the microbit.org cookie/analytics script. |
| runtime | nginx serves the app at `/` and MakeCode at `/makecode/`, over HTTP (80) and HTTPS (443). [docker/40-createai-tls.sh](docker/40-createai-tls.sh) prepares the certificate at startup. |

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

## WebUSB (HTTPS)

Browsers only allow WebUSB and Web Bluetooth on `https://` or `localhost`. So that other
machines can connect and flash a micro:bit from the browser, the container also serves
HTTPS on port 8443 with a certificate it generates itself.

1. Put the host's IP in `docker-compose.yml` (names can be added too, comma separated) and start the container:

   ```yaml
   environment:
     CREATEAI_TLS_HOSTS: "192.168.1.10"
   ```

   ```bash
   docker compose up -d
   ```

2. On each client, install the CA once: open **http://&lt;host IP&gt;:8090/rootCA.crt**, open the
   downloaded file, choose **Install Certificate** and store it in "Trusted Root Certification
   Authorities". Or from a command prompt (no admin needed):

   ```bash
   certutil -user -addstore Root rootCA.crt
   ```

3. Open **https://&lt;host IP&gt;:8443** in Chrome or Edge and connect the micro:bit.

How it works:
- On first start the container creates its own CA in the `createai-tls` volume and issues a server
  certificate for `localhost` plus the hosts in `CREATEAI_TLS_HOSTS`. It reissues the certificate
  when the hosts change or it is about to expire.
- The CA can only sign private IPs (`10.x`, `172.16-31.x`, `192.168.x`, `127.x`) and names ending in
  `.local`, `.lan`, `.home.arpa` or `.internal`, so even a leaked key can't impersonate a public
  website. Other hosts in `CREATEAI_TLS_HOSTS` are skipped with a warning.
- Only the CA's public certificate is served. Its SHA-256 fingerprint is in `docker compose logs`,
  to compare against what you install.
- Changing the IPs in `CREATEAI_TLS_HOSTS` doesn't need the CA reinstalled. Removing the volume
  (`docker compose down -v`) creates a new CA, which every client must install again.
- Reserve the host's IP on the router (DHCP reservation) so it doesn't change.
- Allow ports 8090 and 8443 through the host's firewall.
- To use your own certificate (e.g. from mkcert), mount a folder with `cert.pem` and `key.pem` at
  `/certs`, e.g. uncomment `- ./certs:/certs:ro` in `volumes`.
- There is no authentication: use it on the LAN only and don't expose these ports to the internet.

## Limitations offline

- Links to microbit.org (project ideas, lessons, user guide, support) need internet.
- In MakeCode, only the bundled extensions work. Adding other GitHub extensions, or
  extensions with C++ beyond core/radio/microphone/machine-learning, needs the cloud
  compiler. Sharing projects and opening shared links also needs internet.
- Unbranded open-source build (the official micro:bit theme package is private).
