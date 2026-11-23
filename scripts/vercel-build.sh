#!/usr/bin/env bash
set -euo pipefail

: "${API_BASE_URL:?Configure API_BASE_URL in the Vercel project settings.}"

case "$API_BASE_URL" in
  https://*) ;;
  *)
    echo "API_BASE_URL must use HTTPS for a Vercel deployment." >&2
    exit 1
    ;;
esac

FLUTTER_VERSION="3.47.5"
FLUTTER_ROOT="${HOME}/.flutter"

if [ ! -x "${FLUTTER_ROOT}/bin/flutter" ]; then
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_ROOT}"
fi

export PATH="${FLUTTER_ROOT}/bin:${PATH}"
flutter config --no-analytics
flutter pub get
flutter build web --release --base-href / \
  --dart-define="API_BASE_URL=${API_BASE_URL%/}"
