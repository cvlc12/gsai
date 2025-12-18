# gsai

### Gsai Signs Arch Isos. A simple shell script to download and sign Arch Linux ISOs for use with Secure Boot

## Installation

```
# pacman -S --asdeps --needed libisoburn mtools
$ git clone https://github.com/cvlc12/gsai.git
$ ln -s "$PWD"/gsai/gsai.sh ~/.local/bin/gsai
```

You might have to add `~/.local/bin` to your user's `PATH`, e.g.:

```
$ nano .config/environment.d/10-path.conf
PATH="$HOME/.local/bin:$PATH"
```

## Usage

```
$ gsai --help
GSAI - Sign Arch Linux ISOs for Secure Boot
version: 0
  Options:
       --autosign                Automatically sign if only one set of Secure Boot signing keys are automatically found
       --escalate-with           Takes one of 'run0', 'sudo' or 'doas'
   -h, --help                    Won't help you much
       --iso                     Specify an Arch Linux ISO image file
       --offline                 Prompt for the paths of necessary files instead of fetching them online
   -v, --verbose                 Verbose output
EOF
```

```
$ gsai 
gsai - Sign Arch Linux ISOs for Secure Boot
+ Consider downloading the ISO image via bittorrent. Press 'q' to quit, then run 'gsai --iso <iso_path>':
    > magnet:?xt=urn:btih:cdf37bb22c748fa8cb1594bdc39efed1bcd5cc31&amp;dn=archlinux-2025.12.01-x86_64.iso
--> Press any other key to continue instead. 
+ Downloading Arch Linux 2025.12.01...
####################################################################################################################################################################################### 100.0%
+ Successfully downloaded Arch Linux ISO from http://es.mirrors.cicku.me/archlinux
+ Verifying ISO...
+ Located the following existing Secure Boot keys:
    > Private key         : /etc/kernel/secure-boot-private-key.pem
    > Certificate         : /etc/kernel/secure-boot-certificate.pem
--> Use these keys to sign the Arch Linux ISO image? (y/n) y
+ If requested by run0, enter password to access protected Secure Boot keys.
+ Configuring Arch Linux ISO image...
DONE! - Successfully created signed ISO: archlinux-2025.12.01-x86_64-signed.iso
--> Save signed ISO image: archlinux-2025.12.01-x86_64-signed.iso? (y/n) y
--> Enter path to back up ISO: /home/user/archlinux-2025.12.01-x86_64-signed.iso
+ Created /home/user/archlinux-2025.12.01-x86_64-signed.iso
+ Removed temporary files, exiting

```

## Roadmap
- [ ] Support burning to usb.


## Authors and acknowledgment
[Arch Wiki](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#ISO_repacking)

## License
MIT
