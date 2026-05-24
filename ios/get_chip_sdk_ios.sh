#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# get_chip_sdk_ios.sh
#
# Builds Matter.xcframework from connectedhomeip source and places it at
# ios/Frameworks/Matter.xcframework, ready to link into the Flutter iOS app.
#
# The xcframework bundles two slices:
#   • iphoneos   (arm64)  — physical devices
#   • iphonesimulator (arm64 + x86_64) — Simulator on Apple Silicon + Intel Macs
#
# Usage:
#   bash ios/get_chip_sdk_ios.sh [--build | --ci]
#
#   --build  Clone connectedhomeip, activate build env, and compile with
#            xcodebuild. First-time bootstrap ~5–10 min; compile ~10–30 min.
#            Requires: Xcode 16+, Python 3.10+, CMake 3.25+, Ninja.
#   --ci     Download a pre-built artifact from connectedhomeip GitHub Actions
#            (requires gh CLI + authentication).
#
# Prerequisites (install once):
#   brew install cmake ninja python@3.11
#
# Re-run to get a fresh xcframework after upgrading CHIP_TAG:
#   rm -rf /tmp/connectedhomeip && bash ios/get_chip_sdk_ios.sh --build
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORKS_DIR="$SCRIPT_DIR/Frameworks"
CHIP_REPO="https://github.com/project-chip/connectedhomeip"
CHIP_TAG="${CHIP_TAG:-v1.5.0.0}"   # override: CHIP_TAG=v1.4.2.0 bash ...

mkdir -p "$FRAMEWORKS_DIR"

MODE="${1:---build}"

# ── Helper: resolve python3.10+ ────────────────────────────────────────────
find_python() {
    for candidate in python3.13 python3.12 python3.11 python3.10; do
        if command -v "$candidate" &>/dev/null; then
            echo "$candidate"; return
        fi
    done
    if python3 -c "import sys; assert sys.version_info >= (3,10)" 2>/dev/null; then
        echo "python3"; return
    fi
    echo ""
}

# ── CI download from fluxhome release asset ───────────────────────────────
if [[ "$MODE" == "--ci" ]]; then
    if ! command -v gh &>/dev/null; then
        echo "Error: GitHub CLI (gh) not found. Install from https://cli.github.com/"
        exit 1
    fi
    RELEASE_TAG="chip-sdk-${CHIP_TAG}"
    echo "Downloading Matter.xcframework.zip from $RELEASE_TAG ..."
    TMPDIR_CI=$(mktemp -d)
    gh release download "$RELEASE_TAG" \
        --repo locomuco/fluxhome \
        --pattern "Matter.xcframework.zip" \
        --dir "$TMPDIR_CI"
    echo "Unzipping..."
    unzip -q "$TMPDIR_CI/Matter.xcframework.zip" -d "$TMPDIR_CI"
    if [[ -d "$TMPDIR_CI/Matter.xcframework" ]]; then
        rm -rf "$FRAMEWORKS_DIR/Matter.xcframework"
        cp -R "$TMPDIR_CI/Matter.xcframework" "$FRAMEWORKS_DIR/"
    else
        echo "Error: Matter.xcframework not found in downloaded zip."
        ls "$TMPDIR_CI"
        exit 1
    fi
    rm -rf "$TMPDIR_CI"
    echo "Done. Matter.xcframework placed in $FRAMEWORKS_DIR"
    exit 0
fi

# ── Build from source ──────────────────────────────────────────────────────
if [[ "$MODE" == "--build" ]]; then
    # ── Verify prerequisites ───────────────────────────────────────────────
    echo "Checking prerequisites..."

    if ! command -v xcodebuild &>/dev/null; then
        echo "Error: Xcode not found. Install from the App Store."
        exit 1
    fi
    echo "  Xcode $(xcodebuild -version | head -1 | awk '{print $2}') ✓"

    if ! command -v cmake &>/dev/null; then
        echo "Error: cmake not found. Run: brew install cmake"; exit 1
    fi
    echo "  cmake $(cmake --version | head -1 | awk '{print $3}') ✓"

    if ! command -v ninja &>/dev/null; then
        echo "Error: ninja not found. Run: brew install ninja"; exit 1
    fi
    echo "  ninja $(ninja --version) ✓"

    PYTHON=$(find_python)
    if [[ -z "$PYTHON" ]]; then
        echo "Error: Python 3.10+ not found. Run: brew install python@3.11"; exit 1
    fi
    echo "  $PYTHON ($($PYTHON --version)) ✓"

    # ── Clone or reuse ─────────────────────────────────────────────────────
    WORK_DIR="${CHIP_BUILD_DIR:-/tmp/connectedhomeip}"

    if [[ ! -d "$WORK_DIR/.git" ]]; then
        echo ""
        echo "Cloning connectedhomeip $CHIP_TAG into $WORK_DIR ..."
        rm -rf "$WORK_DIR"
        git clone --depth 1 --branch "$CHIP_TAG" "$CHIP_REPO" "$WORK_DIR"
    else
        echo ""
        echo "Using existing clone at $WORK_DIR"
        echo "  (remove it and re-run to force a fresh clone)"
    fi

    cd "$WORK_DIR"

    # ── Submodules ─────────────────────────────────────────────────────────
    if [[ ! -f "$WORK_DIR/.submodules_synced" ]]; then
        echo ""
        echo "Syncing submodules for Darwin/iOS (shallow)..."
        "$PYTHON" scripts/checkout_submodules.py --shallow --platform darwin --recursive
        touch "$WORK_DIR/.submodules_synced"
    else
        echo "Submodules already synced."
    fi

    # ── Activate CHIP build environment ───────────────────────────────────
    # scripts/activate.sh bootstraps the venv on first run; thereafter we can
    # use .environment/activate.sh directly. Both may set unbound variables so
    # temporarily relax set -u while sourcing.
    echo ""
    set +u
    if [[ -f "$WORK_DIR/.environment/activate.sh" ]]; then
        echo "Activating pre-built CHIP build environment..."
        source "$WORK_DIR/.environment/activate.sh"
    else
        echo "Bootstrapping CHIP build environment (first run, ~5–10 min)..."
        source "$WORK_DIR/scripts/activate.sh"
    fi
    set -u

    # ── Build output dirs ──────────────────────────────────────────────────
    DERIVED_DATA="$WORK_DIR/out/ios-xcframework"
    DEVICE_BUILD="$DERIVED_DATA/Build/Products/Release-iphoneos"
    SIM_BUILD="$DERIVED_DATA/Build/Products/Release-iphonesimulator"
    XCFW_OUT="$WORK_DIR/out/Matter.xcframework"

    # ── Build for iOS device (arm64) ───────────────────────────────────────
    echo ""
    echo "Building Matter.framework for iphoneos (arm64) ..."
    echo "  xcodebuild → Release-iphoneos"
    xcodebuild build \
        -scheme "Matter Framework" \
        -project "$WORK_DIR/src/darwin/Framework/Matter.xcodeproj" \
        -derivedDataPath "$DERIVED_DATA" \
        -sdk iphoneos \
        -configuration Release \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | grep -E "error:|warning: (.*error)|BUILD |Compiling|Linking|CodeSign|\\*\\* BUILD" || true
    echo "  ✅  iphoneos build complete"

    # ── Build for iOS Simulator (arm64 + x86_64) ──────────────────────────
    echo ""
    echo "Building Matter.framework for iphonesimulator (arm64 + x86_64) ..."
    echo "  xcodebuild → Release-iphonesimulator"
    xcodebuild build \
        -scheme "Matter Framework" \
        -project "$WORK_DIR/src/darwin/Framework/Matter.xcodeproj" \
        -derivedDataPath "$DERIVED_DATA" \
        -sdk iphonesimulator \
        -configuration Release \
        ARCHS="arm64 x86_64" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | grep -E "error:|warning: (.*error)|BUILD |Compiling|Linking|CodeSign|\\*\\* BUILD" || true
    echo "  ✅  iphonesimulator build complete"

    # ── Package into Matter.xcframework ───────────────────────────────────
    echo ""
    echo "Packaging Matter.xcframework..."
    rm -rf "$XCFW_OUT"
    xcodebuild -create-xcframework \
        -framework "$DEVICE_BUILD/Matter.framework" \
        -framework "$SIM_BUILD/Matter.framework" \
        -output "$XCFW_OUT"

    # ── Copy to project ────────────────────────────────────────────────────
    echo ""
    echo "Copying to $FRAMEWORKS_DIR ..."
    rm -rf "$FRAMEWORKS_DIR/Matter.xcframework"
    cp -R "$XCFW_OUT" "$FRAMEWORKS_DIR/"

    echo ""
    echo "════════════════════════════════════════════════════"
    echo " ✅  Matter.xcframework placed in:"
    echo "     $FRAMEWORKS_DIR/Matter.xcframework"
    echo ""
    echo " Slices:"
    ls "$FRAMEWORKS_DIR/Matter.xcframework/"
    echo ""
    echo " Next step: build the iOS Flutter target:"
    echo "     flutter build ios --debug"
    echo "════════════════════════════════════════════════════"
    exit 0
fi

echo "Unknown option: $MODE"
echo "Usage: bash get_chip_sdk_ios.sh [--build | --ci]"
exit 1
