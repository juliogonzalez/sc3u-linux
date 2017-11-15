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

### Patch the game

Clone this repository (if you are reading this file at GitHub WebUI), and proceed to the directory where the local clone is stored (using a terminal)

Run:


```bash
./sc3u-patcher.sh
```

The script will take care of everything, asking for your password to use sudo when required. It will start the official SimCity 3000 2.0 patch for you (after patching it), so you just need to follow the assitant.

Provided that there were no errors, you are ready to run SimCity 3000.

### But I do not have sound!

Yes, if you are using [PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/) (most people at this moment), there is a final step.

Since the game requires OSS (so far I was not able to make it work with padsp, aoss or esdcompat), you will need to use a software that is able to emulate OSS devices and send the audio to Pulseaudio.

You need [osspd](https://sourceforge.net/projects/osspd/).

#### openSUSE/SUSE

You can proceed to [openSUSE downloads](https://software.opensuse.org/download.html?project=home%3Ajuliogonzalez%3Abranches%3Ahome%3Aelvigia&package=ossp) and select your distribution for One Click Install. Then add yourself to the system group ```audio```, restart your session and you will be able to run SimCity 3000 with audio.

#### Debian/Ubuntu

Install osspd and the backend for pulseaudio:

```bash
apt-get install osspd osspd-pulseaudio
```

#### Enabling osspd on boot

* systemd (openSUSE and modern Debian)

  ```bash
  sudo systemctl enable osspd
  ```

* SysVinit (Debian)

  ```bash
  sudo update-rc.d osspd enable
  ```
