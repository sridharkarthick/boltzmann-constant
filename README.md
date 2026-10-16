# Measurement of Boltzmann's Constant

## 1. Raspberry Pi 3B+ SD Card Setup

Follow these steps to flash the initial operating system image onto your microSD card:

1. Insert your microSD card into your computer's card reader.
2. Download and install the **Raspberry Pi Imager** from [raspberrypi.com/software](https://www.raspberrypi.com/software/) (refer to the [official getting started guide](https://www.raspberrypi.com/documentation/computers/getting-started.html#imager-install)).
3. Open Raspberry Pi Imager:
   - **Device:** Select **Raspberry Pi 3**.
   - **Operating System:** Navigate to **Raspberry Pi OS (other)** and select **Raspberry Pi OS (Legacy, 32-bit)** (Bookworm).
   - **Storage:** Choose your inserted microSD card.
4. Click **Next** to open the OS Customization settings:
   - Set your username and password.
   - Under localization, select the **US** keyboard layout.
   - Configure local timezone settings.
5. Click **Save**, apply customization settings, and confirm the write operation.
6. Once verification finishes, safely eject the microSD card from your PC.
7. Insert the card into your Raspberry Pi 3B+, connect your monitor (HDMI), keyboard, mouse, and connect the official 5V 2.5A micro-USB power supply. The Pi will boot to the desktop/shell.

---

## 2. Generating the Offline Bundle (in WSL)

This section covers downloading the required runtime libraries, development headers, GCC toolchains, and Python packages using Windows Subsystem for Linux (WSL), copying them to an external drive, and installing them on the Raspberry Pi. By pre-packaging all dependencies on a host PC, the Raspberry Pi operates without requiring an internet connection of its own.

### What `scripts/get_rpi_bundle.sh` Downloads

The script splits the environment creation into two isolated layers:

| Component | Target Architecture | Source | Packages Downloaded |
| :--- | :--- | :--- | :--- |
| **Python Wheels & Sources** | Pure Python & C Sources | PyPI | `pyvisa`, `pyvisa-py`, `pyusb`, `adafruit-circuitpython-ads1x15`, `adafruit-blinka`, `adafruit-circuitpython-busdevice`, `adafruit-circuitpython-typing`, and source tarballs for `RPi.GPIO` and `sysv_ipc`. Platform-incompatible wheels (`manylinux`, `x86`, `win`, `macos`) are stripped automatically. |
| **Debian Archives (`.deb`)** | `armhf` (32-bit ARM) | Official Raspbian & RPi Mirrors (OCF Berkeley, MIT, Oxford fallback) | `python3-numpy`, `python3-scipy`, `python3-matplotlib`, `python3-tk`, `python3-smbus`, `python3-pip`, `python3-setuptools`, `python3-dev`, `libpython3.11-dev`, `i2c-tools`, `libi2c-dev`, `libusb-1.0-0`, `libusb-1.0-0-dev`, `libudev-dev`, `gcc`, `libgcc-12-dev`, and all recursive runtime dependencies (~200 packages). |

The script leverages a temporary `debian:bookworm-slim` Docker container configured with multi-arch `armhf` APT parameters to download foreign binary `.deb` packages directly, bypassing broken local redirect mirrors.

### Step 1: Run the Bundle Downloader in WSL

Open your WSL terminal and execute:

```bash
bash ~/get_rpi_bundle.sh 2>&1 | tee ~/bundle_run.log
```

#### Verification
Watch the console output. It will fetch pip wheels first, verify the local Docker daemon, and query the fallback Raspbian mirrors:

```text
Get:199 [https://mirrors.ocf.berkeley.edu/raspbian/raspbian](https://mirrors.ocf.berkeley.edu/raspbian/raspbian) bookworm/main armhf python3-wheel all 0.38.4-2 [30.8 kB]
Get:200 [https://mirrors.ocf.berkeley.edu/raspbian/raspbian](https://mirrors.ocf.berkeley.edu/raspbian/raspbian) bookworm/main armhf python3-smbus armhf 4.3-2+b2 [11.3 kB]
Fetched 148 MB in 1min 10s (2108 kB/s)
Download complete and in download only mode
Successfully downloaded packages from [https://mirrors.ocf.berkeley.edu/raspbian/raspbian](https://mirrors.ocf.berkeley.edu/raspbian/raspbian)
Downloaded: 200 deb packages (status=1)

=== Verifying Bundle ===
  debs : 200 files
  pip  : 17 files
  size : 144M

=== Bundle is ready at /home/srikrishna/rpi_bundle ===
```

Verify package counts and architecture integrity before transferring:

```bash
echo "Debs: $(ls -1 ~/rpi_bundle/debs/*.deb 2>/dev/null | wc -l)"
echo "Pip packages: $(ls -1 ~/rpi_bundle/pip_packages/* 2>/dev/null | wc -l)"
du -sh ~/rpi_bundle

# Verify target architecture is armhf
dpkg-deb -f ~/rpi_bundle/debs/libc6_*.deb Architecture
dpkg-deb -f ~/rpi_bundle/debs/python3-numpy_*.deb Architecture

# Verify archives are not corrupted
for f in ~/rpi_bundle/debs/*.deb; do dpkg-deb --info "$f" >/dev/null 2>&1 || echo "BROKEN: $f"; done
```

Both package architecture checks should return `armhf`, and no package should report `BROKEN`.

### Step 2: Copy Bundle to USB Drive

Copy the bundle to your external USB flash drive:

```bash
cp -r ~/rpi_bundle /mnt/d/    # Adjust drive letter /mnt/<drive> to match your mounted drive
sync
```

Safely unmount or eject the USB drive from your PC.

---

## 7. Offline Installation on Raspberry Pi 3B+

Plug the USB flash drive into one of the USB ports on the Raspberry Pi.

### Step 1: Mount Drive and Copy Bundle

Open a terminal on the Raspberry Pi:

```bash
# Locate your USB drive identifier (e.g., /dev/sda1 mounted at /media/<user>/<label>)
lsblk

# Copy bundle to the home directory
cp -r "/media/$USER/Backup Plus/rpi_bundle" ~/    # Update mount path if different
sync

# Verify deb package count
ls ~/rpi_bundle/debs | wc -l
```
*Verification:* The terminal output must display `200` (or your exact downloaded package count).

---

### Step 2: Install Debian Packages (`.deb`)

Install the system packages and development toolchain. Run `dpkg` twice to resolve circular dependency ordering automatically:

```bash
cd ~/rpi_bundle/debs
sudo dpkg -i *.deb
sudo dpkg -i *.deb
```

Verify that the C compiler toolchain and core scientific libraries are installed:

```bash
gcc --version
python3 -c "import numpy, scipy, matplotlib; print('Core stack OK')"
```
*Verification:* The terminal should output the GCC version and print `Core stack OK`.

---

### Step 3: Install Pip Packages

Install the downloaded Python packages and compile the C source tarballs (`RPi.GPIO`, `sysv_ipc`) locally using the freshly installed GCC compiler:

```bash
sudo pip3 install \
  --no-index \
  --find-links=$HOME/rpi_bundle/pip_packages \
  --no-build-isolation \
  $HOME/rpi_bundle/pip_packages/* \
  --break-system-packages
```
*Verification:* The terminal should display `Successfully installed ...` for all packages without errors.

---

### Step 4: End-to-End Environment Verification

Confirm that all measurement, communication, and hardware control libraries load properly:

```bash
python3 -c "import pyvisa, RPi.GPIO, sysv_ipc, adafruit_ads1x15; print('All libraries OK')"
```
*Verification:* The terminal should print `All libraries OK` without raising any `ModuleNotFoundError` or `ImportError`.
