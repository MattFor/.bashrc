# ~/.bashrc

# Exit early for non-interactive shells
[[ $- != *i* ]] && return

# History
HISTSIZE=1000000
HISTFILESIZE=2000000

# Terminal
export TERM=xterm-256color

# Load secrets
if [ -f "$HOME/.config/secrets/env" ]; then
  source "$HOME/.config/secrets/env"
fi

### System utilities

install() {
	sudo xbps-install -S "$@"
}

remove() {
	sudo xbps-remove -R "$@"
}

removeoldkernels() {
	sudo vkpurge rm all
}

update() {
	sudo xbps-install -Syu
}

mvp() {
	rsync -ah --progress "$@"
}

mvpr() {
	rsync -ah --progress --remove-source-files "$@"
}

reloadcaddy() {
    sudo caddy fmt --overwrite /etc/caddy/Caddyfile && \
    sudo caddy validate --config /etc/caddy/Caddyfile && \
    sudo caddy reload --config /etc/caddy/Caddyfile
}

copy() {
  if [ ! -t 0 ]; then
    xclip -selection clipboard -in
    return $?
  fi

  if [ $# -gt 0 ]; then
    case "${1,,}" in
      *.png)  xclip -selection clipboard -t image/png  -in "$1" ;;
      *.jpg|*.jpeg) xclip -selection clipboard -t image/jpeg -in "$1" ;;
      *.webp) xclip -selection clipboard -t image/webp -in "$1" ;;
      *) cat "$@" | xclip -selection clipboard -in ;;
    esac
    return $?
  fi

  echo "Usage:"
  echo "  command | copy"
  echo "  copy file1 [file2 ...]"
  return 1
}

topdf() {
    if [ $# -eq 0 ]; then
        echo "Usage: topdf file.odt [file2.odt ...]"
        return 1
    fi

    for file in "$@"; do
        if [ ! -f "$file" ]; then
            echo "File not found: $file"
            continue
        fi

        soffice --headless --nologo --nofirststartwizard --convert-to pdf "$file"
    done
}

rmexif() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: rmexif <file(s)>"
    return 1
  fi

  exiftool -all= -overwrite_original "$@"
}

compress() {
    local algo="$1"
    shift || true

    local use_password=0

    usage() {
        cat <<'EOF'
Usage:
  compress <xz|gz|gzip|zstd|bz2|bzip2|lz4|zip|rar|7z> [pass] <files-or-folders...>

Examples:
  compress xz folder
  compress zstd photos/
  compress zip pass folder
  compress rar pass folder
  compress 7z pass folder
EOF
    }

    if [[ -z "$algo" || "$algo" == "-h" || "$algo" == "--help" ]]; then
        usage
        return 1
    fi

    if [[ "${1:-}" == "pass" ]]; then
        use_password=1
        shift
    fi

    if [[ $# -eq 0 ]]; then
        usage
        return 1
    fi

    local out tmp

    case "$algo" in
        xz|best)
            if [[ $use_password -eq 1 ]]; then
                echo "Password protection is not supported for xz archives."
                return 1
            fi
            out="archive.tar.xz"
            tmp="${out}.tmp"
            tar --exclude="$out" --exclude="$tmp" -cvf "$tmp" -I 'xz -9e --threads=0' "$@"
            mv -f "$tmp" "$out"
            ;;

        gz|gzip)
            if [[ $use_password -eq 1 ]]; then
                echo "Password protection is not supported for gzip archives."
                return 1
            fi
            out="archive.tar.gz"
            tmp="${out}.tmp"
            tar --exclude="$out" --exclude="$tmp" -cvf "$tmp" -I 'gzip -9' "$@"
            mv -f "$tmp" "$out"
            ;;

        zstd)
            if [[ $use_password -eq 1 ]]; then
                echo "Password protection is not supported for zstd archives."
                return 1
            fi
            out="archive.tar.zst"
            tmp="${out}.tmp"
            tar --exclude="$out" --exclude="$tmp" -cvf "$tmp" -I 'zstd -19 -T0' "$@"
            mv -f "$tmp" "$out"
            ;;

        bz2|bzip2)
            if [[ $use_password -eq 1 ]]; then
                echo "Password protection is not supported for bzip2 archives."
                return 1
            fi
            out="archive.tar.bz2"
            tmp="${out}.tmp"
            tar --exclude="$out" --exclude="$tmp" -cvf "$tmp" -I 'bzip2 -9' "$@"
            mv -f "$tmp" "$out"
            ;;

        lz4)
            if [[ $use_password -eq 1 ]]; then
                echo "Password protection is not supported for lz4 archives."
                return 1
            fi
            out="archive.tar.lz4"
            tmp="${out}.tmp"
            tar --exclude="$out" --exclude="$tmp" -cvf "$tmp" -I 'lz4 -9' "$@"
            mv -f "$tmp" "$out"
            ;;

        zip)
            out="archive.zip"
            if [[ $use_password -eq 1 ]]; then
                zip -e -r "$out" "$@"
            else
                zip -r "$out" "$@"
            fi
            ;;

        rar)
            out="archive.rar"
            if [[ $use_password -eq 1 ]]; then
                rar a -hp "$out" "$@"
            else
                rar a "$out" "$@"
            fi
            ;;

        7z)
            out="archive.7z"
            if [[ $use_password -eq 1 ]]; then
                7z a -t7z -mx=9 -mhe=on -p "$out" "$@"
            else
                7z a -t7z -mx=9 "$out" "$@"
            fi
            ;;

        *)
            echo "Unknown compression: $algo"
            usage
            return 1
            ;;
    esac
}

md() {
    if [ -t 0 ]; then
        mdcat "$@" | less -R
    else
        mdcat | less -R
    fi
}

peek() {
    if [[ $# -lt 1 ]]; then
        printf 'Usage: peek <archive>\n' >&2
        return 2
    fi

    local file="$1"
    if [[ ! -e "$file" ]]; then
        printf 'peek: file not found: %s\n' "$file" >&2
        return 2
    fi

    local mime=""
    if command -v file >/dev/null 2>&1; then
        mime=$(file -Lb --mime-type "$file" 2>/dev/null || true)
    fi

    case "$mime" in
        application/zip)
            if command -v unzip >/dev/null 2>&1; then
                unzip -l -- "$file"
            else
                printf 'peek: unzip not installed\n' >&2
                return 4
            fi
            return $?
            ;;

        application/vnd.rar|application/x-rar|application/x-rar-compressed)
            if command -v unrar >/dev/null 2>&1; then
                unrar l -- "$file"
            elif command -v rar >/dev/null 2>&1; then
                rar l -- "$file"
            else
                printf 'peek: rar/unrar not installed\n' >&2
                return 4
            fi
            return $?
            ;;

        application/x-7z-compressed)
            if command -v 7z >/dev/null 2>&1; then
                7z l -- "$file"
            else
                printf 'peek: 7z not installed\n' >&2
                return 4
            fi
            return $?
            ;;

        application/gzip|application/x-gzip)
            tar -tvzf "$file"; return $? ;;
        application/x-bzip2)
            tar -tvjf "$file"; return $? ;;
        application/x-xz|application/x-compress*|application/x-lzip)
            tar -tvJf "$file"; return $? ;;
        application/x-lz4|application/lz4)
            if tar --help 2>&1 | grep -q -- '-I '; then
                tar -I 'lz4 -d -c' -tvf "$file"
            elif command -v lz4 >/dev/null 2>&1; then
                lz4 -d -c -- "$file" | tar -tvf -
            else
                printf 'peek: lz4 support missing (install lz4)\n' >&2
                return 4
            fi
            return $?
            ;;
        application/x-zstd|application/zstd)
            if tar --help 2>&1 | grep -q -- '-I '; then
                tar -I 'zstd -d -c' -tvf "$file"
            elif command -v zstd >/dev/null 2>&1; then
                zstd -d -c -- "$file" | tar -tvf -
            else
                printf 'peek: zstd support missing (install zstd)\n' >&2
                return 4
            fi
            return $?
            ;;
        application/x-tar)
            tar -tvf -- "$file"; return $? ;;
    esac

    case "$file" in
        *.zip)
            command -v unzip >/dev/null && unzip -l -- "$file" && return 0
            ;;
        *.rar)
            if command -v unrar >/dev/null; then
                unrar l -- "$file" && return 0
            elif command -v rar >/dev/null; then
                rar l -- "$file" && return 0
            fi
            ;;
        *.7z|*.7z.001)
            if command -v 7z >/dev/null 2>&1; then
                7z l -- "$file" && return 0
            fi
            ;;
        *.tar.gz|*.tgz) tar -tvzf "$file"; return $? ;;
        *.tar.bz2|*.tbz2) tar -tvjf "$file"; return $? ;;
        *.tar.xz|*.txz) tar -tvJf "$file"; return $? ;;
        *.tar.lz4|*.tlz4)
            if command -v lz4 >/dev/null 2>&1; then
                lz4 -d -c -- "$file" | tar -tvf - && return 0
            fi
            ;;
        *.tar.zst|*.tzst)
            if command -v zstd >/dev/null 2>&1; then
                zstd -d -c -- "$file" | tar -tvf - && return 0
            fi
            ;;
        *.tar) tar -tvf "$file"; return $? ;;
    esac

    printf 'peek: unknown format or missing tools\n' >&2
    return 5
}

### Programming help

activate() {
  local venv_dir="${1:-.venv}"
  local pybin=""

  if [ ! -d "$venv_dir" ]; then
    if command -v python3 >/dev/null 2>&1; then
      pybin="python3"
    elif command -v python >/dev/null 2>&1; then
      pybin="python"
    else
      echo "No python or python3 found."
      return 1
    fi

    echo "Creating virtual environment in: $venv_dir"
    "$pybin" -m venv "$venv_dir" || return 1
  fi

  if [ ! -f "$venv_dir/bin/activate" ]; then
    echo "Found '$venv_dir', but it does not look like a valid venv."
    return 1
  fi

  source "$venv_dir/bin/activate"
}

workon() {
  activate ".venv"
}

gitgraph() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository."
    return 1
  fi

  echo "=== Commit graph ==="
  git log --graph --decorate=full --all --boundary --date-order \
    --pretty=format:'%C(auto)%h%Creset %C(bold blue)%d%Creset %s %Cgreen(%cr)%Creset %C(dim white)- %an%Creset' \
    --abbrev-commit

  echo
  echo "=== Reflog (checkout / branch creation history) ==="
  git reflog --all --date=relative \
    --pretty=format:'%C(auto)%h%Creset %C(yellow)%gd%Creset %gs %Cgreen(%cr)%Creset' 2>/dev/null
}

gitrecurse() {
    local msg="${1:-update}"

    gitrecurse-repo "$msg"

    git submodule foreach --recursive "gitrecurse-repo '$msg'"
}

relaxy-dl() {
    if [ $# -lt 1 ]; then
        echo "Usage: relaxy-dl <remote_file> [local_path]"
        return 1
    fi

    local remote_file="$1"
    local dest="${2:-.}"

    scp -O -i "$___rel_key" "$___rel_host:$___rel_base/$remote_file" "$dest"
}

relaxy-ls() {
    "$___rel_ssh" "ls /home/server/relaxy-private/${1:-}"
}

_tar_from_stdin() {
	tar -tvf - 2>/dev/null || { printf 'tpeek: tar failed to read from stdin\n' >&2; return 3; }
}

_llm_models() {
  ollama list 2>/dev/null | awk 'NR > 1 && $1 != "" {print $1}'
}

_llm_ensure_server() {
  if ollama list >/dev/null 2>&1; then
    return 0
  fi

  nohup ollama serve >/tmp/ollama-serve.log 2>&1 &
  local i
  for i in $(seq 1 30); do
    ollama list >/dev/null 2>&1 && return 0
    sleep 1
  done

  echo "ollama server did not start. Check /tmp/ollama-serve.log" >&2
  return 1
}

_llm_pick_model() {
  local query="$1"
  local models matched

  models="$(_llm_models)"
  if [ -z "$models" ]; then
    return 1
  fi

  if command -v fzf >/dev/null 2>&1; then
    if [ -n "$query" ]; then
      matched="$(printf '%s\n' "$models" | fzf --query "$query" --select-1 --exit-0 2>/dev/null)"
    else
      matched="$(printf '%s\n' "$models" | fzf --select-1 --exit-0 2>/dev/null)"
    fi
    [ -n "$matched" ] && { printf '%s\n' "$matched"; return 0; }
  fi

  if [ -n "$query" ]; then
    matched="$(printf '%s\n' "$models" | awk -v q="$query" '
      BEGIN { ql=tolower(q); best=""; }
      {
        l=tolower($0)
        if (l == ql) { print; exit }
        if (index(l, ql) == 1 && best == "") best = $0
        else if (index(l, ql) > 0 && best == "") best = $0
      }
      END { if (best != "") print best }')"
    [ -n "$matched" ] && { printf '%s\n' "$matched"; return 0; }
  fi

  return 1
}

llmon() {
  local query="$*"
  local model
  local models

  if ! _llm_ensure_server; then
    return 1
  fi

  models="$(_llm_models)"
  if [ -z "$models" ]; then
    echo "No models installed yet."
    echo "Install one with: ollama pull <model>"
    return 1
  fi

  if [ -z "$query" ]; then
    echo "Installed models:"
    printf '  %-32s %s\n' "MODEL" "LAUNCH"
    printf '  %-32s %s\n' "-----" "------"
    while IFS= read -r model; do
      [ -n "$model" ] && printf '  %-32s %s\n' "$model" "ollama run $model"
    done <<EOF
$models
EOF
    echo
    echo "Use: llmon <part-of-name>"
    echo "Example: llmon deepseek"
    return 0
  fi

  model="$(_llm_pick_model "$query")"
  if [ -z "$model" ]; then
    echo "No installed model matched: $query" >&2
    echo
    echo "Installed models:"
    printf '%s\n' "$models" | sed 's/^/  - /'
    return 1
  fi

  echo "Launching: ollama run $model"
  ollama run "$model"
}

llmoff() {
  local running

  running="$(ollama ps 2>/dev/null | awk 'NR > 1 && $1 != "" {print $1}')"
  if [ -n "$running" ]; then
    while IFS= read -r model; do
      [ -n "$model" ] && ollama stop "$model" >/dev/null 2>&1
    done <<EOF
$running
EOF
  fi

  # Then stop the server.
  pkill -x ollama >/dev/null 2>&1 || true

  echo "Ollama stopped."
}

c() {
  if [ $# -eq 0 ]; then
    echo "Usage: c [v|vv|vvv|sv|svv|svvv|dbg|sdbg] file1.cpp [file2.cpp ...]"
    return 1
  fi

  search=false
  verbosity=1
  dbg=false

  token="$1"
  case "$token" in
    sdbg|SDBG|Sdbg)
      search=true; dbg=true; shift ;;
    dbg|gdb|debug)
      dbg=true; shift ;;
    svv|svvv|sv)
      rest="${token#s}"
      verbosity=${#rest}
      search=true
      shift ;;
    vvv|vv|v)
      verbosity=${#token}
      shift ;;
    *)
      if [ -f "$token" ] || [[ "$token" == *.cpp || "$token" == *.cc || "$token" == *.cxx || "$token" == *.c++ ]]; then
        verbosity=1
        search=false
      fi
      ;;
  esac

  if [ $# -eq 0 ]; then
    echo "Error: no source file given."
    return 1
  fi

  files=( "$@" )
  main="${files[0]}"
  output="${main%.*}"

  std_flag="-std=gnu++26"
  common_opts=( -pipe )

  driver_verbose=()
  linker_verbose=()
  warn_flags=()
  extra_flags=()
  sanitizer_flags=()
  debug_flags=()

  if [ "$dbg" = true ]; then
    debug_flags=( -g -O0 -ggdb -fno-omit-frame-pointer -rdynamic )
    warn_flags=( -Wall -Wextra -Wpedantic )
  else
    case "$verbosity" in
      1)
        warn_flags=( -Wall -Wextra )
        extra_flags=( -O2 )
        ;;
      2)
        warn_flags=( -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion -Wformat=2 -Wnull-dereference -Wdouble-promotion )
        extra_flags=( -O2 -ftemplate-backtrace-limit=0 -fconcepts-diagnostics-depth=10 )
        ;;
      3)
        warn_flags=( -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion -Wformat=2 -Wnull-dereference -Wdouble-promotion -Wold-style-cast -Wcast-align -Wformat-security -Wredundant-decls -Wlogical-op -Werror )
        extra_flags=( -O2 -g -ftemplate-backtrace-limit=0 -fconcepts-diagnostics-depth=10 )
        sanitizer_flags=( -fsanitize=address,undefined -fno-omit-frame-pointer )
        ;;
      *)
        warn_flags=( -Wall -Wextra )
        extra_flags=( -O2 )
        ;;
    esac
  fi

  if [ "$search" = true ]; then
    driver_verbose=( -v )
    linker_verbose=( -Wl,--verbose )
  fi

  cmd=( g++ "$std_flag" "${common_opts[@]}" "${warn_flags[@]}" "${extra_flags[@]}" )

  if [ "$dbg" = true ]; then
    cmd+=( "${debug_flags[@]}" )
  fi

  if [ "${#sanitizer_flags[@]}" -ne 0 ] && [ "$dbg" != true ]; then
    cmd+=( "${sanitizer_flags[@]}" )
  fi

  if [ "${#driver_verbose[@]}" -ne 0 ]; then
    cmd+=( "${driver_verbose[@]}" )
  fi

  cmd+=( "${files[@]}" )

  if [ "${#linker_verbose[@]}" -ne 0 ]; then
    cmd+=( "${linker_verbose[@]}" )
  fi

  cmd+=( -o "$output" )

  printf 'Compiling: %s\n' "${cmd[*]}"
  "${cmd[@]}"
}

rustdoc_search() {
  for cmd in rg fzf bat w3m; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf 'Error: required command not found: %s\n' "$cmd" >&2
      return 127
    fi
  done

  local MODE=""
  local BROWSER_MODE=0
  local DOC_BASE TOOLCHAIN
  local RBE INTRO BOOK REF STD
  local QUERY lc
  local DOC_TMPLIST
  local DOC_SELECTED_LINE DOC_SELECTED_REL DOC_SELECTED_ABS

  if [ "$1" = "i" ]; then
    BROWSER_MODE=1
    shift
  fi

  if [ "$1" = "c" ] || [ "$1" = "cc" ]; then
    MODE="$1"
    shift

    if [ -z "$1" ]; then
      printf 'Usage: rdoc %s <crate-name>\n' "$MODE" >&2
      return 2
    fi

    local crate="$1"
    local docs_url="https://docs.rs/${crate}/latest/"
    local crates_url="https://crates.io/crates/${crate}"

    if [ "$MODE" = "cc" ]; then
      if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$docs_url" >/dev/null 2>&1 &
        return 0
      else
        w3m "$docs_url" || w3m "$crates_url"
        return 0
      fi
    else
      if command -v xmllint >/dev/null 2>&1; then
        local tmp frag
        tmp="$(mktemp --suffix=.html)" || tmp="/tmp/rdoc.$$"
        frag="$(mktemp --suffix=.html)" || frag="/tmp/rdoc_frag.$$"

        if curl -Ls "$docs_url" | xmllint --html --xpath '//main' - 2>/dev/null >"$frag"; then
          {
            printf '%s\n' '<!doctype html><html><head>'
            printf '%s\n' "<base href=\"$docs_url\">"
            printf '%s\n' '</head><body>'
            cat "$frag"
            printf '%s\n' '</body></html>'
          } >"$tmp"
          w3m -T text/html "$tmp"
        else
          curl -Ls "$docs_url" >"$tmp"
          if command -v perl >/dev/null 2>&1; then
            perl -0777 -pe "s/(<head[^>]*>)/\$1<base href=\"$docs_url\">/i" "$tmp" >"${tmp}.withbase" && mv "${tmp}.withbase" "$tmp"
          else
            sed -E "0,/<head[^>]*>/s//&<base href=\"$docs_url\">/" "$tmp" >"${tmp}.withbase" 2>/dev/null && mv "${tmp}.withbase" "$tmp" || true
          fi
          w3m -T text/html "$tmp"
        fi

        rm -f "$frag" "$tmp"
      else
        w3m "$docs_url"
      fi
      return 0
    fi
  fi

  TOOLCHAIN="$(rustup show active-toolchain 2>/dev/null | awk '{print $1}' || true)"
  if [ -n "$TOOLCHAIN" ]; then
    DOC_BASE="$HOME/.rustup/toolchains/$TOOLCHAIN/share/doc/rust/html"
  fi

  if [ -z "$DOC_BASE" ] || [ ! -d "$DOC_BASE" ]; then
    DOC_BASE="$(find "$HOME/.rustup/toolchains" -type d -path '*/share/doc/rust/html' 2>/dev/null | head -n1 || true)"
  fi

  if [ -z "$DOC_BASE" ] || [ ! -d "$DOC_BASE" ]; then
    printf 'Rust docs not found under %s. Install with rustup component add rust-docs or point DOC_BASE manually.\n' "$HOME/.rustup/toolchains" >&2
    return 1
  fi

  RBE="$DOC_BASE/rust-by-example/index.html"
  INTRO="$DOC_BASE/rust-by-example/hello.html"
  BOOK="$DOC_BASE/book/index.html"
  REF="$DOC_BASE/reference/index.html"
  STD="$DOC_BASE/std/index.html"

  QUERY="$*"
  lc="${QUERY,,}"

  if [ -z "$QUERY" ]; then
    if [ -f "$RBE" ]; then
      if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$RBE" >/dev/null 2>&1 &
        return 0
      else
        w3m "$RBE"
        return 0
      fi
    else
      printf 'Rust By Example not found at: %s\n' "$RBE" >&2
      return 1
    fi
  fi

  case "$lc" in
    intro|introduction)
      if [ -f "$INTRO" ]; then
        if command -v xdg-open >/dev/null 2>&1; then
          xdg-open "$INTRO" >/dev/null 2>&1 &
          return 0
        else
          w3m "$INTRO"
          return 0
        fi
      fi
      ;;
    book)
      if [ -f "$BOOK" ]; then
        if command -v xdg-open >/dev/null 2>&1; then
          xdg-open "$BOOK" >/dev/null 2>&1 &
          return 0
        else
          w3m "$BOOK"
          return 0
        fi
      fi
      ;;
    reference|ref)
      if [ -f "$REF" ]; then
        if command -v xdg-open >/dev/null 2>&1; then
          xdg-open "$REF" >/dev/null 2>&1 &
          return 0
        else
          w3m "$REF"
          return 0
        fi
      fi
      ;;
    std|standard|library)
      if [ -f "$STD" ]; then
        if command -v xdg-open >/dev/null 2>&1; then
          xdg-open "$STD" >/dev/null 2>&1 &
          return 0
        else
          w3m "$STD"
          return 0
        fi
      fi
      ;;
    by-example|rbe)
      if [ -f "$RBE" ]; then
        if command -v xdg-open >/dev/null 2>&1; then
          xdg-open "$RBE" >/dev/null 2>&1 &
          return 0
        else
          w3m "$RBE"
          return 0
        fi
      fi
      ;;
  esac

  local files=()
  mapfile -t files < <(
    rg -l --hidden --color=never -S --no-messages \
      --glob '!.git' --glob '!target' --glob '!**/node_modules/**' \
      -- "$QUERY" "$DOC_BASE" 2>/dev/null
  )

  if [ ${#files[@]} -eq 0 ]; then
    printf 'No matches found in %s for: %s\n' "$DOC_BASE" "$QUERY" >&2
    return 1
  fi

  local filtered=()
  local DOC_ABS_PATH DOC_REL_PATH DOC_SKIP DOC_COMP
  local IFS

  for DOC_ABS_PATH in "${files[@]}"; do
    if [ "$DOC_ABS_PATH" = "$DOC_BASE" ]; then
      DOC_REL_PATH="$(basename "$DOC_ABS_PATH")"
    else
      DOC_REL_PATH="${DOC_ABS_PATH#"$DOC_BASE"/}"
    fi

    DOC_SKIP=0
    IFS='/'
    read -r -a DOC_COMPS <<<"$DOC_REL_PATH"
    for DOC_COMP in "${DOC_COMPS[@]}"; do
      if [[ "$DOC_COMP" =~ ^[a-z]{2}$ && "$DOC_COMP" != "en" ]]; then
        DOC_SKIP=1
        break
      fi
    done

    if [ "$DOC_SKIP" -eq 0 ]; then
      filtered+=("$DOC_ABS_PATH")
    fi
  done

  if [ ${#filtered[@]} -gt 0 ]; then
    files=("${filtered[@]}")
  fi

  if [ ${#files[@]} -eq 0 ]; then
    printf 'No matches found in %s for: %s\n' "$DOC_BASE" "$QUERY" >&2
    return 1
  fi

  DOC_TMPLIST="$(mktemp)" || DOC_TMPLIST="/tmp/rdoc_list.$$"

  local DOC_DISPLAY_PATH
  for DOC_ABS_PATH in "${files[@]}"; do
    if [ "$DOC_ABS_PATH" = "$DOC_BASE" ]; then
      DOC_REL_PATH="$(basename "$DOC_ABS_PATH")"
    else
      DOC_REL_PATH="${DOC_ABS_PATH#"$DOC_BASE"/}"
    fi
    DOC_DISPLAY_PATH="$DOC_REL_PATH"
    printf '%s\t%s\n' "$DOC_DISPLAY_PATH" "$DOC_ABS_PATH" >>"$DOC_TMPLIST"
  done

  rdoc_open_html() {
    local DOC_OPEN_ABS="$1"
    local DOC_OPEN_DIR DOC_OPEN_BASE DOC_OPEN_TMP DOC_OPEN_FRAG

    DOC_OPEN_DIR="$(dirname "$DOC_OPEN_ABS")"
    DOC_OPEN_BASE="file://$DOC_OPEN_DIR/"

    if [ "$BROWSER_MODE" -eq 1 ] && command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$DOC_OPEN_ABS" >/dev/null 2>&1 &
      return 0
    fi

    if ! command -v xmllint >/dev/null 2>&1; then
      w3m "$DOC_OPEN_ABS"
      return 0
    fi

    DOC_OPEN_TMP="$(mktemp --suffix=.html)" || DOC_OPEN_TMP="/tmp/rdoc_open.$$"
    DOC_OPEN_FRAG="$(mktemp --suffix=.html)" || DOC_OPEN_FRAG="/tmp/rdoc_open_frag.$$"

    if xmllint --html --xpath '//main' "$DOC_OPEN_ABS" 2>/dev/null >"$DOC_OPEN_FRAG"; then
      {
        printf '%s\n' '<!doctype html><html><head>'
        printf '%s\n' "<base href=\"$DOC_OPEN_BASE\">"
        printf '%s\n' '</head><body>'
        cat "$DOC_OPEN_FRAG"
        printf '%s\n' '</body></html>'
      } >"$DOC_OPEN_TMP"
      w3m -T text/html "$DOC_OPEN_TMP"
      rm -f "$DOC_OPEN_FRAG" "$DOC_OPEN_TMP"
      return 0
    fi

    if xmllint --html --xpath '//article' "$DOC_OPEN_ABS" 2>/dev/null >"$DOC_OPEN_FRAG"; then
      {
        printf '%s\n' '<!doctype html><html><head>'
        printf '%s\n' "<base href=\"$DOC_OPEN_BASE\">"
        printf '%s\n' '</head><body>'
        cat "$DOC_OPEN_FRAG"
        printf '%s\n' '</body></html>'
      } >"$DOC_OPEN_TMP"
      w3m -T text/html "$DOC_OPEN_TMP"
      rm -f "$DOC_OPEN_FRAG" "$DOC_OPEN_TMP"
      return 0
    fi

    rm -f "$DOC_OPEN_FRAG" "$DOC_OPEN_TMP"
    w3m "$DOC_OPEN_ABS"
  }

  rdoc_preview() {
    local DOC_PREVIEW_LINE="$1"
    local DOC_PREVIEW_REL DOC_PREVIEW_ABS DOC_PREVIEW_COLS
    local DOC_PREVIEW_DIR tmp frag

    IFS=$'\t' read -r DOC_PREVIEW_REL DOC_PREVIEW_ABS <<<"$DOC_PREVIEW_LINE"

    [ -f "$DOC_PREVIEW_ABS" ] || {
      printf 'file not found: %s\n' "$DOC_PREVIEW_ABS"
      return 0
    }

    DOC_PREVIEW_COLS="$(tput cols 2>/dev/null || printf '80')"
    printf 'Relative: %s\nFull path: %s\n\n' "$DOC_PREVIEW_REL" "$DOC_PREVIEW_ABS"

    case "${DOC_PREVIEW_ABS##*.}" in
      html|htm)
        DOC_PREVIEW_DIR="$(dirname "$DOC_PREVIEW_ABS")"

        if command -v xmllint >/dev/null 2>&1; then
          tmp="$(mktemp --suffix=.html)" || tmp="/tmp/rdoc_preview.$$"
          frag="$(mktemp --suffix=.html)" || frag="/tmp/rdoc_preview_frag.$$"

          if xmllint --html --xpath '//main' "$DOC_PREVIEW_ABS" 2>/dev/null >"$frag"; then
            {
              printf '%s\n' '<!doctype html><html><head>'
              printf '%s\n' "<base href=\"file://$DOC_PREVIEW_DIR/\">"
              printf '%s\n' '</head><body>'
              cat "$frag"
              printf '%s\n' '</body></html>'
            } >"$tmp"
            w3m -dump -T text/html -cols "$DOC_PREVIEW_COLS" "$tmp"
            rm -f "$frag" "$tmp"
            return 0
          fi

          if xmllint --html --xpath '//article' "$DOC_PREVIEW_ABS" 2>/dev/null >"$frag"; then
            {
              printf '%s\n' '<!doctype html><html><head>'
              printf '%s\n' "<base href=\"file://$DOC_PREVIEW_DIR/\">"
              printf '%s\n' '</head><body>'
              cat "$frag"
              printf '%s\n' '</body></html>'
            } >"$tmp"
            w3m -dump -T text/html -cols "$DOC_PREVIEW_COLS" "$tmp"
            rm -f "$frag" "$tmp"
            return 0
          fi

          rm -f "$frag" "$tmp"
        fi

        w3m -dump -T text/html -cols "$DOC_PREVIEW_COLS" "$DOC_PREVIEW_ABS"
        ;;
      md)
        bat --paging=never --style=numbers "$DOC_PREVIEW_ABS"
        ;;
      *)
        bat --paging=never --style=plain "$DOC_PREVIEW_ABS"
        ;;
    esac
  }

  export -f rdoc_preview rdoc_open_html 2>/dev/null || true

  DOC_SELECTED_LINE=$(
    fzf --prompt="RustDocs> " \
        --header="Base: $DOC_BASE  (Enter opens the file)" \
        --delimiter=$'\t' \
        --with-nth=1 \
        --preview-window='right:75%,wrap' \
        --preview 'bash -lc '\''rdoc_preview "$1"'\'' bash {}' \
        < "$DOC_TMPLIST"
  )

  rm -f "$DOC_TMPLIST"

  if [ -z "$DOC_SELECTED_LINE" ]; then
    return 130
  fi

  IFS=$'\t' read -r DOC_SELECTED_REL DOC_SELECTED_ABS <<<"$DOC_SELECTED_LINE"

  if [ -z "$DOC_SELECTED_ABS" ] || [ ! -f "$DOC_SELECTED_ABS" ]; then
    printf 'Selected file missing or invalid: %s\n' "$DOC_SELECTED_ABS" >&2
    return 1
  fi

  case "${DOC_SELECTED_ABS##*.}" in
    html|htm)
      rdoc_open_html "$DOC_SELECTED_ABS"
      ;;
    md)
      bat --paging=always --style=numbers "$DOC_SELECTED_ABS"
      ;;
    *)
      if [ -n "$PAGER" ]; then
        "$PAGER" "$DOC_SELECTED_ABS"
      else
        less -R "$DOC_SELECTED_ABS"
      fi
      ;;
  esac

  return 0
}

alias rdoc='rustdoc_search'

dockeron() {
  if [ -d /etc/sv/docker ] && [ ! -e /var/service/docker ]; then
    sudo ln -s /etc/sv/docker /var/service/ || true
  fi

  echo "Starting Docker service..."
  sudo sv up docker || true

  echo "dockeron: Docker started and enabled on boot."
}

dockeroff() {
  echo "Stopping Docker service..."

  if command -v docker >/dev/null 2>&1; then
    sudo docker ps -q | xargs -r sudo docker stop
  fi

  if [ -e /var/service/docker ]; then
    sudo sv down docker || true
    sudo rm -f /var/service/docker
  fi

  echo "dockeroff: Docker stopped and disabled from startup."
}

### Bluetooth

btup() {
  if [ -d /etc/sv/dbus ] && [ ! -e /var/service/dbus ]; then
    sudo ln -s /etc/sv/dbus /var/service/ || true
  fi
  if [ -d /etc/sv/bluetoothd ] && [ ! -e /var/service/bluetoothd ]; then
    sudo ln -s /etc/sv/bluetoothd /var/service/ || true
  fi

  echo "Starting dbus and bluetoothd..."
  if [ -e /var/service/dbus ]; then sudo sv up dbus || true; fi
  if [ -e /var/service/bluetoothd ]; then sudo sv up bluetoothd || true; fi

  # unblock and power on
  command -v rfkill >/dev/null 2>&1 && sudo rfkill unblock bluetooth || true
  if command -v bluetoothctl >/dev/null 2>&1; then
    printf 'power on\nagent on\ndefault-agent\nquit\n' | sudo bluetoothctl >/dev/null 2>&1 || true
  fi
  command -v hciconfig >/dev/null 2>&1 && sudo hciconfig hci0 up >/dev/null 2>&1 || true

  echo "btup: started bluetoothd and requested adapter power-on."
  echo "Use 'bluetoothctl' to pair/connect (or Blueman for GUI)."
}

btdown() {
  echo "Powering down bluetooth..."

  if sv status bluetoothd 2>/dev/null | grep -q run; then
    printf 'disconnect\npower off\nquit\n' | sudo bluetoothctl --timeout 3 >/dev/null 2>&1 || true
  fi

  if ip link show hci0 >/dev/null 2>&1; then
    sudo hciconfig hci0 down >/dev/null 2>&1 || true
  fi

  command -v rfkill >/dev/null 2>&1 && sudo rfkill block bluetooth || true

  if [ -e /var/service/bluetoothd ]; then
    sudo sv down bluetoothd || true
    sudo rm -f /var/service/bluetoothd
  fi

  echo "btdown: bluetooth powered off, service stopped, and disabled."
}

### Virtualisation utilties

virtup() {
  for svc in libvirtd virtlogd virtlockd; do
    if [ -d "/etc/sv/$svc" ] && [ ! -e "/var/service/$svc" ]; then
      sudo ln -s "/etc/sv/$svc" /var/service/ || true
    fi
  done

  echo "Ensuring /run/libvirt exists..."
  sudo mkdir -p /run/libvirt || true
  sudo chown root:root /run/libvirt || true

  if [ -e /var/service/libvirtd ]; then
    echo "Starting libvirtd (runit)..."
    sudo sv up libvirtd || true
  else
    echo "libvirtd runit service missing — attempting to start libvirtd daemon..."
    command -v libvirtd >/dev/null 2>&1 && sudo libvirtd --daemon || true
  fi

  if [ -e /var/service/virtlogd ]; then
    echo "Starting virtlogd (runit)..."
    sudo sv up virtlogd || true
  else
    echo "virtlogd runit service missing — attempting to start virtlogd daemon..."
    if command -v virtlogd >/dev/null 2>&1; then
      sudo virtlogd --daemon || true
    elif [ -x /usr/sbin/virtlogd ]; then
      sudo /usr/sbin/virtlogd --daemon || true
    fi
  fi

  if [ -e /var/service/virtlockd ]; then
    echo "Starting virtlockd (runit)..."
    sudo sv up virtlockd || true
  else
    if command -v virtlockd >/dev/null 2>&1; then
      echo "virtlockd runit service missing — attempting to start virtlockd daemon..."
      sudo virtlockd --daemon || true
    fi
  fi

  sleep 1.5

  echo "Sockets:"
  ls -l /run/libvirt 2>/dev/null || true
  [ -e /run/libvirt/virtlogd-sock ] && echo " - virtlogd-sock present" || echo " - virtlogd-sock missing"
  [ -e /run/libvirt/libvirt-sock ] && echo " - libvirt-sock present" || echo " - libvirt-sock missing"

  # Quick verification
  if command -v virsh >/dev/null 2>&1; then
    echo "virsh connection test:"
    virsh -c qemu:///system list --all || true
  fi

  echo "virtup: done. If virt-manager previously complained, retry it now."
}

virtdown() {
  echo "Stopping libvirt services..."

  if [ -e /var/service/virtlockd ]; then
    sudo sv down virtlockd || true
    sudo rm -f /var/service/virtlockd || true
  fi

  if [ -e /var/service/virtlogd ]; then
    sudo sv down virtlogd || true
    sudo rm -f /var/service/virtlogd || true
  else
    # fallback: kill daemon if running
    if pgrep -x virtlogd >/dev/null 2>&1; then
      sudo pkill -f virtlogd || true
    fi
  fi

  if [ -e /var/service/libvirtd ]; then
    sudo sv down libvirtd || true
    sudo rm -f /var/service/libvirtd || true
  else
    if pgrep -x libvirtd >/dev/null 2>&1; then
      sudo pkill -f libvirtd || true
    fi
  fi

  sudo rm -f /run/libvirt/virtlogd-sock 2>/dev/null || true
  sudo rm -f /run/libvirt/libvirt-sock 2>/dev/null || true

  echo "virtdown: libvirt services stopped and disabled from autostart (runit symlinks removed)."
  echo "If you want services disabled but not removed, remove the 'rm -f /var/service/...' lines above."
}

### Other useful commands

cc() {
  if [[ $# -ne 3 ]]; then
    echo "Usage: cc <amount> <from_currency> <to_currency>" >&2
    return 1
  fi

  local amount="$1"
  local from="${2^^}"
  local to="${3^^}"

  if ! [[ "$amount" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Error: amount must be a number" >&2
    return 1
  fi

  local response rate result

  response="$(curl -fsS "https://api.frankfurter.dev/v1/latest?base=$from&symbols=$to")" || return 1

  rate="$(jq -er --arg to "$to" '.rates[$to]' <<<"$response")" || return 1

  result="$(awk -v amount="$amount" -v rate="$rate" 'BEGIN { printf "%.2f", amount * rate }')"

  printf "%s %s -> %s %s\n" "$amount" "$from" "$result" "$to"
}

# Keybindings
bind '"\C-h": backward-kill-word'

# Rust/cargo
. "$HOME/.cargo/env" 2>/dev/null || true

# Nvm
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# Aliases
alias qr="zbarimg -q --raw"
alias prolog="setsid swipl-win & disown"
alias pdf='zathura'
alias m='micro'
alias nano='micro'
alias rg='rg -p'
alias cd='z'
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias lh='du -sh *'
alias lhh='du -sh -- * .[!.]* 2>/dev/null'
alias ..='z ..'
alias ...='z ../..'
alias relaxy='$___rel_ssh'
alias torus='$___name'
alias sandbox='firejail --private=. bash'
alias rundockerdb='docker start oracle-xe'

# Pretty display
if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b)"
fi

_short_path() {
  local pwd="$PWD"
  if [[ "$pwd" == "$HOME"* ]]; then
    pwd="~${pwd#$HOME}"
  fi

  local max=40
  if [ "${#pwd}" -le "$max" ]; then
    printf '%s' "$pwd"
  else
    local start_len=16
    local end_len=$((max - start_len - 1))
    local start_part="${pwd:0:start_len}"
    local end_part="${pwd: -$end_len}"
    printf '%s…%s' "$start_part" "$end_part"
  fi
}

PROMPT_COMMAND='__last_exit=$?'

PS1='\[\e[1;37m\][\u@\h \[\e[90m\]$(_short_path)\[\e[0m\]\[\e[1;37m\]]\[\e[0m\]\$ '

export EDITOR=micro
export VISUAL=micro

# Zoxide
eval "$(zoxide init bash)" 2>/dev/null || true

# Created by `pipx` on 2026-03-23 13:01:31
export PATH="$PATH:/home/mattfor/.local/bin"
