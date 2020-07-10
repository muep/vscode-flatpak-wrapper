#!@BASH@
# shellcheck shell=bash

set -e
shopt -s nullglob

function msg() {
  echo "@PROGRAM_NAME@-wrapper: $*" >&2
}

function exec_vscode() {
  exec "@EDITOR_BINARY@" \
       --extensions-dir="${XDG_DATA_HOME}/@DATA_DIR_NAME@/extensions" \
       "$@"
}

if [ -n "${FLATPAK_VSCODE_ENV}" ]; then
  msg "Environment is already set up"
  exec_vscode "$@"
fi

declare -A PATH_SUBDIRS
PATH_SUBDIRS[PATH]="bin"
PATH_SUBDIRS[PYTHONPATH]="lib/python@PYTHON_VERSION@/site-packages"
PATH_SUBDIRS[PKG_CONFIG_PATH]="lib/pkgconfig"
PATH_SUBDIRS[GI_TYPELIB_PATH]="lib/girepository-1.0"

function export_path_vars() {
  base_dir="$1"
  for var_name in "${!PATH_SUBDIRS[@]}"; do
    abs_dir="$base_dir/${PATH_SUBDIRS[$var_name]}"
    if [ -d "$abs_dir" ]; then
      msg "Adding $abs_dir to $var_name"
      if [ -z "${!var_name}" ]; then
        export $var_name="$abs_dir"
      else
        export $var_name="${!var_name}:$abs_dir"
      fi
    fi
  done
}

for tool_dir in /app/tools/*; do
  export_path_vars "$tool_dir"
done

if [ "$FLATPAK_ENABLE_SDK_EXT" = "*" ]; then
  SDK=()
  for d in /usr/lib/sdk/*; do
    SDK+=("${d##*/}")
  done
else
  IFS=',' read -ra SDK <<< "$FLATPAK_ENABLE_SDK_EXT"
fi

for i in "${SDK[@]}"; do
  if [[ -d "/usr/lib/sdk/$i" ]]; then
    if [[ -f "/usr/lib/sdk/$i/enable.sh" ]]; then
      msg "Evaluating /usr/lib/sdk/$i/enable.sh"
      # shellcheck source=/dev/null
      . "/usr/lib/sdk/$i/enable.sh"
    else
      export_path_vars "/usr/lib/sdk/$i"
    fi
  else
    msg "Requested SDK extension \"$i\" is not installed"
  fi
done

msg "Setting up Node.js packages"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npmrc"
if [ ! -f "$NPM_CONFIG_USERCONFIG" ]; then
cat <<EOF_NPM_CONFIG > "$NPM_CONFIG_USERCONFIG"
prefix=\${XDG_DATA_HOME}/node
init-module=\${XDG_CONFIG_HOME}/npm-init.js
tmp=\${XDG_CACHE_HOME}/tmp
EOF_NPM_CONFIG
fi
export PATH="$PATH:$XDG_DATA_HOME/node/bin"

msg "Setting up Cargo packages"
export CARGO_INSTALL_ROOT="$XDG_DATA_HOME/cargo"
export CARGO_HOME="$CARGO_INSTALL_ROOT"
export PATH="$PATH:$CARGO_INSTALL_ROOT/bin"

msg "Setting up Python packages"
export PYTHONUSERBASE="$XDG_DATA_HOME/python"
export PATH="$PATH:$PYTHONUSERBASE/bin"

export FLATPAK_VSCODE_ENV=1
exec_vscode "$@"