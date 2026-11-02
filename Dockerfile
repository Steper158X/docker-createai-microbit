# syntax=docker/dockerfile:1

# ---------- Build stage ----------
FROM node:24-bookworm AS build

# Repo/ref to build. Override with --build-arg GIT_REF=v0.7.0 etc.
ARG GIT_REPO=https://github.com/microbit-foundation/ml-trainer.git
ARG GIT_REF=main
# Base path the app is served from, e.g. "/createai/" when behind a sub-path.
ARG BASE_URL=/
# Optional Sentry DSN baked into the bundle (leave empty to disable).
ARG VITE_SENTRY_DSN=

# The project requires npm >= 11.18 (engine-strict, min-release-age).
RUN npm install -g npm@11 --registry=https://registry.npmjs.org

WORKDIR /app
RUN git clone --depth 1 --branch "${GIT_REF}" "${GIT_REPO}" . \
 || (git init . && git remote add origin "${GIT_REPO}" \
     && git fetch --depth 1 origin "${GIT_REF}" && git checkout FETCH_HEAD)

RUN --mount=type=cache,target=/root/.npm npm ci

ENV BASE_URL=${BASE_URL} \
    VITE_SENTRY_DSN=${VITE_SENTRY_DSN} \
    VITE_STAGE=PRODUCTION
RUN npm run build

# ---------- Runtime stage ----------
FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1/healthz || exit 1
