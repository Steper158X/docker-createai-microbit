# syntax=docker/dockerfile:1
#
# Fully offline CreateAI (micro:bit ml-trainer) + self-hosted MakeCode.
# Internet is needed at build time only.

# Base path the app is served from, e.g. "/createai/" behind a sub-path.
ARG BASE_URL=/

# ---------- MakeCode (pxt-microbit static package) ----------
FROM node:24-bookworm AS makecode
ARG BASE_URL
ARG PXT_MICROBIT_REF=v9.0.12
# Keep in step with extensionURL in ml-trainer src/makecode/utils.ts.
ARG ML_EXT_REF=v1.0.16
ARG ML_RUNNER_REF=v0.4.8
COPY makecode/build-makecode.sh /build-makecode.sh
RUN sed -i 's/\r$//' /build-makecode.sh \
 && PXT_MICROBIT_REF=${PXT_MICROBIT_REF} ML_EXT_REF=${ML_EXT_REF} ML_RUNNER_REF=${ML_RUNNER_REF} \
    MAKECODE_ROUTE=${BASE_URL}makecode/ OUT=/out/makecode bash /build-makecode.sh

# ---------- CreateAI app ----------
FROM node:24-bookworm AS app
ARG BASE_URL
ARG GIT_REPO=https://github.com/microbit-foundation/ml-trainer.git
ARG GIT_REF=main

# The project requires npm >= 11.18 (engine-strict, min-release-age).
RUN npm install -g npm@11 --registry=https://registry.npmjs.org

WORKDIR /app
RUN git clone --depth 1 --branch "${GIT_REF}" "${GIT_REPO}" . \
 || (git init . && git remote add origin "${GIT_REPO}" \
     && git fetch --depth 1 origin "${GIT_REF}" && git checkout FETCH_HEAD)

# Lets the app point at the self-hosted MakeCode (opt-in via VITE_MAKECODE_*).
COPY patches/ /patches/
RUN git apply /patches/*.patch

RUN --mount=type=cache,target=/root/.npm npm ci

ENV BASE_URL=${BASE_URL} \
    VITE_STAGE=PRODUCTION \
    VITE_MAKECODE_URL=${BASE_URL}makecode/ \
    VITE_MAKECODE_RENDER_BLOCKS_URL=${BASE_URL}makecode/docs.html \
    VITE_MAKECODE_ML_EXTENSION=*
RUN npm run build \
 # microbit.org cookie banner/analytics script: not reachable offline.
 && perl -0pi -e 's#<script[^>]*shared-assets\.microbit\.org[^>]*>\s*</script>##s' dist/index.html \
 && ! grep -q shared-assets dist/index.html

# ---------- Runtime ----------
FROM nginx:1.27-alpine
RUN apk add --no-cache openssl
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/40-createai-tls.sh /docker-entrypoint.d/40-createai-tls.sh
RUN sed -i 's/\r$//' /docker-entrypoint.d/40-createai-tls.sh \
 && chmod +x /docker-entrypoint.d/40-createai-tls.sh
COPY --from=app /app/dist /usr/share/nginx/html
COPY --from=makecode /out/makecode /usr/share/nginx/html/makecode

EXPOSE 80 443
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1/healthz || exit 1
