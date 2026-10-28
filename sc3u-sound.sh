#!/bin/sh -e
# Install and enable osspd so SimCity 3000 can use OSS audio.
#
# This helper currently automates Debian/Ubuntu. On other distributions it
# prints the manual steps and exits with an error. Package installation is kept
# out of sc3u-patcher.sh so other distributions can be added here without
# making the patcher distribution-specific.

if [ "$(id -u)" -eq 0 ]; then
  SUDO=
else
  SUDO=sudo
fi

usage() {
  cat <<EOF
Usage: $0 [--check|--help]

Install and start osspd (OSS audio emulation through PulseAudio/PipeWire).

  (no option)  Install osspd, start it, and verify /dev/dsp
  --check      Only check whether OSS sound is available
  -h, --help   Show this help

This script automates Debian/Ubuntu. See README.md for other distributions.
EOF
}

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed$'
}

check_sound() {
  [ -e /dev/dsp ] || return 1
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active --quiet osspd
  elif command -v service >/dev/null 2>&1; then
    service osspd status >/dev/null 2>&1
  else
    return 0
  fi
}

ACTION=install
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check|--status)
      ACTION=check
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ "${ACTION}" = check ]; then
  if check_sound; then
    echo "OSS sound is available (/dev/dsp present and osspd active)"
    exit 0
  fi
  echo "OSS sound is not available (/dev/dsp missing or osspd not running)" >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1 ||
   ! command -v dpkg-query >/dev/null 2>&1; then
  echo "ERROR: This helper only automates Debian/Ubuntu for now." >&2
  echo "See README.md for manual osspd setup on your distribution." >&2
  exit 1
fi

if pkg_installed osspd && pkg_installed osspd-pulseaudio; then
  echo "osspd is already installed"
else
  echo "Installing osspd and osspd-pulseaudio"
  ${SUDO} env DEBIAN_FRONTEND=noninteractive apt-get update
  ${SUDO} env DEBIAN_FRONTEND=noninteractive apt-get install -y osspd osspd-pulseaudio
fi

${SUDO} modprobe cuse >/dev/null 2>&1 || true

if command -v systemctl >/dev/null 2>&1; then
  ${SUDO} systemctl enable --now osspd
elif command -v service >/dev/null 2>&1; then
  ${SUDO} service osspd start || true
fi

# Give osspd a moment to create /dev/dsp
i=0
while [ "${i}" -lt 5 ] && [ ! -e /dev/dsp ]; do
  sleep 1
  i=$((i + 1))
done

if check_sound; then
  echo "OSS sound is available: $(ls -l /dev/dsp)"
else
  echo "WARNING: osspd is installed but OSS sound is not available." >&2
  echo "Check: systemctl status osspd" >&2
  echo "Also make sure the cuse kernel module is available." >&2
  exit 1
fi
