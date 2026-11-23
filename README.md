# .bashrc

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

My .bashrc for my Void Linux machines, with system, packaging, media and programming utilities.

## Features

It's a pretty complex script, has all of my system, programming +more utilities. Maybe it will also be of use to someone else.  
Makes life a lot easier.

## Requirements

| Function / alias                               | Needs                                                                                                                                                                                                                                                                 |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `install`, `remove`, `removeoldkernels`        | `xbps`, `vkpurge`, `sudo` (Void only)                                                                                                                                                                                                                                 |
| `update`                                       | `xbps` or an `update` command; `rustup`, `flatpak` if installed                                                                                                                                                                                                       |
| `mvp`, `mvpr`                                  | `rsync`                                                                                                                                                                                                                                                               |
| `yt`                                           | `yt-dlp`, `ffmpeg`; `xdg-user-dir` for the download folder                                                                                                                                                                                                            |
| `reloadcaddy`                                  | `caddy`, `sudo`                                                                                                                                                                                                                                                       |
| `copy`, `imgtxt`, `cpimgtxt`                   | `xclip` (X11); `imgtxt` also ImageMagick's `magick` and `tesseract-ocr`                                                                                                                                                                                               |
| `topdf`                                        | LibreOffice (`soffice`)                                                                                                                                                                                                                                               |
| `rmexif`                                       | `exiftool`                                                                                                                                                                                                                                                            |
| `compress`, `peek`                             | `tar`, `xz`, `gzip`, `bzip2`, `zstd`, `lz4`, `zip`, `unzip`, `7z`, `file`; `rar` / `unrar` for RAR                                                                                                                                                                    |
| `md`                                           | `glow`                                                                                                                                                                                                                                                                |
| `activate`, `workon`                           | `python3` with `venv`                                                                                                                                                                                                                                                 |
| `minify`                                       | `esbuild`, `rsync`                                                                                                                                                                                                                                                    |
| `gitrepo`, `gitremake`, `gitdiff`, `gitgraph`  | `git`                                                                                                                                                                                                                                                                 |
| `gitpr`                                        | `git`, `gh`, `tea`                                                                                                                                                                                                                                                    |
| `rpi`, `rpi-up`, `rpi-dl`, `rpi-ls`, `rpi-raw` | `ssh`; `pv` for progress                                                                                                                                                                                                                                              |
| `tssh`, `tcopy`, `tmove`                       | `tailscale`, `ssh`, `rsync`                                                                                                                                                                                                                                           |
| `c`                                            | `g++` new enough for `-std=gnu++26`                                                                                                                                                                                                                                   |
| `rdoc`                                         | `rustup` with the `rust-docs` component, `rg`, `fzf`, `bat`, `w3m`, `xmllint`, `curl`                                                                                                                                                                                 |
| `bt`, `btup`, `btdown`                         | runit, `bluez`, `rfkill`, `sudo`                                                                                                                                                                                                                                      |
| `virt`, `virtup`, `virtdown`                   | runit, `libvirt`, `sudo`                                                                                                                                                                                                                                              |
| `a`                                            | `pactl`                                                                                                                                                                                                                                                               |
| `cc`                                           | `curl`, `jq`                                                                                                                                                                                                                                                          |
| `tz`                                           | GNU `date`                                                                                                                                                                                                                                                            |
| Aliases                                        | `bat` (`r`), `nvim` (`e`, `lt`), `micro` (`m`, `ee`, `nano`), `gdu` (`disk`), `zathura` (`pdf`), `fastfetch` (`ff`), `xdg-open` (`open`), `zbarimg` (`qr`), `tmux` (`piwatch`), `firejail` (`sandbox`); leftovers `prolog` (`swipl-win`) and `rundockerdb` (`docker`) |

## Install

### The file

Back up your own `~/.bashrc` first; this replaces it:

```sh
curl -fsSL https://raw.githubusercontent.com/MattFor/.bashrc/master/.bashrc -o ~/.bashrc
```

### Packages

Everything above that has a package. `caddy`, `bluez`, `libvirt` and the non-free RAR tools are left out: add them if you use `reloadcaddy`, `bt`, `virt` or RAR archives.

```sh
# Void
sudo xbps-install -S zoxide micro neovim bat fzf ripgrep w3m libxml2 curl jq rsync glow gdu yt-dlp ffmpeg xclip ImageMagick tesseract-ocr tesseract-ocr-eng libreoffice exiftool zbar xz gzip bzip2 zstd lz4 zip unzip file 7zip python3 esbuild git github-cli tea openssh pv tailscale gcc rustup firejail fastfetch zathura zathura-pdf-mupdf xdg-utils xdg-user-dirs tmux
# Debian, Ubuntu
sudo apt install zoxide micro neovim bat fzf ripgrep w3m libxml2-utils curl jq rsync glow gdu yt-dlp ffmpeg xclip imagemagick tesseract-ocr libreoffice libimage-exiftool-perl zbar-tools xz-utils gzip bzip2 zstd lz4 zip unzip file 7zip python3 python3-venv esbuild git gh openssh-client pv g++ rustup firejail fastfetch zathura xdg-utils xdg-user-dirs tmux
# Fedora
sudo dnf install zoxide micro neovim bat fzf ripgrep w3m libxml2 curl jq rsync glow gdu yt-dlp ffmpeg-free xclip ImageMagick tesseract libreoffice perl-Image-ExifTool zbar xz gzip bzip2 zstd lz4 zip unzip file 7zip python3 golang-github-evanw-esbuild git gh openssh-clients pv tailscale gcc-c++ rustup firejail fastfetch zathura zathura-pdf-poppler xdg-utils xdg-user-dirs tmux
# Arch
sudo pacman -S --needed zoxide micro neovim bat fzf ripgrep w3m libxml2 curl jq rsync glow gdu yt-dlp ffmpeg xclip imagemagick tesseract tesseract-data-eng libreoffice-fresh perl-image-exiftool zbar xz gzip bzip2 zstd lz4 zip unzip file 7zip python esbuild git github-cli openssh pv tailscale gcc rustup firejail fastfetch zathura zathura-pdf-mupdf xdg-utils xdg-user-dirs tmux
# openSUSE Tumbleweed
sudo zypper install zoxide micro-editor neovim bat fzf ripgrep w3m libxml2-tools curl jq rsync glow gdu yt-dlp ffmpeg xclip ImageMagick tesseract-ocr tesseract-ocr-traineddata-eng libreoffice exiftool zbar xz gzip bzip2 zstd lz4 zip unzip file 7zip python3 esbuild git gh gitea-tea openssh-clients pv tailscale gcc-c++ rustup firejail fastfetch zathura zathura-plugin-pdf-poppler xdg-utils xdg-user-dirs tmux
# Alpine (community repo), with the GNU tools busybox lacks
sudo apk add bash coreutils findutils tar zoxide micro neovim bat fzf ripgrep w3m libxml2-utils curl jq rsync gdu yt-dlp ffmpeg xclip imagemagick tesseract-ocr tesseract-ocr-data-eng libreoffice exiftool zbar xz gzip bzip2 zstd lz4 zip unzip file 7zip python3 esbuild git github-cli tea openssh-client-default pv tailscale g++ rustup fastfetch zathura zathura-pdf-mupdf xdg-utils xdg-user-dirs tmux
# Termux (no X11, so no clipboard, OCR, PDF viewer or LibreOffice)
pkg install zoxide micro neovim bat fzf ripgrep w3m libxml2-utils curl jq rsync glow gdu python-yt-dlp ffmpeg exiftool zbar xz-utils gzip bzip2 zstd lz4 zip unzip file 7zip python esbuild git gh tea openssh pv clang fastfetch tmux
```

| Missing     | From                                       | Get it                                                                                                                                                                                                                           |
| ----------- | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tea`       | apt, dnf, pacman                           | [Release binaries](https://gitea.com/gitea/tea/releases); Arch: AUR                                                                                                                                                              |
| `tailscale` | apt, Termux                                | apt: `curl -fsSL https://tailscale.com/install.sh \| sh`; Termux: the static arm64 build from [pkgs.tailscale.com](https://pkgs.tailscale.com/stable/#static), `tailscaled` in userspace mode with its socket in `~/.tailscale/` |
| `glow`      | Alpine (edge only), older Ubuntu           | [Release binaries](https://github.com/charmbracelet/glow/releases)                                                                                                                                                               |
| `fastfetch` | older Ubuntu                               | [Release binaries](https://github.com/fastfetch-cli/fastfetch/releases)                                                                                                                                                          |
| `firejail`  | Alpine, Termux                             | Not available                                                                                                                                                                                                                    |
| `rustup`    | Termux                                     | [rustup.rs](https://rustup.rs) installer (untested there)                                                                                                                                                                        |
| `rar`       | all but Debian non-free, Ubuntu multiverse | [rarlab.com](https://www.rarlab.com); `unrar` alone is enough for `peek` and is in Debian non-free, Ubuntu multiverse, Arch, openSUSE non-oss, Termux and Void's nonfree repo                                                    |

### Other systems

Parts that assume Void machines:

| Part                                    | Elsewhere                                                                                                                                       |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `install`, `remove`, `removeoldkernels` | Defined only when `xbps-install` exists, so `install` stays coreutils' elsewhere                                                                |
| `update`                                | Runs `xbps-install -Syu`, else an `update` command on `PATH`, then `rustup` and `flatpak`; put your own upgrade in an `update` script           |
| `bt`, `virt` and their aliases          | Drive runit services (`/etc/sv`, `/var/service`, `sv`); on systemd start them with `systemctl` (`virt` starts the daemons itself without runit) |
| `imgtxt`                                | Calls `tesseract-ocr`, Void's name for `tesseract`: `ln -s "$(command -v tesseract)" ~/.local/bin/tesseract-ocr`                                |
| `a`                                     | Switches between two of my audio devices by name; edit them                                                                                     |

## License

MIT, see [LICENSE](LICENSE). By [MattFor](https://github.com/MattFor).
