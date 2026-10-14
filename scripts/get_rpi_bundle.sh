#!/bin/bash
# ============================================================
#  get_rpi_bundle.sh
#  Run in WSL: bash ~/get_rpi_bundle.sh 2>&1 | tee ~/bundle_log.txt
#  Builds an offline bundle for Raspberry Pi OS Bookworm 32-bit
# ============================================================
set -e

BUNDLE="$HOME/rpi_bundle"

echo "=== Cleaning old bundle ==="
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/debs" "$BUNDLE/pip_packages"

# ============================================================
# PART 1: pip packages
# ============================================================
echo ""
echo "=== Downloading pip packages ==="
pip3 download \
    pyvisa \
    pyvisa-py \
    pyusb \
    adafruit-circuitpython-ads1x15 \
    adafruit-blinka \
    adafruit-circuitpython-busdevice \
    adafruit-circuitpython-typing \
    -d "$BUNDLE/pip_packages"

# Source tarballs (wheels are often x86 only)
pip3 download RPi.GPIO --no-binary RPi.GPIO -d "$BUNDLE/pip_packages"
pip3 download sysv_ipc --no-binary sysv_ipc -d "$BUNDLE/pip_packages"

# Strip platform-incompatible wheels
rm -f "$BUNDLE/pip_packages/"*manylinux*.whl
rm -f "$BUNDLE/pip_packages/"*linux_x86*.whl
rm -f "$BUNDLE/pip_packages/"*win*.whl
rm -f "$BUNDLE/pip_packages/"*macos*.whl

echo ""
echo "pip packages downloaded:"
ls -lh "$BUNDLE/pip_packages/"

# ============================================================
# PART 2: .deb packages via Docker (with reliable mirrors)
# ============================================================
echo ""
echo "=== Starting Docker ==="
sudo systemctl start docker 2>/dev/null || true
sudo chmod 666 /var/run/docker.sock 2>/dev/null || true

if ! sudo docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not running or accessible."
    exit 1
fi
echo "Docker OK"

# Explicit reliable mirrors bypassing the broken raspbian.mirror.net.in redirector
MIRRORS="https://mirrors.ocf.berkeley.edu/raspbian/raspbian http://mirrors.mit.edu/raspbian/raspbian http://mirror.ox.ac.uk/sites/archive.raspbian.org/archive/raspbian"

cat > "$BUNDLE/inner.sh" << 'INNER'
export DEBIAN_FRONTEND=noninteractive
rm -f /etc/apt/apt.conf.d/docker-clean

apt-get update -qq
apt-get install -y -qq --no-install-recommends ca-certificates curl >/dev/null

W=/work
mkdir -p $W/state/lists/partial $W/cache/archives/partial
: > $W/status

APT=(apt-get -y
  -o APT::Architecture=armhf
  -o APT::Architectures=armhf
  -o APT::Sandbox::User=root
  -o Dir::State=$W/state
  -o Dir::State::status=$W/status
  -o Dir::Cache=$W/cache
  -o Dir::Etc::sourcelist=$W/sources.list
  -o Dir::Etc::sourceparts=/dev/null
  -o Acquire::Retries=3
  -o Acquire::Queue-Mode=access
  -o Acquire::http::Pipeline-Depth=0
  -o Acquire::http::No-Cache=true
  -o Acquire::http::No-Store=true)

PKGS="python3-numpy python3-scipy python3-matplotlib python3-tk python3-smbus
  python3-pip python3-setuptools python3-dev libpython3.11-dev i2c-tools
  libi2c-dev libusb-1.0-0 libusb-1.0-0-dev libudev-dev gcc libgcc-12-dev"

ok=0
for M in $MIRRORS; do
  echo
  echo "##################### Trying mirror: $M"
  cat > $W/sources.list << EOF
deb [arch=armhf trusted=yes] $M bookworm main contrib non-free rpi
deb [arch=armhf trusted=yes] http://archive.raspberrypi.com/debian/ bookworm main
EOF

  "${APT[@]}" clean
  "${APT[@]}" update 2>&1 | grep -v "GPG error" || true

  for try in 1 2 3; do
    echo "--- download attempt $try ($M)"
    if "${APT[@]}" install --download-only --no-install-recommends $PKGS; then
      ok=1
      break
    fi
  done

  if [ $ok -eq 1 ]; then
    echo "Successfully downloaded packages from $M"
    break
  fi
  echo "!!! Mirror failed: $M"
done

cp $W/cache/archives/*.deb /output/ 2>/dev/null || true
echo "Downloaded: $(ls /output/*.deb 2>/dev/null | wc -l) deb packages (status=$ok)"
INNER

echo ""
echo "=== Running container build ==="
sudo docker run --rm \
    -e MIRRORS="$MIRRORS" \
    -v "$BUNDLE/debs:/output" \
    -v "$BUNDLE/inner.sh:/inner.sh:ro" \
    debian:bookworm-slim bash /inner.sh

# ============================================================
# PART 3: Verification
# ============================================================
echo ""
echo "=== Verifying Bundle ==="
DEB_COUNT=$(ls "$BUNDLE/debs/"*.deb 2>/dev/null | wc -l)
PIP_COUNT=$(ls "$BUNDLE/pip_packages/" 2>/dev/null | wc -l)
SIZE=$(du -sh "$BUNDLE" | cut -f1)

echo "  debs : $DEB_COUNT files"
echo "  pip  : $PIP_COUNT files"
echo "  size : $SIZE"

CORRUPT=0
for f in "$BUNDLE/debs/"*.deb; do
    [ -e "$f" ] || { CORRUPT=1; break; }
    dpkg-deb --info "$f" >/dev/null 2>&1 || { echo "CORRUPT: $f"; CORRUPT=1; }
done

if [ "$CORRUPT" -eq 0 ] && [ "$DEB_COUNT" -ge 150 ]; then
    echo ""
    echo "=== Bundle is ready at $BUNDLE ==="
    echo "Copy to external drive:"
    echo "  cp -r $BUNDLE /mnt/d/    # update drive letter accordingly"
    echo "  sync"
else
    echo ""
    echo "=== Bundle validation failed (deb count: $DEB_COUNT, corrupt: $CORRUPT) ==="
    exit 1
fi
