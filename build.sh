#!/bin/zsh
set -eu

cd -- "${0:A:h}"
build_mode="${1:-build}"
case "$build_mode" in
    build|test) ;;
    *) printf 'Usage: zsh build.sh [build|test]\n' >&2; exit 2 ;;
esac
build_root="${PRESENTER_BUILD_ROOT:-$PWD/.build}"
build_root="${build_root:A}"
export CLANG_MODULE_CACHE_PATH="$build_root/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"

if ! xcrun --find swiftc >/dev/null 2>&1; then
    printf 'Install Apple Command Line Tools with xcode-select --install, then retry. Swift 6 or later is required.\n' >&2
    exit 1
fi
swift_options=(--scratch-path "$build_root/$build_mode" --cache-path "$build_root/Cache" --config-path "$build_root/Config" --security-path "$build_root/Security")
if [[ "$build_mode" == test ]]; then
    swift_compiler=$(xcrun --find swiftc)
    testing_plugins="${swift_compiler:h:h}/lib/swift/host/plugins/testing"
    # Swift 6.4's Swift Build engine can omit TestingMacros when Core Image overlays are imported.
    if [[ -d "$testing_plugins" ]]; then
        swift_options+=(-Xswiftc -plugin-path -Xswiftc "$testing_plugins")
    fi
    swift test "${swift_options[@]}"
    exit 0
fi
swift build --configuration release "${swift_options[@]}"
binary_directory=$(swift build --configuration release "${swift_options[@]}" --show-bin-path)

mkdir -p Presenter.app/Contents/MacOS
cp Info.plist Presenter.app/Contents/Info.plist
cp "$binary_directory/Presenter" Presenter.app/Contents/MacOS/Presenter
codesign --force --sign - --identifier local.presenter.utility Presenter.app
codesign --verify --strict Presenter.app
printf 'Built %s/Presenter.app\n' "$PWD"
