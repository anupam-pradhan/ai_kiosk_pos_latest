#!/bin/bash
set -euo pipefail

if [ -f ".env" ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

BUILD_RELEASE_AUTO_INCREMENT="${BUILD_RELEASE_AUTO_INCREMENT:-true}"
BUILD_RELEASE_ALL_APKS="${BUILD_RELEASE_ALL_APKS:-true}"
BUILD_RELEASE_DEFAULT_MODE="${BUILD_RELEASE_DEFAULT_MODE:-kiosk}"
BUILD_RELEASE_OUTPUT_DIR="${BUILD_RELEASE_OUTPUT_DIR:-release_apks}"
BUILD_RELEASE_NAME_PREFIX="${BUILD_RELEASE_NAME_PREFIX:-megapos}"

# Persistent release signing (prevents update/install conflicts due to key mismatch)
AUTO_CREATE_RELEASE_KEYSTORE="${AUTO_CREATE_RELEASE_KEYSTORE:-true}"
RELEASE_KEYSTORE_PATH="${RELEASE_KEYSTORE_PATH:-android/app/megapos-release.jks}"
RELEASE_KEY_ALIAS="${RELEASE_KEY_ALIAS:-megapos_release}"
RELEASE_STORE_PASSWORD="${RELEASE_STORE_PASSWORD:-change_me_store_password}"
RELEASE_KEY_PASSWORD="${RELEASE_KEY_PASSWORD:-change_me_store_password}"
RELEASE_KEY_VALIDITY_DAYS="${RELEASE_KEY_VALIDITY_DAYS:-9125}"
RELEASE_KEY_DNAME="${RELEASE_KEY_DNAME:-CN=MEGAPOS,OU=Mobile,O=MEGAPOS,L=Bengaluru,ST=Karnataka,C=IN}"

normalize_mode() {
  local raw="$1"
  local normalized
  normalized="$(echo "${raw}" | tr '[:upper:]' '[:lower:]' | tr '-' '_' | tr -d ' ')"

  case "${normalized}" in
    kiosk) echo "kiosk" ;;
    largekiosk|large_kiosk) echo "large_kiosk" ;;
    pos) echo "pos" ;;
    mobilekiosk|mobile_kiosk) echo "mobile_kiosk" ;;
    selection|mode_selection|select)
      echo "selection"
      ;;
    *)
      echo ""
      ;;
  esac
}

read_version() {
  awk '/^version:/{gsub(/[[:space:]]/, "", $2); print $2; exit}' pubspec.yaml
}

bump_build_number() {
  local current_version="$1"
  local base_version build_number new_build_number new_version

  base_version="${current_version%%+*}"
  if [[ "${current_version}" == *"+"* ]]; then
    build_number="${current_version##*+}"
  else
    build_number="0"
  fi

  if ! [[ "${build_number}" =~ ^[0-9]+$ ]]; then
    echo "❌ Invalid build number in pubspec version: ${current_version}"
    exit 1
  fi

  new_build_number=$((build_number + 1))
  new_version="${base_version}+${new_build_number}"

  awk -v new_version="${new_version}" '
    BEGIN { updated = 0 }
    /^version:[[:space:]]*/ && updated == 0 {
      print "version: " new_version
      updated = 1
      next
    }
    { print }
  ' pubspec.yaml > pubspec.yaml.tmp

  mv pubspec.yaml.tmp pubspec.yaml
  echo "${new_version}"
}

is_true() {
  local raw="${1:-false}"
  local normalized
  normalized="$(echo "${raw}" | tr '[:upper:]' '[:lower:]')"
  [[ "${normalized}" == "true" || "${normalized}" == "1" || "${normalized}" == "yes" ]]
}

resolve_store_file_for_gradle() {
  local path="$1"
  if [[ "${path}" = /* ]]; then
    echo "${path}"
    return
  fi

  if [[ "${path}" == android/* ]]; then
    echo "${path#android/}"
    return
  fi

  # key.properties lives in android/, so use parent-relative for root-level paths.
  echo "../${path}"
}

ensure_release_signing() {
  local keystore_abs_path
  local gradle_store_file

  mkdir -p "$(dirname "${RELEASE_KEYSTORE_PATH}")"

  # JDK keytool defaults to PKCS12 where key password matches store password.
  if [ "${RELEASE_KEY_PASSWORD}" != "${RELEASE_STORE_PASSWORD}" ]; then
    echo "⚠️ RELEASE_KEY_PASSWORD must match RELEASE_STORE_PASSWORD for PKCS12 keystores."
    echo "   Using RELEASE_STORE_PASSWORD for both values."
    RELEASE_KEY_PASSWORD="${RELEASE_STORE_PASSWORD}"
  fi

  if [ ! -f "${RELEASE_KEYSTORE_PATH}" ]; then
    if ! is_true "${AUTO_CREATE_RELEASE_KEYSTORE}"; then
      echo "❌ Release keystore not found: ${RELEASE_KEYSTORE_PATH}"
      echo "   Set AUTO_CREATE_RELEASE_KEYSTORE=true or provide existing keystore."
      exit 1
    fi

    if ! command -v keytool >/dev/null 2>&1; then
      echo "❌ keytool not found. Install JDK or create keystore manually."
      exit 1
    fi

    echo "🔐 Creating persistent release keystore: ${RELEASE_KEYSTORE_PATH}"
    keytool -genkeypair \
      -v \
      -keystore "${RELEASE_KEYSTORE_PATH}" \
      -alias "${RELEASE_KEY_ALIAS}" \
      -keyalg RSA \
      -keysize 2048 \
      -validity "${RELEASE_KEY_VALIDITY_DAYS}" \
      -storepass "${RELEASE_STORE_PASSWORD}" \
      -keypass "${RELEASE_KEY_PASSWORD}" \
      -dname "${RELEASE_KEY_DNAME}"
  fi

  keystore_abs_path="$(cd "$(dirname "${RELEASE_KEYSTORE_PATH}")" && pwd)/$(basename "${RELEASE_KEYSTORE_PATH}")"
  gradle_store_file="$(resolve_store_file_for_gradle "${RELEASE_KEYSTORE_PATH}")"

  cat > android/key.properties <<EOF
storePassword=${RELEASE_STORE_PASSWORD}
keyPassword=${RELEASE_KEY_PASSWORD}
keyAlias=${RELEASE_KEY_ALIAS}
storeFile=${gradle_store_file}
EOF

  echo "🔏 Release signing configured"
  echo "   Keystore: ${keystore_abs_path}"
  echo "   Alias: ${RELEASE_KEY_ALIAS}"
}

VERSION="$(read_version)"
if [ -z "${VERSION}" ]; then
  echo "❌ Could not read version from pubspec.yaml"
  exit 1
fi

if [ "${BUILD_RELEASE_AUTO_INCREMENT}" = "true" ]; then
  VERSION="$(bump_build_number "${VERSION}")"
  echo "🔢 Auto-incremented build version to ${VERSION}"
fi

ensure_release_signing

mkdir -p "${BUILD_RELEASE_OUTPUT_DIR}"

declare -a MODES_TO_BUILD=()

if [ "${BUILD_RELEASE_ALL_APKS}" = "true" ]; then
  MODES_TO_BUILD=("kiosk" "large_kiosk" "pos" "mobile_kiosk")
else
  single_mode="$(normalize_mode "${BUILD_RELEASE_DEFAULT_MODE}")"
  if [ -z "${single_mode}" ] || [ "${single_mode}" = "selection" ]; then
    single_mode="$(normalize_mode "${KIOSK_FIXED_MODE:-kiosk}")"
  fi
  if [ -z "${single_mode}" ] || [ "${single_mode}" = "selection" ]; then
    single_mode="kiosk"
  fi
  MODES_TO_BUILD=("${single_mode}")
fi

echo ""
echo "🚀 Release configuration"
echo "   Version: ${VERSION}"
echo "   Auto increment: ${BUILD_RELEASE_AUTO_INCREMENT}"
echo "   Build all APKs: ${BUILD_RELEASE_ALL_APKS}"
echo "   Output dir: ${BUILD_RELEASE_OUTPUT_DIR}"

for mode in "${MODES_TO_BUILD[@]}"; do
  mode_suffix="${mode//_/-}"

  echo ""
  echo "════════════════════════════════════"
  echo "Building mode: ${mode}"
  echo "════════════════════════════════════"

  flutter build apk --release --dart-define=KIOSK_FIXED_MODE="${mode}"

  apk_source="build/app/outputs/flutter-apk/app-release.apk"
  apk_target="${BUILD_RELEASE_OUTPUT_DIR}/${BUILD_RELEASE_NAME_PREFIX}-${mode_suffix}-v${VERSION}.apk"

  if [ ! -f "${apk_source}" ]; then
    echo "❌ APK build output not found at ${apk_source}"
    exit 1
  fi

  cp "${apk_source}" "${apk_target}"
  echo "✅ Created: ${apk_target}"
done

echo ""
echo "✅ Release build complete"
