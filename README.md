[Versión en Castellano](README-ES.md)

# Native SimCity 3000 Unlimited for modern GNU/Linux distributions

This is just one of the results of a [project](https://hackweek.suse.com/16/projects/old-games-on-modern-linux) for the [16th SUSE Hackweek](https://hackweek.suse.com/16/projects).

Since running Loki and other old native and propietary games can be a challenge, we decided to research a little how much effort could take prepare such games to run on moderm GNU/Linux distributions.

## Challenges

For SimCity 3000 the biggest problems were:

- SimCity 3000 is 32 bits
- It does not work with current glib versions. This can be avoided with [Loki Compatibility Libraries](http://www.improbability.net/loki/)
- The patch 2.0 is not able to run because of changes to the POSIX standards
- The sound uses OSS and it is not able to use padsp, aoss or esdcompat neither at openSUSE 42.3 or Debian SID

## Workarounds

There are a lot of different workarounds on the Internet, including [one](https://www.juliogonzalez.es/como-ejecutar-simcity-3000-en-debian-i386-o-amd64/58) I wrote in Spanish years ago, but in the end all of them require the user to run a lot of different commands with a lot of arguments.

So this repository tries to easy the procedure so we can run just install the game, apply the patch, configure sound and start playing.

## Instructions


### Get the game

First of all, you need the original CD or an ISO image from the original CD.

If you do not have it, try one of the following links:

* [Amazon](https://www.amazon.com/s/ref=bl_sr_software?_encoding=UTF8&node=229534&field-brandtextbin=Loki%20Entertainment%20Software)
* [Linux-Discount](http://www.linux-discount.de/software/games/LokiSoft)
* [ixsoft](http://www.ixsoft.de/cgi-bin/web_store.cgi?ref=Catalogs/de/software-games-catalog.html)
* [Linux-Onlineshop](https://www.linux-onlineshop.de/index.php?page=categorie&cat=1&next_page=1) 

### Install the game

Insert the CD or mount the image, and then use a terminal to proceed to the directory where the CD/image is mounted and run:


```bash
sudo linux32 ./setup.sh
```

Use the default paths for installation when required, and answer **y** to the different questions about what to install (that way you will not need the CD or the ISO to run the game)

On some modern 64-bit distributions (for example Ubuntu 24.04 amd64) the original installer may fail or install only the data files. The patcher below completes the missing binaries and libraries from the mounted CD/ISO when they are absent.

### Patch the game

Clone this repository (if you are reading this file at GitHub WebUI), and proceed to the directory where the local clone is stored (using a terminal)

Make sure you have the required tools installed. The names of the packages that provides them depends on your distributions:

- curl
- cat
- patch
- tar
- install (coreutils)
- linux32 (util-linux)

With the CD/ISO mounted at `/mnt`, run:

```bash
sudo ./sc3u-patcher.sh
```

If the CD/ISO is mounted somewhere else, set `CDROM_PATH`:

```bash
sudo CDROM_PATH=/path/to/cdrom ./sc3u-patcher.sh
```

The script completes the base installation if needed, applies the official SimCity 3000 2.0a patch, installs the Loki compatibility libraries, and creates the `sc3u` launcher. It is safe to run again if a step fails.

Before making changes it checks that OSS sound is available (`/dev/dsp` exists and `osspd` is running). On Debian/Ubuntu you can set up sound first with `sudo ./sc3u-sound.sh`. If you do not need sound, pass `--skip-sound-check`.

Provided that there were no errors, you are ready to run SimCity 3000. Try windowed mode first:

```bash
sc3u -w
```

If that works, run `sc3u` for fullscreen mode.

### But I do not have sound!

Yes, if you are using [PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/) or PipeWire's PulseAudio compatibility (most people at this moment), there is a final step.

Since the game requires OSS (so far I was not able to make it work with padsp, aoss or esdcompat), you will need to use a software that is able to emulate OSS devices and send the audio to PulseAudio.

You need [osspd](https://sourceforge.net/projects/osspd/).

On Debian/Ubuntu, `sc3u-sound.sh` installs osspd and its PulseAudio backend, enables the service, and verifies `/dev/dsp`:

```bash
sudo ./sc3u-sound.sh
```

Use `./sc3u-sound.sh --check` to verify the setup. For other distributions, continue below.

#### openSUSE/SUSE

You can proceed to [openSUSE downloads](https://software.opensuse.org/download.html?project=home%3Ajuliogonzalez%3Abranches%3Ahome%3Aelvigia&package=ossp) and select your distribution for One Click Install. Then add yourself to the system group ```audio```, restart your session and you will be able to run SimCity 3000 with audio.

#### Debian/Ubuntu

Install osspd and the backend for PulseAudio manually:

```bash
sudo apt-get install osspd osspd-pulseaudio
```

#### Enabling osspd on boot

* systemd (openSUSE and modern Debian)

  ```bash
  sudo systemctl enable --now osspd
  ```

* SysVinit (Debian)

  ```bash
  sudo update-rc.d osspd enable
  ```
