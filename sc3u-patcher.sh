#!/bin/sh -e
PATCH_FNAME='sc3u-2.0a-x86.run'
LOKI_COMPAT='loki_compat_libs-1.5.tar.bz2'
SC3U_PATH='/usr/local/games/SC3U'

# Check for required programs
RPROGRAMS="curl cat patch tar"
for RPROGRAM in ${RPROGRAMS}; do
  if [ "$(which ${RPROGRAM} &> /dev/null; echo ${?})" != "0" ]; then
    echo "ERROR: Required binary ${RPROGRAM} not found. Install it to proceed"
    exit 1
  fi
done

# Download sc3u patch
if [ ! -f ${PATCH_FNAME} ]; then
  curl http://updates.lokigames.com/sc3u/${PATCH_FNAME} -o ${PATCH_FNAME}
fi

# Fix compatibility problems
patch -p0 < ${PATCH_FNAME}.patch

# Run the patch
sudo sh ${PATCH_FNAME}

# Patch s3cu binary
sudo cp ${SC3U_PATH}/sc3u ${SC3U_PATH}/sc3u.old
cat <<EOM >sc3u
#!/bin/bash
SCPATH=${SC3U_PATH}
echo Running from \$SCPATH
cd \$SCPATH
export LD_LIBRARY_PATH=\$SCPATH/Loki_Compat/
LD_ASSUME_KERNEL=2.2.5 \$SCPATH/Loki_Compat/ld-linux.so.2 \$SCPATH/sc3u.dynamic
EOM
sudo cp sc3u ${SC3U_PATH}/sc3u
sudo chmod +x ${SC3U_PATH}/sc3u

# Download and install loki compat libary
if [ ! -f ${LOKI_COMPAT} ]; then
  curl http://www.improbability.net/loki/${LOKI_COMPAT} -o ${LOKI_COMPAT}
fi
sudo tar -xjf ${LOKI_COMPAT} -C ${SC3U_PATH}

# Remove downloads
rm -f ${PATCH_FNAME} sc3u ${LOKI_COMPAT}
