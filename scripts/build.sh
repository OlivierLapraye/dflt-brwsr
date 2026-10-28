#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIGURATION=${CONFIGURATION:-Release}

# Keep unsigned CI products separate so they cannot replace a working app.
BUILD_MODE=signed
case "${1:-}" in
    "") ;;
    --unsigned) BUILD_MODE=unsigned; shift ;;
    *) printf 'Usage: sh scripts/build.sh [--unsigned]\n' >&2; exit 2 ;;
esac
if [ "$#" -ne 0 ]; then
    printf 'Usage: sh scripts/build.sh [--unsigned]\n' >&2
    exit 2
fi
if [ "$BUILD_MODE" = unsigned ]; then
    DERIVED_DATA_PATH="$PROJECT_ROOT/.build/xcode-unsigned"
    set -- CODE_SIGNING_ALLOWED=NO
else
    DERIVED_DATA_PATH="$PROJECT_ROOT/.build/xcode"
    set --
    if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
        set -- "$@" "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM"
    fi
fi

xcodebuild \
    -project "$PROJECT_ROOT/DefaultBrowser.xcodeproj" \
    -scheme DefaultBrowser \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    "$@" build

BUILT_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Default Browser.app"
if [ "$BUILD_MODE" = signed ]; then
    python3 "$PROJECT_ROOT/scripts/verify-signing.py" "$BUILT_APP"
    printf '\nBuilt app: %s\n' "$BUILT_APP"
else
    printf '\nUnsigned CI build only; cannot run Shortcuts actions: %s\n' "$BUILT_APP"
fi
