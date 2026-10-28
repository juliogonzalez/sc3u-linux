#!/bin/sh -e
# Reversible widescreen/HD resolution patch for SimCity 3000 Unlimited.
#
# The native game binary (sc3u.dynamic) only accepts a small hardcoded set of
# 4:3 startup resolutions. This patch modifies two routines and three display
# mode table entries in place:
#
#   FixStartupResolutionValuesIfNeeded
#       Stops rewriting an unsupported startup resolution to a 4:3 fallback.
#   IsStartupResolutionOK
#       Always reports the requested startup resolution as valid.
#
# The high 4:3 mode table entries are replaced with widescreen modes:
#
#   1152x864   -> 1280x720
#   1280x1024  -> 1920x1080
#   1600x1200  -> 2560x1440
#
# The unpatched binary is copied to sc3u.dynamic.orig the first time the patch
# is applied, so the change can be reverted.
#
# Based on https://github.com/lfbr0/simcity3000-linux-widescreen-patch
#
# The mode table entries below are x86 `movl $WIDTH,-0x24(%ebp)` and
# `movl $HEIGHT,-0x20(%ebp)` instructions. *_ORIG_HEX describes the original
# 4:3 values and *_PATCHED_HEX the replacement widescreen values.

DEFAULT_SC3U_PATH=/usr/local/games/SC3U
SC3U_PATH=${SC3U_PATH:-${DEFAULT_SC3U_PATH}}

FIX_ORIG_HEX=5589e5568b750c8b4d108b1681fa8002
CHECK_ORIG_HEX=5589e58b550c8b4d10b0
MODE1_ORIG_HEX=c745dc80040000c745e060030000
MODE2_ORIG_HEX=c745dc00050000c745e000040000
MODE3_ORIG_HEX=c745dc40060000c745e0b0040000

FIX_PATCHED_HEX=5589e5568b750c8b4d108b0685c0740b8b1185d274055e89ec5dc3c70680020000c701e00100005e89ec5dc3
CHECK_PATCHED_HEX=b001c390909090909090909090909090
MODE1_PATCHED_HEX=c745dc00050000c745e0d0020000
MODE2_PATCHED_HEX=c745dc80070000c745e038040000
MODE3_PATCHED_HEX=c745dc000a0000c745e0a0050000

fix_patched_bytes() {
  printf '\125\211\345\126\213\165\014\213\115\020\213\006\205\300\164\013\213\021\205\322\164\005\136\211\354\135\303\307\006\200\002\000\000\307\001\340\001\000\000\136\211\354\135\303'
}

check_patched_bytes() {
  printf '\260\001\303\220\220\220\220\220\220\220\220\220\220\220\220\220'
}

mode1_patched_bytes() {
  printf '\307\105\334\000\005\000\000\307\105\340\320\002\000\000'
}

mode2_patched_bytes() {
  printf '\307\105\334\200\007\000\000\307\105\340\070\004\000\000'
}

mode3_patched_bytes() {
  printf '\307\105\334\000\012\000\000\307\105\340\240\005\000\000'
}

if [ "$(id -u)" -eq 0 ]; then
  SUDO=
else
  SUDO=sudo
fi

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] [ACTION]

Unlock widescreen and other high resolutions in SimCity 3000 Unlimited.

Actions:
  --apply          Apply the patch (default)
  --status         Show whether the patch is applied
  --revert         Restore sc3u.dynamic from the backup

Options:
  -p, --path DIR   Game installation directory
                   (default: ${DEFAULT_SC3U_PATH})
  -h, --help       Show this help

The patch replaces these display modes:
  1152x864   -> 1280x720
  1280x1024  -> 1920x1080
  1600x1200  -> 2560x1440

Only use a mode your display supports. Width and height must be divisible by 8.
The game interface does not scale, so it may look small at high resolutions.
EOF
}

bytes_at() {
  FILE=$1
  OFFSET=$2
  COUNT=$3
  od -An -v -tx1 -j "${OFFSET}" -N "${COUNT}" "${FILE}" | tr -d ' \n'
}

ACTION=apply
while [ "$#" -gt 0 ]; do
  case "$1" in
    apply|--apply|--enable)
      ACTION=apply
      ;;
    --status)
      ACTION=status
      ;;
    --revert|--disable)
      ACTION=revert
      ;;
    -p|--path)
      shift
      if [ "$#" -eq 0 ] || [ -z "$1" ]; then
        echo "ERROR: --path requires a directory" >&2
        exit 1
      fi
      SC3U_PATH=$1
      ;;
    --path=*)
      SC3U_PATH=${1#*=}
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

BIN="${SC3U_PATH}/sc3u.dynamic"
BACKUP="${BIN}.orig"

# Check for required programs
RPROGRAMS="grep awk dd cp id od tr mktemp"
for RPROGRAM in ${RPROGRAMS}; do
  if ! command -v "${RPROGRAM}" >/dev/null 2>&1; then
    echo "ERROR: Required binary ${RPROGRAM} not found. Install it to proceed" >&2
    exit 1
  fi
done

if [ "${ACTION}" = revert ]; then
  if [ ! -f "${BACKUP}" ]; then
    echo "ERROR: Backup not found: ${BACKUP}" >&2
    exit 1
  fi
  ${SUDO} cp -p "${BACKUP}" "${BIN}"
  echo "Restored ${BIN} from ${BACKUP}"
  exit 0
fi

if [ ! -f "${BIN}" ]; then
  echo "ERROR: ${BIN} not found. Run sc3u-patcher.sh first." >&2
  exit 1
fi

HEXFILE=$(mktemp "${TMPDIR:-/tmp}/sc3u-widescreen.XXXXXX")
trap 'rm -f "${HEXFILE}"' EXIT

find_offset() {
  PATTERN=$1
  LC_ALL=C grep -b -o -F -- "${PATTERN}" "${HEXFILE}" 2>/dev/null |
    awk -F: '($1 % 2) == 0 { print $1 / 2; exit }'
}

# The backup is always an unpatched copy, so use it to locate the functions
# once it exists. Avoids matching patched bytes elsewhere in the binary.
ORIG_SRC=${BIN}
if [ -f "${BACKUP}" ]; then
  ORIG_SRC=${BACKUP}
fi

od -An -v -tx1 "${ORIG_SRC}" | tr -d ' \n' > "${HEXFILE}"

FIX_OFFSET=$(find_offset "${FIX_ORIG_HEX}")
CHECK_OFFSET=$(find_offset "${CHECK_ORIG_HEX}")
MODE1_OFFSET=$(find_offset "${MODE1_ORIG_HEX}")
MODE2_OFFSET=$(find_offset "${MODE2_ORIG_HEX}")
MODE3_OFFSET=$(find_offset "${MODE3_ORIG_HEX}")

if [ -z "${FIX_OFFSET}" ] || [ -z "${CHECK_OFFSET}" ] ||
   [ -z "${MODE1_OFFSET}" ] || [ -z "${MODE2_OFFSET}" ] ||
   [ -z "${MODE3_OFFSET}" ]; then
  echo "ERROR: Unexpected ${ORIG_SRC} version (resolution code not found)" >&2
  exit 1
fi

# Prints: patched, original, or unknown
check_state() {
  OFFSET=$1
  ORIG_HEX=$2
  PATCHED_HEX=$3
  PATCHED_LEN=$((${#PATCHED_HEX} / 2))
  ORIG_LEN=$((${#ORIG_HEX} / 2))

  if [ "$(bytes_at "${BIN}" "${OFFSET}" "${PATCHED_LEN}")" = "${PATCHED_HEX}" ]; then
    echo patched
  elif [ "$(bytes_at "${BIN}" "${OFFSET}" "${ORIG_LEN}")" = "${ORIG_HEX}" ]; then
    echo original
  else
    echo unknown
  fi
}

FIX_STATE=$(check_state "${FIX_OFFSET}" "${FIX_ORIG_HEX}" "${FIX_PATCHED_HEX}")
CHECK_STATE=$(check_state "${CHECK_OFFSET}" "${CHECK_ORIG_HEX}" "${CHECK_PATCHED_HEX}")
MODE1_STATE=$(check_state "${MODE1_OFFSET}" "${MODE1_ORIG_HEX}" "${MODE1_PATCHED_HEX}")
MODE2_STATE=$(check_state "${MODE2_OFFSET}" "${MODE2_ORIG_HEX}" "${MODE2_PATCHED_HEX}")
MODE3_STATE=$(check_state "${MODE3_OFFSET}" "${MODE3_ORIG_HEX}" "${MODE3_PATCHED_HEX}")

if [ "${ACTION}" = status ]; then
  if [ "${FIX_STATE}" = patched ] && [ "${CHECK_STATE}" = patched ] &&
     [ "${MODE1_STATE}" = patched ] && [ "${MODE2_STATE}" = patched ] &&
     [ "${MODE3_STATE}" = patched ]; then
    echo "Widescreen patch: applied"
    exit 0
  elif [ "${FIX_STATE}" = original ] && [ "${CHECK_STATE}" = original ] &&
       [ "${MODE1_STATE}" = original ] && [ "${MODE2_STATE}" = original ] &&
       [ "${MODE3_STATE}" = original ]; then
    echo "Widescreen patch: not applied"
    exit 0
  else
    echo "Widescreen patch: inconsistent (fix=${FIX_STATE}, check=${CHECK_STATE}, mode1=${MODE1_STATE}, mode2=${MODE2_STATE}, mode3=${MODE3_STATE})" >&2
    exit 1
  fi
fi

if [ ! -f "${BACKUP}" ] &&
   { [ "${FIX_STATE}" = patched ] || [ "${CHECK_STATE}" = patched ] ||
     [ "${MODE1_STATE}" = patched ] || [ "${MODE2_STATE}" = patched ] ||
     [ "${MODE3_STATE}" = patched ]; }; then
  echo "ERROR: ${BACKUP} is missing but ${BIN} is partially patched." >&2
  echo "Restore an unpatched copy before applying this patch." >&2
  exit 1
fi

apply_patch() {
  LABEL=$1
  OFFSET=$2
  STATE=$3
  BYTES_FN=$4

  case "${STATE}" in
    patched)
      echo "${LABEL}: already patched"
      ;;
    original)
      if [ ! -f "${BACKUP}" ]; then
        echo "Creating backup: ${BACKUP}"
        ${SUDO} cp -p "${BIN}" "${BACKUP}"
      fi
      echo "${LABEL}: patching at offset ${OFFSET}"
      "${BYTES_FN}" | ${SUDO} dd of="${BIN}" bs=1 seek="${OFFSET}" conv=notrunc status=none
      ;;
    *)
      echo "ERROR: ${LABEL}: unexpected bytes at offset ${OFFSET}" >&2
      return 1
      ;;
  esac
}

apply_patch "FixStartupResolutionValuesIfNeeded" "${FIX_OFFSET}" "${FIX_STATE}" fix_patched_bytes
apply_patch "IsStartupResolutionOK" "${CHECK_OFFSET}" "${CHECK_STATE}" check_patched_bytes
apply_patch "Display mode 1280x720" "${MODE1_OFFSET}" "${MODE1_STATE}" mode1_patched_bytes
apply_patch "Display mode 1920x1080" "${MODE2_OFFSET}" "${MODE2_STATE}" mode2_patched_bytes
apply_patch "Display mode 2560x1440" "${MODE3_OFFSET}" "${MODE3_STATE}" mode3_patched_bytes

if [ "$(check_state "${FIX_OFFSET}" "${FIX_ORIG_HEX}" "${FIX_PATCHED_HEX}")" != patched ] ||
   [ "$(check_state "${CHECK_OFFSET}" "${CHECK_ORIG_HEX}" "${CHECK_PATCHED_HEX}")" != patched ] ||
   [ "$(check_state "${MODE1_OFFSET}" "${MODE1_ORIG_HEX}" "${MODE1_PATCHED_HEX}")" != patched ] ||
   [ "$(check_state "${MODE2_OFFSET}" "${MODE2_ORIG_HEX}" "${MODE2_PATCHED_HEX}")" != patched ] ||
   [ "$(check_state "${MODE3_OFFSET}" "${MODE3_ORIG_HEX}" "${MODE3_PATCHED_HEX}")" != patched ]; then
  echo "ERROR: Patch verification failed" >&2
  exit 1
fi

cat <<EOF

Widescreen patch applied.

Start the game, open the in-game video/display options, and choose one of:
    1280x720
    1920x1080
    2560x1440

Only choose a mode your display actually supports. Width and height must be
divisible by 8; modes such as 1366x768, 1600x900 and 1440x900 are unsafe.
The game interface does not scale, so it may look small at high resolutions.

Revert with:
    $0 --revert
EOF
