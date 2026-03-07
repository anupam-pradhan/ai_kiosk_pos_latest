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

VERSION="$(read_version)"
if [ -z "${VERSION}" ]; then
  echo "❌ Could not read version from pubspec.yaml"
  exit 1
fi

if [ "${BUILD_RELEASE_AUTO_INCREMENT}" = "true" ]; then
  VERSION="$(bump_build_number "${VERSION}")"
  echo "🔢 Auto-incremented build version to ${VERSION}"
fi

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
