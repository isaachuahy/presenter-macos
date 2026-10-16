#!/bin/zsh
set -eu

cd -- "${0:A:h}"
launch_app=true
case "${1:-}" in
    '') ;;
    --no-open) launch_app=false ;;
    --help) printf 'Usage: zsh install.sh [--no-open]\nInstalls to ~/Applications, or PRESENTER_INSTALL_DIR when set.\n'; exit 0 ;;
    *) printf 'Usage: zsh install.sh [--no-open]\n' >&2; exit 2 ;;
esac

install_directory="${PRESENTER_INSTALL_DIR:-$HOME/Applications}"
install_directory="${install_directory:A}"
destination="$install_directory/Presenter.app"

check_destination() {
    if [[ -L "$destination" ]]; then
        printf 'Refusing to replace a symlink at %s.\n' "$destination" >&2
        exit 1
    fi
    if [[ -e "$destination" ]]; then
        local identifier
        identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist" 2>/dev/null || true)
        if [[ "$identifier" != local.presenter.utility ]]; then
            printf 'Another app already occupies %s. Choose PRESENTER_INSTALL_DIR.\n' "$destination" >&2
            exit 1
        fi
    fi
    local process_status=0
    /usr/bin/pgrep -x Presenter >/dev/null 2>&1 || process_status=$?
    if (( process_status == 0 )); then
        printf 'Quit Presenter from its menu-bar panel, then run this installer again.\n' >&2
        exit 1
    elif (( process_status != 1 )); then
        printf 'Could not check whether Presenter is running. Installation stopped.\n' >&2
        exit 1
    fi
}

check_destination
zsh build.sh
mkdir -p -- "$install_directory"
staging=$(mktemp -d "$install_directory/.Presenter-install.XXXXXX")
cleanup() {
    if [[ -e "$staging/Previous.app" && ! -e "$destination" ]]; then
        if ! mv -- "$staging/Previous.app" "$destination"; then
            printf 'Previous installation preserved at %s/Previous.app.\n' "$staging" >&2
            return
        fi
    fi
    rm -rf -- "$staging"
}
trap cleanup EXIT
ditto Presenter.app "$staging/Presenter.app"
codesign --verify --strict "$staging/Presenter.app"
check_destination
if [[ -e "$destination" ]]; then
    mv -- "$destination" "$staging/Previous.app"
fi
mv -- "$staging/Presenter.app" "$destination"
printf 'Installed %s\n' "$destination"
if [[ "$launch_app" == true ]]; then
    open "$destination"
    printf 'Click the video icon in the menu bar to open Presenter.\n'
fi
