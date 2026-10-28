#!/bin/sh -e
PATCH_FNAME='sc3u-2.0a-x86.run'
PATCH_FIX='sc3u-2.0a-x86.run.patch'
LOKI_COMPAT='loki_compat_libs-1.5.tar.bz2'
SC3U_PATH=${SC3U_PATH:-/usr/local/games/SC3U}
CDROM_PATH=${CDROM_PATH:-/mnt}
BINDIR=${BINDIR:-/usr/local/bin}
BASE_BIN_PATH="$CDROM_PATH/bin/x86/glibc-2.1"
PATCH_URL='https://updates.lokigames.com/sc3u'
LOKI_URL='https://www.improbability.net/loki'
SKIP_SOUND_CHECK=0

if [ "$(id -u)" -eq 0 ]; then
  SUDO=
else
  SUDO=sudo
fi

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Prepare SimCity 3000 Unlimited to run on modern GNU/Linux systems.

Options:
  --skip-sound-check   Continue even if /dev/dsp or the osspd service is missing
  -h, --help           Show this help

Environment:
  SC3U_PATH    Game installation directory (default: /usr/local/games/SC3U)
  CDROM_PATH   Mount point of the game CD/ISO (default: /mnt)
  BINDIR       Directory for the sc3u launcher (default: /usr/local/bin)
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-sound-check|--no-sound)
      SKIP_SOUND_CHECK=1
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

sound_service_active() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active --quiet osspd
  elif command -v service >/dev/null 2>&1; then
    service osspd status >/dev/null 2>&1
  else
    return 0
  fi
}

check_sound() {
  [ -e /dev/dsp ] || return 1
  sound_service_active
}

if [ "${SKIP_SOUND_CHECK}" -eq 0 ] && ! check_sound; then
  echo "ERROR: OSS sound is not available: /dev/dsp is missing or the osspd service is not running." >&2
  echo "Run ./sc3u-sound.sh (Debian/Ubuntu) or follow the README instructions for your distribution." >&2
  echo "Use --skip-sound-check to continue without sound." >&2
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")
cd "${SCRIPT_DIR}"

# Check for required programs
RPROGRAMS="cat chmod cp curl grep install linux32 ln mktemp patch rm sleep tar"
for RPROGRAM in ${RPROGRAMS}; do
  if ! command -v "${RPROGRAM}" >/dev/null 2>&1; then
    echo "ERROR: Required binary ${RPROGRAM} not found. Install it to proceed"
    exit 1
  fi
done

if [ -n "${SUDO}" ] && ! command -v sudo >/dev/null 2>&1; then
  echo "ERROR: sudo is required when not running as root" >&2
  exit 1
fi

if [ ! -d "${SC3U_PATH}" ]; then
  echo "ERROR: ${SC3U_PATH} not found. Install the game first."
  exit 1
fi

# The original Loki installer needs 32-bit compatibility and on some modern
# 64-bit distributions (for example Ubuntu 24.04 amd64) it may fail or install
# only the data files. Complete the missing binary part from the mounted CD/ISO.
if [ ! -d "${SC3U_PATH}/lib" ] || [ ! -x "${SC3U_PATH}/sc3u" ]; then
  if [ ! -x "${BASE_BIN_PATH}/sc3u" ] || [ ! -d "${BASE_BIN_PATH}/lib" ]; then
    echo "ERROR: Base game binaries not found under ${BASE_BIN_PATH}."
    echo "Mount the SimCity 3000 Unlimited CD/ISO on ${CDROM_PATH}, or set CDROM_PATH."
    exit 1
  fi
  echo "Installing missing base game binaries from ${BASE_BIN_PATH}"
  ${SUDO} install -d "${SC3U_PATH}/lib"
  ${SUDO} cp -a "${BASE_BIN_PATH}/lib/." "${SC3U_PATH}/lib/"
  ${SUDO} chmod -R u+w "${SC3U_PATH}/lib"
  if [ ! -x "${SC3U_PATH}/sc3u" ]; then
    ${SUDO} install -m755 "${BASE_BIN_PATH}/sc3u" "${SC3U_PATH}/sc3u"
  fi
  if [ ! -x "${SC3U_PATH}/sc3bat" ] && [ -x "${BASE_BIN_PATH}/sc3bat" ]; then
    ${SUDO} install -m755 "${BASE_BIN_PATH}/sc3bat" "${SC3U_PATH}/sc3bat"
  fi
fi

# Download the official 2.0a patch
if [ ! -f "${PATCH_FNAME}" ]; then
  echo "Downloading ${PATCH_FNAME}"
  curl -fL "${PATCH_URL}/${PATCH_FNAME}" -o "${PATCH_FNAME}"
fi

# Fix compatibility problems with modern POSIX shells
if ! grep -aq '^skip=180' "${PATCH_FNAME}" || \
   ! grep -aqF 'script="linux32 ./update.sh"' "${PATCH_FNAME}" || \
   ! grep -aqF "tail -n +\$skip" "${PATCH_FNAME}"; then
  echo "Applying linux32/POSIX compatibility fixes to the patch"
  patch -p0 < "${PATCH_FIX}"
fi

# Run the patch, unless it was already applied
if [ -x "${SC3U_PATH}/sc3u.dynamic" ] && [ -f "${SC3U_PATH}/README-2.0a" ]; then
  echo "SimCity 3000 2.0a update already applied"
else
  echo "Applying SimCity 3000 Unlimited 2.0a update"
  PATCH_TMP=$(mktemp -d "${TMPDIR:-/tmp}/sc3u-patch.XXXXXX")
  PATCH_DIR="${PATCH_TMP}/sc3u-2.0a"
  if ! ${SUDO} sh "${PATCH_FNAME}" --keep --target "${PATCH_DIR}" "${SC3U_PATH}"; then
    echo "ERROR: The 2.0a update failed. Extracted patch kept at ${PATCH_DIR}"
    exit 1
  fi
  ${SUDO} rm -rf "${PATCH_TMP}"
fi

# Download and install the Loki compatibility libraries
echo "Installing Loki compatibility libraries"
if [ ! -f "${LOKI_COMPAT}" ]; then
  curl -fL "${LOKI_URL}/${LOKI_COMPAT}" -o "${LOKI_COMPAT}"
fi
${SUDO} tar -xjf "${LOKI_COMPAT}" -C "${SC3U_PATH}"

for LIB in ld-linux.so.2 libSDL-1.1.so.0 libsmpeg-0.4.so.0 libopenal-0.0.so; do
  if [ ! -e "${SC3U_PATH}/Loki_Compat/${LIB}" ]; then
    echo "ERROR: ${LIB} not found in Loki_Compat after extraction"
    exit 1
  fi
done

# Install a launcher, keeping the patched static binary as sc3u.old
if ! grep -aq 'Loki_Compat/ld-linux.so.2' "${SC3U_PATH}/sc3u" 2>/dev/null; then
  ${SUDO} cp -p "${SC3U_PATH}/sc3u" "${SC3U_PATH}/sc3u.old"
fi

LAUNCHER=$(mktemp "${TMPDIR:-/tmp}/sc3u-launcher.XXXXXX")
trap 'rm -f "${LAUNCHER}"' EXIT
cat > "${LAUNCHER}" <<EOF
#!/bin/sh
SCPATH='${SC3U_PATH}'
cd "\$SCPATH" || exit 1
export LD_LIBRARY_PATH="\$SCPATH/lib:\$SCPATH/Loki_Compat"
export LD_ASSUME_KERNEL=2.2.5
export LANG=en_US.UTF-8
export SDL_AUDIODRIVER=dsp
export AUDIODEV=/dev/dsp
export SDL_VIDEO_YUV_HWACCEL=0
exec "\$SCPATH/Loki_Compat/ld-linux.so.2" "\$SCPATH/sc3u.dynamic" "\$@"
EOF
${SUDO} install -m755 "${LAUNCHER}" "${SC3U_PATH}/sc3u"
rm -f "${LAUNCHER}"
${SUDO} install -d "${BINDIR}"
${SUDO} ln -sf "${SC3U_PATH}/sc3u" "${BINDIR}/sc3u"

cat <<EOF

SimCity 3000 Unlimited setup complete.

Run windowed first:
    sc3u -w

If that works, run fullscreen:
    sc3u

For sound setup or troubleshooting, use ./sc3u-sound.sh, or see:
    systemctl status osspd
    ls -l /dev/dsp
EOF
