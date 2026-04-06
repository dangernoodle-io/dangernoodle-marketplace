#!/usr/bin/env bash
set -euo pipefail

BINARY_DIR="${CLAUDE_PLUGIN_DATA}/bin"
BINARY="${BINARY_DIR}/serial-io-mcp"
REPO="dangernoodle-io/serial-io-mcp"

# Detect OS.
case "$(uname -s)" in
  Darwin) OS="darwin" ;;
  Linux)  OS="linux" ;;
  *)
    echo "serial-io-mcp: unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

# Detect arch.
case "$(uname -m)" in
  x86_64)        ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *)
    echo "serial-io-mcp: unsupported arch: $(uname -m)" >&2
    exit 1
    ;;
esac

# Archive extension per OS.
if [ "$OS" = "darwin" ]; then
  EXT="zip"
else
  EXT="tar.gz"
fi

# Fetch latest release tag.
LATEST_TAG="$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep '"tag_name"' \
  | head -1 \
  | sed 's/.*"tag_name": *"\(.*\)".*/\1/')"

if [ -z "$LATEST_TAG" ]; then
  echo "serial-io-mcp: failed to fetch latest release tag" >&2
  [ -x "$BINARY" ] && exit 0
  exit 1
fi

# Strip leading v for archive naming.
LATEST_VERSION="${LATEST_TAG#v}"

# Check installed version via binary --version output.
INSTALLED_VERSION=""
if [ -x "$BINARY" ]; then
  INSTALLED_VERSION="$("$BINARY" --version 2>/dev/null | tr -d '[:space:]')"
fi

# Skip if up to date.
if [ "$INSTALLED_VERSION" = "$LATEST_VERSION" ] && [ -x "$BINARY" ]; then
  exit 0
fi

echo "serial-io-mcp: installing ${LATEST_VERSION} (${OS}/${ARCH})..."

mkdir -p "$BINARY_DIR"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

BASE_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}"
ARCHIVE_NAME="serial-io-mcp_${LATEST_VERSION}_${OS}_${ARCH}.${EXT}"
CHECKSUM_NAME="serial-io-mcp_${LATEST_VERSION}_SHA256SUMS"

# Download archive and checksums.
curl -sL --fail -o "${WORK_DIR}/${ARCHIVE_NAME}" "${BASE_URL}/${ARCHIVE_NAME}"
curl -sL --fail -o "${WORK_DIR}/${CHECKSUM_NAME}" "${BASE_URL}/${CHECKSUM_NAME}"

# Verify checksum.
(cd "$WORK_DIR" && grep "${ARCHIVE_NAME}" "${CHECKSUM_NAME}" | shasum -a 256 -c -)

# Extract.
if [ "$EXT" = "zip" ]; then
  unzip -qo "${WORK_DIR}/${ARCHIVE_NAME}" -d "${WORK_DIR}/extracted"
else
  mkdir -p "${WORK_DIR}/extracted"
  tar -xzf "${WORK_DIR}/${ARCHIVE_NAME}" -C "${WORK_DIR}/extracted"
fi

# Install binary.
install -m 755 "${WORK_DIR}/extracted/serial-io-mcp" "$BINARY"

echo "serial-io-mcp: installed ${LATEST_VERSION}"
