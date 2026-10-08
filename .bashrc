# ~/.bashrc

# Exit early for non-interactive shells
[[ $- != *i* ]] && return

# History
HISTSIZE=1000000
HISTFILESIZE=2000000

sync="${SYNC_DIR:-"$HOME/sync-folder"}"
s="$sync"

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
    sudo xbps-install -Syu || true

    command -v rustup >/dev/null 2>&1 && rustup update || true

    command -v flatpak >/dev/null 2>&1 && flatpak update -y || true
}

mvp() {
    rsync -ah --progress "$@"
}

mvpr() {
    rsync -ah --progress --remove-source-files "$@"
}

reloadcaddy() {
    sudo caddy fmt --overwrite /etc/caddy/Caddyfile \
        && sudo caddy validate --config /etc/caddy/Caddyfile \
        && sudo caddy reload --config /etc/caddy/Caddyfile
}

copy() {
    if [ ! -t 0 ]; then
        xclip -selection clipboard -in
        return $?
    fi

    if [ $# -gt 0 ]; then
        case "${1,,}" in
            *.png) xclip -selection clipboard -t image/png -in "$1" ;;
            *.jpg | *.jpeg) xclip -selection clipboard -t image/jpeg -in "$1" ;;
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

imgtxt() {
    local targets type tmp rc

    targets=$(xclip -selection clipboard -t TARGETS -o 2>/dev/null)
    type=$(grep -m1 -x 'image/png' <<<"$targets" || grep -m1 '^image/' <<<"$targets") || {
        echo "No image found in the clipboard." >&2
        return 1
    }

    tmp=$(mktemp --suffix=.png)
    xclip -selection clipboard -t "$type" -o | magick - "$tmp"

    if [[ $(magick "$tmp" -colorspace Gray -format '%[fx:mean < 0.4]' info:) == 1 ]]; then
        magick "$tmp" -colorspace Gray -negate -resize 200% "$tmp"
    fi

    tesseract-ocr "$tmp" stdout 2>/dev/null
    rc=$?
    rm -f "$tmp"
    return $rc
}

cpimgtxt() {
    local text
    text=$(imgtxt) || return

    if [[ $text != *[![:space:]]* ]]; then
        echo "No text found in the image." >&2
        return 1
    fi

    printf '%s\n' "$text"
    printf '%s' "$text" | copy
}

hash() {
    [[ $1 == -* ]] && {
        builtin hash "$@"
        return
    }

    local alg="sha256"

    usage() {
        echo "Usage:"
        echo "  hash [algorithm] <file>"
        echo "  hash [algorithm] <text...>"
        echo
        echo "Available:"
        echo "  md5 sha1 sha224 sha256 sha384 sha512 b2"
    }

    [[ $# -eq 0 ]] && {
        usage
        return 1
    }

    case "$1" in
        md5 | sha1 | sha224 | sha256 | sha384 | sha512 | b2)
            alg="$1"
            shift
            ;;
    esac

    [[ $# -eq 0 ]] && {
        usage
        return 1
    }

    local cmd
    case "$alg" in
        b2) cmd=b2sum ;;
        *) cmd="${alg}sum" ;;
    esac

    if [[ $# -eq 1 && -f "$1" ]]; then
        "$cmd" -- "$1"
    else
        printf '%s' "$*" | "$cmd"
    fi
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

_kebab_case() {
    local name="$1" keep_ext="${2:-0}"
    local leading ext stem last prev

    leading="${name%%[!.]*}"
    name="${name#"$leading"}"

    stem="$name"
    ext=""

    if [[ $keep_ext -ne 0 && "$name" == ?*.* ]]; then
        last="${name##*.}"
        if [[ "$last" =~ ^[A-Za-z0-9]{1,8}$ ]]; then
            ext=".${last}"
            stem="${name%.*}"
            prev="${stem##*.}"
            if [[ "$stem" == ?*.* && "${prev,,}" == "tar" ]]; then
                ext=".${prev}${ext}"
                stem="${stem%.*}"
            fi
        fi
    fi

    stem=$(printf '%s' "$stem" | sed -E '
        :d
        s#(^|[^0-9._])([0-9]{1,3})[._]([0-9]{1,3})([^0-9]|$)#\1\2/\3\4#
        td
        s#([a-z0-9])([A-Z])#\1-\2#g
        s#([A-Z]+)([A-Z][a-z])#\1-\2#g
        s#([A-Za-z])([0-9])#\1-\2#g
        s#([0-9])([A-Za-z])#\1-\2#g
        s#[^[:alnum:]/]+#-#g
        s#-+#-#g
        s#^-##
        s#-$##
    ')

    stem="${stem,,}"
    printf '%s%s%s' "$leading" "${stem//\//.}" "${ext,,}"
}

kebabify() {
    local recursive=0 dry=0

    usage() {
        cat <<'EOF'
Usage: kebabify [-r] [-n] [path...]

Renames files and directories to kebab-case. With no paths, every non-hidden
entry in the current directory is renamed.

  -r, --recursive  descend into subdirectories, renaming deepest names first
  -n, --dry-run    print the renames without performing them
EOF
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --recursive) recursive=1 ;;
            --dry-run) dry=1 ;;
            --help)
                usage
                return 0
                ;;
            --)
                shift
                break
                ;;
            -?*)
                local flags="${1#-}" i flag
                for ((i = 0; i < ${#flags}; i++)); do
                    flag="${flags:i:1}"
                    case "$flag" in
                        r) recursive=1 ;;
                        n) dry=1 ;;
                        h)
                            usage
                            return 0
                            ;;
                        *)
                            printf 'kebabify: unknown option: -%s\n' "$flag" >&2
                            return 2
                            ;;
                    esac
                done
                ;;
            *) break ;;
        esac
        shift
    done

    local -a queue=()
    if [[ $# -gt 0 ]]; then
        queue=("$@")
    else
        local entry
        for entry in *; do
            [[ -e "$entry" || -L "$entry" ]] && queue+=("$entry")
        done
    fi

    local -a targets=()
    local path sub
    for path in "${queue[@]}"; do
        if [[ $recursive -eq 1 && -d "$path" && ! -L "$path" ]]; then
            while IFS= read -r -d '' sub; do
                targets+=("$sub")
            done < <(find "$path" -mindepth 1 -depth -not -path '*/.*' -print0)
        fi
        targets+=("$path")
    done

    local -A planned=()
    local dir base new target
    for path in "${targets[@]}"; do
        [[ -e "$path" || -L "$path" ]] || continue

        base="${path##*/}"
        dir="${path%/*}"
        [[ "$dir" == "$path" ]] && dir="."

        if [[ -d "$path" && ! -L "$path" ]]; then
            new=$(_kebab_case "$base")
        else
            new=$(_kebab_case "$base" 1)
        fi

        [[ -z "$new" || "$new" == "$base" ]] && continue

        target="$dir/$new"
        if [[ -e "$target" || -L "$target" || -n "${planned[$target]:-}" ]]; then
            printf 'SKIP: "%s" -> "%s" (target already exists)\n' "$path" "$new"
            continue
        fi
        planned["$target"]=1

        printf 'RENAME: "%s" -> "%s"\n' "$path" "$new"
        [[ $dry -eq 1 ]] || mv -- "$path" "$target"
    done
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
        xz | best)
            if [[ $use_password -eq 1 ]]; then
                echo "Password protection is not supported for xz archives."
                return 1
            fi
            out="archive.tar.xz"
            tmp="${out}.tmp"
            tar --exclude="$out" --exclude="$tmp" -cvf "$tmp" -I 'xz -9e --threads=0' "$@"
            mv -f "$tmp" "$out"
            ;;

        gz | gzip)
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

        bz2 | bzip2)
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
    local args=("$@")

    [ -t 0 ] || args=(-)

    if [ -t 1 ]; then
        glow -p "${args[@]}"
    else
        glow "${args[@]}"
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

        application/vnd.rar | application/x-rar | application/x-rar-compressed)
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

        application/gzip | application/x-gzip)
            tar -tvzf "$file"
            return $?
            ;;
        application/x-bzip2)
            tar -tvjf "$file"
            return $?
            ;;
        application/x-xz | application/x-compress* | application/x-lzip)
            tar -tvJf "$file"
            return $?
            ;;
        application/x-lz4 | application/lz4)
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
        application/x-zstd | application/zstd)
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
            tar -tvf -- "$file"
            return $?
            ;;
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
        *.7z | *.7z.001)
            if command -v 7z >/dev/null 2>&1; then
                7z l -- "$file" && return 0
            fi
            ;;
        *.tar.gz | *.tgz)
            tar -tvzf "$file"
            return $?
            ;;
        *.tar.bz2 | *.tbz2)
            tar -tvjf "$file"
            return $?
            ;;
        *.tar.xz | *.txz)
            tar -tvJf "$file"
            return $?
            ;;
        *.tar.lz4 | *.tlz4)
            if command -v lz4 >/dev/null 2>&1; then
                lz4 -d -c -- "$file" | tar -tvf - && return 0
            fi
            ;;
        *.tar.zst | *.tzst)
            if command -v zstd >/dev/null 2>&1; then
                zstd -d -c -- "$file" | tar -tvf - && return 0
            fi
            ;;
        *.tar)
            tar -tvf "$file"
            return $?
            ;;
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

minify() (
    set -Eeuo pipefail

    local DIST="${1:-dist}"

    command -v esbuild >/dev/null 2>&1 || {
        echo "Error: esbuild is not installed."
        return 1
    }

    command -v rsync >/dev/null 2>&1 || {
        echo "Error: rsync is not installed."
        return 1
    }

    rm -rf "$DIST"
    mkdir -p "$DIST"

    rsync -a \
        --exclude='.git' \
        --exclude='.github' \
        --exclude='.gitlab' \
        --exclude='.svn' \
        --exclude='node_modules' \
        --exclude="$DIST" \
        --exclude='.cache' \
        --exclude='.vscode' \
        --exclude='.idea' \
        --exclude='coverage' \
        --exclude='tmp' \
        ./ "$DIST/"

    find . \
        -type f \
        \( -name '*.js' -o -name '*.css' \) \
        ! -path "./$DIST/*" \
        ! -path './node_modules/*' \
        | while IFS= read -r file; do

            local out="$DIST/${file#./}"
            mkdir -p "$(dirname "$out")"

            printf 'Minifying %s\n' "$file"

            esbuild "$file" \
                --minify \
                --legal-comments=none \
                --outfile="$out"
        done

    echo
    echo "Minified website written to $DIST/"
)

gitrepo() {
    if [ -z "${1:-}" ]; then
        echo "Usage: gitrepo <repo-name>"
        return 1
    fi

    local repo="$1"
    local codeberg_user=${CODEBERG_USER:-}
    local github_user=${GITHUB_USER:-}
    if [ -z "$codeberg_user" ] || [ -z "$github_user" ]; then
        printf '%s\n' "Set CODEBERG_USER and GITHUB_USER in ~/.config/secrets/env first." >&2
        return 1
    fi

    git remote add origin "ssh://git@codeberg.org/${codeberg_user}/${repo}.git"
    git remote add github "git@github.com:${github_user}/${repo}.git"

    git remote set-url --add --push origin "ssh://git@codeberg.org/${codeberg_user}/${repo}.git"
    git remote set-url --add --push origin "git@github.com:${github_user}/${repo}.git"

    echo "Configured remotes for ${repo}:"
    git remote -v
}

gitremake() {
    if [[ $# -ne 2 ]]; then
        echo 'Usage: gitremake <branch-name> "commit message"'
        return 1
    fi

    local new_branch="$1"
    local message="$2"
    local old_branch
    local temp_branch="__gitremake__"

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Error: not inside a Git repository."
        return 1
    fi

    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Error: working tree is not clean."
        return 1
    fi

    old_branch="$(git branch --show-current)"

    if [[ -z "$old_branch" ]]; then
        echo "Error: not currently on a branch."
        return 1
    fi

    if git show-ref --verify --quiet "refs/heads/$temp_branch"; then
        temp_branch="__gitremake__-$(date +%s)-$RANDOM"
        while git show-ref --verify --quiet "refs/heads/$temp_branch"; do
            temp_branch="__gitremake__-$(date +%s)-$RANDOM"
        done
    fi

    echo "Old branch:   $old_branch"
    echo "New branch:   $new_branch"
    echo "Commit:       $message"
    echo "Temp branch:  $temp_branch"

    read -r -p "Continue? [y/N] " confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]] || return 1

    git checkout --orphan "$temp_branch" || return 1

    git add -A || return 1
    git commit --no-verify -m "$message" || return 1

    git branch --format='%(refname:short)' \
        | while IFS= read -r branch; do
            [[ "$branch" == "$temp_branch" ]] && continue
            git branch -D "$branch" || exit 1
        done

    git branch -m "$new_branch" || return 1

    git push --force -u origin "$new_branch"
}

gitdiff() {
    local base_commit

    if [ -n "$1" ] && git rev-parse --verify "$1^{commit}" >/dev/null 2>&1; then
        base_commit="$1"
        shift
    else
        local me
        me=$(git config user.email)

        if [ -z "$me" ]; then
            echo "Error: git user.email is not configured." >&2
            return 1
        fi

        base_commit=$(git log --author="$me" -n 1 --format="%H" 2>/dev/null)

        if [ -z "$base_commit" ]; then
            echo "No commits found by $me in current branch history." >&2
            return 1
        fi
    fi

    git diff "$base_commit" HEAD "$@"
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

gitpr() {
    if [ -z "$1" ]; then
        echo 'Usage: gitpr "title" ["body"]' >&2
        return 1
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: not inside a Git repository." >&2
        return 1
    fi

    if ! command -v gh >/dev/null 2>&1 || ! command -v tea >/dev/null 2>&1; then
        echo "Error: both gh and tea are required." >&2
        return 1
    fi

    if [ -z "$(tea login list -o simple 2>/dev/null)" ]; then
        echo "Error: no gitea login configured, run: tea login add" >&2
        return 1
    fi

    local title="$1"
    local body="${2:-}"
    local branch base

    branch="$(git branch --show-current)"

    if [ -z "$branch" ]; then
        echo "Error: not currently on a branch." >&2
        return 1
    fi

    base="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
    base="${base#origin/}"

    if [ -z "$base" ]; then
        base="$(git config --get init.defaultBranch)"
        base="${base:-main}"
    fi

    if [ "$branch" = "$base" ]; then
        echo "Error: current branch is the base branch ($base)." >&2
        return 1
    fi

    git push -u origin "$branch" || return 1

    local monitor=0
    [[ $- == *m* ]] && monitor=1
    set +m

    local gh_log tea_log gh_pid tea_pid gh_rc tea_rc

    gh_log="$(mktemp)"
    tea_log="$(mktemp)"

    gh pr create --base "$base" --head "$branch" --title "$title" --body "$body" >"$gh_log" 2>&1 &
    gh_pid=$!

    tea pr create --remote origin --base "$base" --head "$branch" --title "$title" --description "$body" >"$tea_log" 2>&1 &
    tea_pid=$!

    wait "$gh_pid"
    gh_rc=$?

    wait "$tea_pid"
    tea_rc=$?

    [ "$monitor" -eq 1 ] && set -m

    echo "=== GitHub ==="
    cat "$gh_log"

    echo "=== Codeberg ==="
    cat "$tea_log"

    rm -f "$gh_log" "$tea_log"

    [ "$gh_rc" -eq 0 ] && [ "$tea_rc" -eq 0 ]
}

rpi-up() {
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        echo "Usage: rpi-up <local_path> [remote_dir]"
        echo "  remote_dir defaults to the Pi home; relative paths start there"
        return 1
    fi

    local src="${1%/}"
    local dest="${2:-.}"

    if [ ! -e "$src" ]; then
        echo "rpi-up: not found: $src" >&2
        return 1
    fi

    tar -c -C "$(dirname -- "$src")" -- "$(basename -- "$src")" \
        | pv -s "$(du -sb -- "$src" | cut -f1)" \
        | $___rel_ssh "mkdir -p -- $(printf '%q' "$dest") && tar -x -C $(printf '%q' "$dest")"
}

rpi-dl() {
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        echo "Usage: rpi-dl <remote_path> [local_dir]"
        echo "  relative remote paths start at the Pi home (the bot is in relaxy/)"
        return 1
    fi

    local src="${1%/}"
    local dest="${2:-.}"

    mkdir -p -- "$dest" || return 1

    $___rel_ssh "cd $(printf '%q' "$(dirname -- "$src")") && tar -c -- $(printf '%q' "$(basename -- "$src")")" </dev/null \
        | pv \
        | tar -x -C "$dest"
}

rpi-ls() {
    $___rel_ssh "ls ${1:-}"
}

_tar_from_stdin() {
    tar -tvf - 2>/dev/null || {
        printf 'tpeek: tar failed to read from stdin\n' >&2
        return 3
    }
}

c() {
    if [ $# -eq 0 ]; then
        echo "Usage: c [v|vv|vvv|sv|svv|svvv|dbg|sdbg] file1.cpp [file2.cpp ...]"
        return 1
    fi

    local search verbosity dbg token rest main output std_flag
    local -a files common_opts driver_verbose linker_verbose warn_flags extra_flags sanitizer_flags debug_flags cmd

    search=false
    verbosity=1
    dbg=false

    token="$1"
    case "$token" in
        sdbg | SDBG | Sdbg)
            search=true
            dbg=true
            shift
            ;;
        dbg | gdb | debug)
            dbg=true
            shift
            ;;
        svv | svvv | sv)
            rest="${token#s}"
            verbosity=${#rest}
            search=true
            shift
            ;;
        vvv | vv | v)
            verbosity=${#token}
            shift
            ;;
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

    files=("$@")
    main="${files[0]}"
    output="${main%.*}"

    std_flag="-std=gnu++26"
    common_opts=(-pipe)

    driver_verbose=()
    linker_verbose=()
    warn_flags=()
    extra_flags=()
    sanitizer_flags=()
    debug_flags=()

    if [ "$dbg" = true ]; then
        debug_flags=(-g -O0 -ggdb -fno-omit-frame-pointer -rdynamic)
        warn_flags=(-Wall -Wextra -Wpedantic)
    else
        case "$verbosity" in
            1)
                warn_flags=(-Wall -Wextra)
                extra_flags=(-O2)
                ;;
            2)
                warn_flags=(-Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion -Wformat=2 -Wnull-dereference -Wdouble-promotion)
                extra_flags=(-O2 -ftemplate-backtrace-limit=0 -fconcepts-diagnostics-depth=10)
                ;;
            3)
                warn_flags=(-Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion -Wformat=2 -Wnull-dereference -Wdouble-promotion -Wold-style-cast -Wcast-align -Wformat-security -Wredundant-decls -Wlogical-op -Werror)
                extra_flags=(-O2 -g -ftemplate-backtrace-limit=0 -fconcepts-diagnostics-depth=10)
                sanitizer_flags=(-fsanitize=address,undefined -fno-omit-frame-pointer)
                ;;
            *)
                warn_flags=(-Wall -Wextra)
                extra_flags=(-O2)
                ;;
        esac
    fi

    if [ "$search" = true ]; then
        driver_verbose=(-v)
        linker_verbose=(-Wl,--verbose)
    fi

    cmd=(g++ "$std_flag" "${common_opts[@]}" "${warn_flags[@]}" "${extra_flags[@]}")

    if [ "$dbg" = true ]; then
        cmd+=("${debug_flags[@]}")
    fi

    if [ "${#sanitizer_flags[@]}" -ne 0 ] && [ "$dbg" != true ]; then
        cmd+=("${sanitizer_flags[@]}")
    fi

    if [ "${#driver_verbose[@]}" -ne 0 ]; then
        cmd+=("${driver_verbose[@]}")
    fi

    cmd+=("${files[@]}")

    if [ "${#linker_verbose[@]}" -ne 0 ]; then
        cmd+=("${linker_verbose[@]}")
    fi

    cmd+=(-o "$output")

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
        intro | introduction)
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
        reference | ref)
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
        std | standard | library)
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
        by-example | rbe)
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
            html | htm)
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
            <"$DOC_TMPLIST"
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
        html | htm)
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

ai() {
    local action model selected models choice root gateway ollama_pid odysseus_pid pid i url remote_host remote_service remote_port ts_hostname remote_prompt remote_response
    root=${ODYSSEUS_ROOT:-"$HOME/applications/odysseus"}
    gateway=${FREELLMAPI_ROOT:-"$HOME/applications/freellmapi"}

    if [ $# -gt 0 ]; then
        action=$1
        shift
        if ollama list 2>/dev/null | awk 'NR > 1 { print $1 }' | grep -Fxq "$action"; then
            set -- "$action" "$@"
            action=local
        fi
    else
        choice=$(
            printf '%s\n' \
                'local: Choose an Ollama model' \
                'claude: Claude Code' \
                'copilot: GitHub Copilot CLI' \
                'cursor: Cursor Agent' \
                'codex: OpenAI Codex CLI' \
                'odysseus: Open Odysseus' \
                'freellmapi: Open FreeLLMAPI' \
                'remote: Connect to another Tailscale machine' \
                'health: Check every local AI service, endpoint, and model' \
                'status: Check local AI services' \
                'models: List installed Ollama models' \
                'logs: Show recent AI service logs' \
                'start: Start the local AI stack' \
                'stop: Stop the local AI stack' \
                'autostart: Manage Docker autostart' \
                'help: Show ai usage' \
                | fzf --prompt='AI command: ' --height=55% --layout=reverse
        )
        [ -n "$choice" ] || return 0
        action=${choice%%:*}
        [ "$action" = "local" ] || [ "$action" = "claude" ] || [ "$action" = "copilot" ] \
            || [ "$action" = "cursor" ] || [ "$action" = "codex" ] || [ "$action" = "status" ] \
            || [ "$action" = "odysseus" ] || [ "$action" = "freellmapi" ] || [ "$action" = "health" ] \
            || [ "$action" = "models" ] \
            || [ "$action" = "remote" ] \
            || [ "$action" = "logs" ] || [ "$action" = "start" ] || [ "$action" = "stop" ] \
            || [ "$action" = "autostart" ] || action=help
    fi

    case "$action" in
        local)
            models=$(ollama list 2>/dev/null | awk 'NR > 1 && $1 != "" { print $1 }')
            [ -n "$models" ] || {
                printf '%s\n' "No Ollama models are installed or Ollama is not running." >&2
                return 1
            }
            model=$1
            [ -n "$model" ] && printf '%s\n' "$models" | grep -Fxq "$model" || model=
            if [ -z "$model" ]; then
                model=$(printf '%s\n' "$models" | fzf --prompt='Local model: ' --height=40% --layout=reverse)
            fi
            [ -n "$model" ] || return 0
            shift $(($# > 0 ? 1 : 0))
            if [ $# -gt 0 ]; then
                ollama run "$model" "$*"
            else
                ollama run "$model"
            fi
            ;;
        claude)
            command -v claude >/dev/null 2>&1 || {
                printf '%s\n' "Claude Code is not installed." >&2
                return 1
            }
            claude "$@"
            ;;
        copilot)
            command -v copilot >/dev/null 2>&1 || {
                printf '%s\n' "Copilot CLI is not installed." >&2
                return 1
            }
            copilot "$@"
            ;;
        cursor)
            command -v agent >/dev/null 2>&1 || {
                printf '%s\n' "Cursor Agent CLI is not installed." >&2
                return 1
            }
            agent "$@"
            ;;
        codex)
            command -v codex >/dev/null 2>&1 || {
                printf '%s\n' "Codex CLI is not installed." >&2
                return 1
            }
            codex "$@"
            ;;
        odysseus)
            url=http://127.0.0.1:7000
            command -v xdg-open >/dev/null 2>&1 || {
                printf '%s\n' "$url"
                return 0
            }
            xdg-open "$url" >/dev/null 2>&1 &
            ;;
        freellmapi)
            url=http://127.0.0.1:3001
            command -v xdg-open >/dev/null 2>&1 || {
                printf '%s\n' "$url"
                return 0
            }
            xdg-open "$url" >/dev/null 2>&1 &
            ;;
        remote)
            if ! command -v tailscale >/dev/null 2>&1; then
                printf '%s\n' "Tailscale is not installed." >&2
                return 1
            fi
            case "${1:-help}" in
                setup)
                    ts_hostname=${TS_HOSTNAME:-${HOSTNAME%%.*}}
                    [ -n "$ts_hostname" ] || ts_hostname=$(hostname)
                    printf '%s\n' \
                        'On each machine, install Tailscale and sign in:' \
                        "  sudo tailscale up --ssh --hostname=$ts_hostname" \
                        "This machine will use the hostname: $ts_hostname" \
                        'Then connect by name without tracking IP addresses:' \
                        '  ai remote ssh <machine-name>' \
                        'List visible machines with:' \
                        '  ai remote status'
                    ;;
                status)
                    sudo tailscale status
                    ;;
                ssh | connect)
                    remote_host=$2
                    [ -n "$remote_host" ] || {
                        printf '%s\n' "Usage: ai remote ssh <machine> [command...]" >&2
                        return 2
                    }
                    shift 2
                    if [ $# -gt 0 ]; then
                        tailscale ssh "$remote_host" "$@"
                    else
                        tailscale ssh "$remote_host"
                    fi
                    ;;
                tunnel)
                    remote_host=$2
                    remote_service=$3
                    [ -n "$remote_host" ] && [ -n "$remote_service" ] || {
                        printf '%s\n' "Usage: ai remote tunnel <machine> <ollama|odysseus|freellmapi|PORT> [local-port]" >&2
                        return 2
                    }
                    case "$remote_service" in
                        ollama) remote_port=11434 ;;
                        odysseus) remote_port=7000 ;;
                        freellmapi) remote_port=3001 ;;
                        ''|*[!0-9]*) 
                            printf '%s\n' "Unknown service: $remote_service" >&2
                            return 2
                            ;;
                        *) remote_port=$remote_service ;;
                    esac
                    remote_port=${4:-$remote_port}
                    case "$remote_port" in
                        ''|*[!0-9]*)
                            printf '%s\n' "Local port must be numeric." >&2
                            return 2
                            ;;
                    esac
                    printf '%s\n' "Forwarding 127.0.0.1:$remote_port to $remote_host:127.0.0.1:$remote_port; press Ctrl-C to stop."
                    tailscale ssh "$remote_host" -N -L "$remote_port:127.0.0.1:$remote_port"
                    ;;
                local)
                    remote_host=$2
                    model=$3
                    shift 3
                    [ -n "$remote_host" ] || {
                        printf '%s\n' "Usage: ai remote local <machine> [MODEL] [PROMPT]" >&2
                        return 2
                    }
                    if ! curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
                        if [ -f /tmp/ai-remote-ollama.pid ]; then
                            pid=$(cat /tmp/ai-remote-ollama.pid)
                            kill "$pid" 2>/dev/null || true
                            rm -f /tmp/ai-remote-ollama.pid
                        fi
                        nohup tailscale ssh "$remote_host" -N -L 11434:127.0.0.1:11434 \
                            >/tmp/ai-remote-ollama.log 2>&1 </dev/null &
                        echo $! >/tmp/ai-remote-ollama.pid
                        sleep 2
                    fi
                    curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null 2>&1 || {
                        printf '%s\n' "Remote Ollama is unavailable. Is $remote_host online and connected to Tailscale?" >&2
                        return 1
                    }
                    models=$(curl -fsS http://127.0.0.1:11434/api/tags | python3 -c 'import json, sys; print("\n".join(m["name"] for m in json.load(sys.stdin)["models"]))') || return 1
                    [ -n "$model" ] && printf '%s\n' "$models" | grep -Fxq "$model" || model=
                    if [ -z "$model" ]; then
                        model=$(printf '%s\n' "$models" | fzf --prompt="Remote model ($remote_host): " --height=40% --layout=reverse)
                    fi
                    [ -n "$model" ] || return 0
                    if [ $# -gt 0 ]; then
                        remote_prompt="$*"
                    else
                        printf 'Prompt for %s via %s: ' "$model" "$remote_host"
                        IFS= read -r remote_prompt
                    fi
                    remote_response=$(python3 - "$model" "$remote_prompt" <<'PY'
import json
import sys
model, prompt = sys.argv[1:]
print(json.dumps({
    "model": model,
    "prompt": prompt,
    "stream": False,
    "think": True,
}))
PY
                    ) || return 1
                    curl -fsS --max-time 600 http://127.0.0.1:11434/api/generate \
                        -H 'Content-Type: application/json' \
                        -d "$remote_response" |
                        python3 -c 'import json, sys; print(json.load(sys.stdin).get("response", ""))'
                    ;;
                help | *)
                    printf '%s\n' \
                        'Usage: ai remote [setup|status|ssh|tunnel|local]' \
                        '  ai remote setup                         Show one-time Tailscale setup' \
                        '  ai remote status                        List machines and MagicDNS names' \
                        '  ai remote ssh <machine> [command...]    Open an SSH session by name' \
                        '  ai remote tunnel <machine> ollama       Tunnel remote Ollama to local port 11434' \
                        '  ai remote tunnel <machine> odysseus     Tunnel remote Odysseus to local port 7000' \
                        '  ai remote tunnel <machine> freellmapi   Tunnel remote FreeLLMAPI to local port 3001' \
                        '  ai remote local <machine> [MODEL] [PROMPT]  Query remote Ollama automatically'
                    ;;
            esac
            ;;
        models)
            ollama list
            ;;
        health)
            local health_failed=0 health_mode=${1:-shallow} health_model
            printf '%s\n' 'AI health check'
            printf '%-28s' 'Ollama HTTP API'
            if curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null; then
                printf '%s\n' 'OK'
            else
                printf '%s\n' 'FAIL'
                health_failed=1
            fi
            printf '%-28s' 'Ollama OpenAI endpoint'
            if curl -fsS --max-time 3 http://127.0.0.1:11434/v1/models >/dev/null; then
                printf '%s\n' 'OK'
            else
                printf '%s\n' 'FAIL'
                health_failed=1
            fi
            printf '%-28s' 'Odysseus HTTP API'
            if curl -fsS --max-time 3 http://127.0.0.1:7000/health >/dev/null; then
                printf '%s\n' 'OK'
            else
                printf '%s\n' 'FAIL'
                health_failed=1
            fi
            printf '%-28s' 'FreeLLMAPI HTTP API'
            if curl -fsS --max-time 3 http://127.0.0.1:3001/api/ping >/dev/null; then
                printf '%s\n' 'OK'
            else
                printf '%s\n' 'FAIL'
                health_failed=1
            fi
            printf '%s\n' 'Docker containers:'
            docker compose -f "$root/docker-compose.yml" ps 2>/dev/null || health_failed=1
            docker compose -f "$gateway/docker-compose.yml" ps 2>/dev/null || health_failed=1
            printf '%s\n' 'Ollama models:'
            models=$(ollama list 2>/dev/null | awk 'NR > 1 && $1 != "" { print $1 }')
            if [ -z "$models" ]; then
                printf '%s\n' 'No models found'
                health_failed=1
            else
                while IFS= read -r health_model; do
                    [ -n "$health_model" ] || continue
                    printf '%-28s' "$health_model"
                    if curl -fsS --max-time 10 http://127.0.0.1:11434/api/show \
                        -H 'Content-Type: application/json' \
                        -d "{\"name\":\"$health_model\"}" >/dev/null; then
                        printf '%s\n' 'available'
                    else
                        printf '%s\n' 'FAIL'
                        health_failed=1
                    fi
                    if [ "$health_mode" = "deep" ]; then
                        printf '%-28s' "$health_model inference"
                        if curl -fsS --max-time 120 http://127.0.0.1:11434/api/chat \
                            -H 'Content-Type: application/json' \
                            -d "{\"model\":\"$health_model\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply only with OK.\"}],\"stream\":false,\"think\":false}" \
                            | grep -q '"content"'; then
                            printf '%s\n' 'OK'
                        else
                            printf '%s\n' 'FAIL'
                            health_failed=1
                        fi
                    fi
                done <<EOF
$models
EOF
            fi
            [ "$health_mode" = "deep" ] || printf '%s\n' 'Use `ai health deep` to run a small inference request through every local model.'
            return "$health_failed"
            ;;
        status)
            printf '%-14s' "Tailscale"
            if command -v tailscale >/dev/null 2>&1 && sudo tailscale status >/dev/null 2>&1; then
                printf '%s\n' "ready"
            else
                printf '%s\n' "offline"
            fi
            printf '%-14s' "Ollama"
            curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null && printf '%s\n' "ready" || printf '%s\n' "offline"
            printf '%-14s' "Odysseus"
            curl -fsS --max-time 3 http://127.0.0.1:7000/health >/dev/null && printf '%s\n' "ready" || printf '%s\n' "offline"
            printf '%-14s' "FreeLLMAPI"
            curl -fsS --max-time 3 http://127.0.0.1:3001/api/ping >/dev/null && printf '%s\n' "ready" || printf '%s\n' "offline"
            printf '%s\n' "Installed models:"
            ollama list 2>/dev/null || true
            ;;
        logs)
            case "${1:-all}" in
                ollama) tail -n 80 /tmp/ollama-serve.log 2>/dev/null || printf '%s\n' "No Ollama log found." ;;
                odysseus) tail -n 80 /tmp/odysseus.log 2>/dev/null || printf '%s\n' "No Odysseus log found." ;;
                freellmapi) docker compose -f "$gateway/docker-compose.yml" logs --tail=80 --no-color freellmapi ;;
                all)
                    ai logs ollama
                    ai logs odysseus
                    ai logs freellmapi
                    ;;
                *)
                    printf '%s\n' "Usage: ai logs [ollama|odysseus|freellmapi|all]" >&2
                    return 2
                    ;;
            esac
            ;;
        start)
            if [ "${1:-}" = "tailscale" ]; then
                command -v tailscale >/dev/null 2>&1 || {
                    printf '%s\n' "Tailscale is not installed." >&2
                    return 1
                }
                if [ -d /etc/sv/tailscaled ] && [ ! -e /var/service/tailscaled ]; then
                    sudo ln -s /etc/sv/tailscaled /var/service/tailscaled || return 1
                fi
                if [ -e /var/service/tailscaled ]; then
                    sudo sv up tailscaled >/dev/null 2>&1 || true
                elif ! pgrep -x tailscaled >/dev/null 2>&1; then
                    printf '%s\n' "Tailscale runit service is unavailable." >&2
                    return 1
                fi
                ts_hostname=${TS_HOSTNAME:-${HOSTNAME%%.*}}
                [ -n "$ts_hostname" ] || ts_hostname=$(hostname)
                sudo tailscale up --ssh --hostname="$ts_hostname"
                return $?
            fi
            if [ "${1:-}" = "docker" ]; then
                if [ -d /etc/sv/docker ] && [ ! -e /var/service/docker ]; then
                    sudo ln -s /etc/sv/docker /var/service/docker || return 1
                fi
                sudo sv up docker
                return $?
            fi
            ollama_pid=/tmp/ollama-serve.pid
            odysseus_pid=/tmp/odysseus.pid
            if [ -d /etc/sv/docker ] && [ ! -e /var/service/docker ]; then
                sudo ln -s /etc/sv/docker /var/service/docker || return 1
            fi
            sudo sv up docker || return 1
            for i in $(seq 1 30); do
                docker info >/dev/null 2>&1 && break
                sleep 1
            done
            docker info >/dev/null 2>&1 || {
                printf '%s\n' "Docker did not become ready." >&2
                return 1
            }
            (cd "$root" && docker compose up -d chromadb searxng ntfy) || return 1
            (cd "$gateway" && docker compose up -d freellmapi) || return 1
            if ! ollama list >/dev/null 2>&1; then
                if [ -f "$ollama_pid" ] && kill -0 "$(cat "$ollama_pid")" 2>/dev/null; then
                    :
                else
                    nohup ollama serve >/tmp/ollama-serve.log 2>&1 &
                    echo $! >"$ollama_pid"
                fi
            fi
            if [ -f "$odysseus_pid" ] && kill -0 "$(cat "$odysseus_pid")" 2>/dev/null; then
                printf '%s\n' "Odysseus is already running."
            else
                (
                    cd "$root" || exit 1
                    nohup .venv/bin/python -m uvicorn app:app --host 127.0.0.1 --port 7000 >/tmp/odysseus.log 2>&1 &
                    echo $! >"$odysseus_pid"
                )
                printf '%s\n' "Odysseus started in the background."
            fi
            ;;
        stop)
            if [ "${1:-}" = "tailscale" ]; then
                command -v tailscale >/dev/null 2>&1 || {
                    printf '%s\n' "Tailscale is not installed." >&2
                    return 1
                }
                sudo tailscale down >/dev/null 2>&1 || true
                if [ -e /var/service/tailscaled ]; then
                    sudo sv down tailscaled
                else
                    printf '%s\n' "Tailscale service is already stopped."
                fi
                return 0
            fi
            if [ "${1:-}" = "docker" ]; then
                if [ -e /var/service/docker ]; then
                    sudo sv down docker
                else
                    printf '%s\n' "Docker service is already stopped."
                fi
                return 0
            fi
            ollama_pid=/tmp/ollama-serve.pid
            odysseus_pid=/tmp/odysseus.pid
            if [ -f "$odysseus_pid" ]; then
                pid=$(cat "$odysseus_pid")
                kill "$pid" 2>/dev/null || true
                rm -f "$odysseus_pid"
            fi
            if [ -f "$ollama_pid" ]; then
                pid=$(cat "$ollama_pid")
                kill "$pid" 2>/dev/null || true
                rm -f "$ollama_pid"
            fi
            (cd "$root" && docker compose stop chromadb searxng ntfy >/dev/null 2>&1 || true)
            (cd "$gateway" && docker compose stop freellmapi >/dev/null 2>&1 || true)
            sudo sv down docker >/dev/null 2>&1 || true
            ;;
        autostart)
            case "${1:-status}" in
                enable | on)
                    [ -d /etc/sv/docker ] || {
                        printf '%s\n' "Docker runit service not found." >&2
                        return 1
                    }
                    [ -e /var/service/docker ] || sudo ln -s /etc/sv/docker /var/service/docker
                    sudo sv up docker
                    printf '%s\n' "Docker autostart enabled."
                    ;;
                disable | off | remove)
                    if [ -e /var/service/docker ]; then
                        sudo sv down docker >/dev/null 2>&1 || true
                        sudo rm -f /var/service/docker
                    fi
                    printf '%s\n' "Docker autostart disabled."
                    ;;
                status)
                    if [ -e /var/service/docker ]; then
                        printf '%s\n' "Docker autostart: enabled"
                    else
                        printf '%s\n' "Docker autostart: disabled"
                    fi
                    ;;
                *)
                    printf '%s\n' "Usage: ai autostart [enable|disable|status]" >&2
                    return 2
                    ;;
            esac
            ;;
        help | *)
            printf '%s\n' \
                'Usage: ai [local [MODEL] [PROMPT]|claude|copilot|cursor|codex|odysseus|freellmapi|remote|health [deep]|status|models|logs|start|stop|autostart|help]' \
                'Examples:' \
                '  ai                         Choose a tool interactively' \
                '  ai local qwen3:14b        Run a local model' \
                '  ai claude                 Start Claude Code' \
                '  ai cursor                 Start Cursor Agent' \
                '  ai copilot                Start GitHub Copilot CLI' \
                '  ai codex                  Start OpenAI Codex CLI' \
                '  ai odysseus               Open the Odysseus web UI' \
                '  ai freellmapi             Open the FreeLLMAPI dashboard' \
                '  ai remote setup           Show Tailscale setup instructions' \
                '  ai remote status         List remote machines by name' \
                '  ai remote ssh laptop     Connect to a machine without its IP' \
                '  ai remote tunnel laptop ollama  Use a remote Ollama locally' \
                '  ai health                 Check services, containers, endpoints, and models' \
                '  ai health deep           Also run one small inference request per model' \
                '  ai status                 Check local services and models' \
                '  ai logs all               Show recent service logs' \
                '  ai start                  Start the AI stack in the background' \
                '  ai start docker           Start Docker only' \
                '  ai start tailscale       Start Tailscale using this machine name' \
                '  ai stop                   Stop the AI stack' \
                '  ai stop docker            Stop Docker only' \
                '  ai stop tailscale        Stop Tailscale' \
                '  ai autostart enable      Enable Docker autostart' \
                '  ai autostart disable     Remove Docker autostart'
            ;;
    esac
}

### Bluetooth

bt() {
    local action="${1:-status}"
    case "$action" in
        on | up | start)
            for svc in dbus bluetoothd; do
                if [ -d "/etc/sv/$svc" ] && [ ! -e "/var/service/$svc" ]; then
                    sudo ln -s "/etc/sv/$svc" "/var/service/$svc"
                fi
                [ -e "/var/service/$svc" ] && sudo sv up "$svc"
            done
            command -v rfkill >/dev/null 2>&1 && sudo rfkill unblock bluetooth || true
            command -v bluetoothctl >/dev/null 2>&1 \
                && printf 'power on\nagent on\ndefault-agent\nquit\n' | sudo bluetoothctl >/dev/null 2>&1 || true
            command -v hciconfig >/dev/null 2>&1 && sudo hciconfig hci0 up >/dev/null 2>&1 || true
            printf '%s\n' "Bluetooth started."
            ;;
        off | down | stop)
            command -v bluetoothctl >/dev/null 2>&1 \
                && printf 'disconnect\npower off\nquit\n' | sudo bluetoothctl --timeout 3 >/dev/null 2>&1 || true
            command -v hciconfig >/dev/null 2>&1 && sudo hciconfig hci0 down >/dev/null 2>&1 || true
            command -v rfkill >/dev/null 2>&1 && sudo rfkill block bluetooth || true
            if [ -e /var/service/bluetoothd ]; then
                sudo sv down bluetoothd
                sudo rm -f /var/service/bluetoothd
            fi
            printf '%s\n' "Bluetooth stopped and disabled."
            ;;
        status)
            printf '%-14s' "dbus"
            sv status dbus 2>/dev/null || printf '%s\n' "unavailable"
            printf '%-14s' "bluetoothd"
            sv status bluetoothd 2>/dev/null || printf '%s\n' "unavailable"
            command -v rfkill >/dev/null 2>&1 && rfkill list bluetooth 2>/dev/null | grep -E 'Soft blocked|Hard blocked' || true
            ;;
        *)
            printf '%s\n' "Usage: bt [on|off|status]" >&2
            return 2
            ;;
    esac
}

btup() { bt on; }
btdown() { bt off; }

### Virtualisation utilties

virt() {
    local action="${1:-status}" svc
    case "$action" in
        on | up | start)
            sudo mkdir -p /run/libvirt
            sudo chown root:root /run/libvirt
            for svc in libvirtd virtlogd virtlockd; do
                if [ -d "/etc/sv/$svc" ] && [ ! -e "/var/service/$svc" ]; then
                    sudo ln -s "/etc/sv/$svc" "/var/service/$svc"
                fi
                if [ -e "/var/service/$svc" ]; then
                    sudo sv up "$svc"
                elif command -v "$svc" >/dev/null 2>&1; then
                    sudo "$svc" --daemon
                fi
            done
            command -v virsh >/dev/null 2>&1 && virsh -c qemu:///system list --all
            ;;
        off | down | stop)
            for svc in virtlockd virtlogd libvirtd; do
                if [ -e "/var/service/$svc" ]; then
                    sudo sv down "$svc"
                    sudo rm -f "/var/service/$svc"
                elif pgrep -x "$svc" >/dev/null 2>&1; then
                    sudo pkill -x "$svc"
                fi
            done
            ;;
        status)
            for svc in libvirtd virtlogd virtlockd; do
                printf '%-12s' "$svc"
                sv status "$svc" 2>/dev/null || printf '%s\n' "unavailable"
            done
            command -v virsh >/dev/null 2>&1 && virsh -c qemu:///system list --all
            ;;
        *)
            printf '%s\n' "Usage: virt [on|off|status]" >&2
            return 2
            ;;
    esac
}

virtup() { virt on; }
virtdown() { virt off; }

### Other useful commands

a() {
    local tu104 hyperx current target

    tu104=$(pactl list sinks | awk '
        /^Sink #/ { name="" }
        /^[[:space:]]*Name:/ { name=$2 }
        /^[[:space:]]*Description:/ {
            desc=$0
            sub(/^[^:]*:[[:space:]]*/, "", desc)
            if (index(desc, "TU104 HD Audio Controller Digital Stereo (HDMI)") == 1)
                print name
        }
    ' | head -n1)

    hyperx=$(pactl list sinks | awk '
        /^Sink #/ { name="" }
        /^[[:space:]]*Name:/ { name=$2 }
        /^[[:space:]]*Description:/ {
            desc=$0
            sub(/^[^:]*:[[:space:]]*/, "", desc)
            if (index(desc, "HyperX Cloud III Analog Stereo") == 1)
                print name
        }
    ' | head -n1)

    current=$(pactl get-default-sink)

    if [[ "$current" == "$tu104" ]]; then
        target="$hyperx"
        echo "Switching to HyperX Cloud III"
    else
        target="$tu104"
        echo "Switching to TU104 HDMI"
    fi

    pactl set-default-sink "$target"

    pactl list short sink-inputs | cut -f1 | while read -r id; do
        pactl move-sink-input "$id" "$target"
    done
}

cc() {
    if [[ $# -ne 3 ]]; then
        echo "Usage: cc <amount> <from_currency> <to_currency>" >&2
        return 1
    fi

    local amount="$1"
    local from="${2^^}"
    local to="${3^^}"
    local response rate result

    if ! [[ "$amount" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "Error: amount must be a positive number" >&2
        return 1
    fi

    response="$(curl -fsS "https://api.frankfurter.dev/v2/rate/$from/$to")" || {
        echo "Error: API request failed" >&2
        return 1
    }

    rate="$(jq -er '.rate' <<<"$response")" || {
        echo "Error: unexpected API response" >&2
        return 1
    }

    result="$(awk -v amount="$amount" -v rate="$rate" 'BEGIN { printf "%.2f", amount * rate }')"
    printf "%s %s -> %s %s\n" "$amount" "$from" "$result" "$to"
}

tz() {
    if [[ $# -ne 3 ]]; then
        echo "Usage: tz HH:MM FROM_TZ TO_TZ"
        echo "Example: tz 12:30 BST CEST"
        return 1
    fi

    local time="${1,,}"
    local from="${2^^}"
    local to="${3^^}"
    local date_today
    local from_zone
    local to_zone

    declare -A zones=(
        [UTC]="UTC"
        [GMT]="Europe/London"
        [BST]="Europe/London"
        [CET]="Europe/Warsaw"
        [CEST]="Europe/Warsaw"
        [WET]="Europe/Lisbon"
        [WEST]="Europe/Lisbon"
        [EET]="Europe/Helsinki"
        [EEST]="Europe/Helsinki"

        [EST]="America/New_York"
        [EDT]="America/New_York"
        [CST]="America/Chicago"
        [CDT]="America/Chicago"
        [MST]="America/Denver"
        [MDT]="America/Denver"
        [PST]="America/Los_Angeles"
        [PDT]="America/Los_Angeles"

        [JST]="Asia/Tokyo"
        [KST]="Asia/Seoul"
        [IST]="Asia/Kolkata"
        [AEST]="Australia/Sydney"
        [AEDT]="Australia/Sydney"
    )

    from_zone="${zones[$from]}"
    to_zone="${zones[$to]}"

    if [[ -z "$from_zone" ]]; then
        echo "Unknown source timezone: $from"
        return 1
    fi

    if [[ -z "$to_zone" ]]; then
        echo "Unknown target timezone: $to"
        return 1
    fi

    if [[ ! "$time" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        echo "Invalid time: $1 (use HH:MM)"
        return 1
    fi

    date_today=$(date +%Y-%m-%d)

    TZ="$to_zone" date -d "TZ=\"$from_zone\" $date_today $time" "+$to: %H:%M"
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
alias ..='z ..'
alias ...='z ../..'
alias ....='z ../../..'
alias .....='z ../../../..'

alias r='bat'
alias e='nvim'
alias m='micro'
alias ee='micro'
alias nano='micro'
alias pdf='zathura'
alias ff='fastfetch'
alias open='xdg-open'
alias lt='e leetcode.nvim'
alias qr="zbarimg -q --raw"

alias torus='$___name'
alias rpi='$___rel_ssh'
rpi-raw() {
    local target=${RPI_SSH_TARGET:-}
    local key=${RPI_SSH_KEY:-}
    local port=${RPI_SSH_PORT:-22}
    if [ -z "$target" ]; then
        printf '%s
' "Set RPI_SSH_TARGET in ~/.config/secrets/env first." >&2
        return 2
    fi
    local -a ssh_args
    ssh_args=(-p "$port")
    [ -z "$key" ] || ssh_args+=(-i "$key")
    ssh "${ssh_args[@]}" "$target" "$@"
}
alias piwatch='tmux -L piwatch a -t piwatch'

alias lh='du -sh *'
alias ls='ls --color=auto'
alias la='ls -A --color=auto'
alias ll='ls -lah --color=auto'
alias lhh='du -sh -- * .[!.]* 2>/dev/null'

alias sandbox='firejail --private=. bash'

# Obsolete
alias prolog="setsid swipl-win & disown"
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

_cnf_jump_file="${XDG_RUNTIME_DIR:-/tmp}/bash-cnf-jump.$$"

_cnf_jump() {
    [ -f "$_cnf_jump_file" ] || return 0

    local dir
    dir=$(<"$_cnf_jump_file")
    rm -f -- "$_cnf_jump_file"
    builtin cd -- "$dir"
}

PROMPT_COMMAND='_cnf_jump'

PS1='\[\e[1;37m\][\u@\h \[\e[90m\]$(_short_path)\[\e[0m\]\[\e[1;37m\]]\[\e[0m\]\$ '

export EDITOR=micro
export VISUAL=micro

# Zoxide
eval "$(zoxide init bash)" 2>/dev/null || true

command_not_found_handle() {
    local cmd="$1"

    case "$cmd" in
        */* | . | .. | ~*)
            printf 'bash: %s: command not found\n' "$cmd" >&2
            return 127
            ;;
    esac

    local dir
    dir="$(zoxide query "$cmd" 2>/dev/null)" || {
        printf 'bash: %s: command not found\n' "$cmd" >&2
        return 127
    }

    printf '%s' "$dir" >"$_cnf_jump_file"
}

cd() {
    z "$@"
}

shopt -s autocd

# Created by `pipx` on 2026-03-23 13:01:31
export PATH="$PATH:$HOME/.local/bin"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export MANPATH="$HOME/.local/share/man:${MANPATH:-}"

_dedupe_path() {
    local -a dirs
    local -A seen=()
    local dir out="" first=1

    IFS=: read -ra dirs <<<"${!1}:"
    for dir in "${dirs[@]}"; do
        [[ -n ${seen[x$dir]} ]] && continue
        seen[x$dir]=1
        if [[ $first -eq 1 ]]; then
            out="$dir"
            first=0
        else
            out+=":$dir"
        fi
    done

    printf -v "$1" '%s' "$out"
}

_dedupe_path PATH
_dedupe_path MANPATH

command -v tracker >/dev/null 2>&1 && eval "$(tracker completion bash)"
