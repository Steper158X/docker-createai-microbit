#!/usr/bin/env bash
# Builds a self-hostable static MakeCode for micro:bit with the CreateAI
# machine-learning extensions bundled and their native image pre-compiled.
set -euo pipefail

PXT_MICROBIT_REF="${PXT_MICROBIT_REF:-v9.0.12}"
ML_EXT_REF="${ML_EXT_REF:-v1.0.16}"
ML_RUNNER_REF="${ML_RUNNER_REF:-v0.4.8}"
ROUTE="${MAKECODE_ROUTE:-/makecode/}"
OUT="${OUT:-/out/makecode}"

if [ ! -d /pxt-microbit ]; then
  git clone --depth 1 --branch "$PXT_MICROBIT_REF" https://github.com/microsoft/pxt-microbit.git /pxt-microbit
  (cd /pxt-microbit && npm install --no-audit --no-fund)
fi
cd /pxt-microbit

fetch_lib() { # repo ref dir
  git clone --depth 1 --branch "$2" "https://github.com/microbit-foundation/$1.git" "libs/$3"
  rm -rf "libs/$3/.git" "libs/$3/.github"
}
fetch_lib pxt-microbit-ml "$ML_EXT_REF" machine-learning
fetch_lib pxt-microbit-ml-runner "$ML_RUNNER_REF" machine-learning-runner

# Project template that matches what CreateAI generates (see ml-trainer
# src/makecode/utils.ts). Bundled dirs ending in "prj" get their native
# image written to built/hexcache, which the static editor serves offline.
mkdir -p libs/createaiprj
cat > libs/createaiprj/pxt.json <<'JSON'
{
  "name": "createaiprj",
  "description": "CreateAI offline native image",
  "dependencies": {
    "core": "file:../core",
    "microphone": "file:../microphone",
    "radio": "file:../radio",
    "machine-learning": "file:../machine-learning"
  },
  "files": ["main.ts"],
  "preferredEditor": "blocksprj"
}
JSON
echo "" > libs/createaiprj/main.ts

node - <<'JS'
const fs = require("fs");
// GitHub deps can't be fetched offline; point them at the sibling bundled
// packages the same way the target's own libs reference each other.
for (const dir of ["libs/machine-learning", "libs/machine-learning-runner"]) {
  const f = `${dir}/pxt.json`;
  const cfg = JSON.parse(fs.readFileSync(f, "utf8"));
  for (const k of Object.keys(cfg.dependencies || {})) {
    cfg.dependencies[k] = `file:../${k}`;
  }
  fs.writeFileSync(f, JSON.stringify(cfg, null, 4));
}
const t = JSON.parse(fs.readFileSync("pxtarget.json", "utf8"));
t.bundleddirs.push("libs/machine-learning-runner", "libs/machine-learning", "libs/createaiprj");
fs.writeFileSync("pxtarget.json", JSON.stringify(t, null, 4));
JS

node node_modules/pxt-core/built/pxt.js staticpkg --route "$ROUTE" 2>&1 | tee /tmp/staticpkg.log
if grep -q "INTERNAL ERROR|^error:" /tmp/staticpkg.log; then exit 1; fi

ls built/hexcache

# Disable Application Insights telemetry: pxtweb.js only loads it when
# window.loadAppInsights is defined.
grep -rl "window.loadAppInsights = function" built/packaged --include=*.html   | xargs -r sed -i 's/window\.loadAppInsights = function/window.__pxtTelemetryDisabled = function/'
mkdir -p "$(dirname "$OUT")"
cp -r built/packaged"$ROUTE" "$OUT" 2>/dev/null || cp -r built/packaged "$OUT"
