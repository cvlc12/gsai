# gsai — *Gsai Signs Arch ISOs*

**gsai** is a bash script that automates downloading, verifying, and signing official Arch Linux ISO images for use with Secure Boot and custom signing keys.

![gsai demo](assets/demo.gif)

## Features:

- Automatically downloads the latest Arch Linux ISO, using the locally set mirrors
- Verifies ISO integrity using checksums and PGP signatures
- Works offline when provided with:
  - an Arch Linux ISO
  - its corresponding PGP signature
  - checksum files
- Detects custom Secure Boot signing keys in common locations or prompts interactively
- Signs the official ISO as in [ISO repacking](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Sign_the_official_ISO_with_custom_keys)

## Installation

### AUR

Available on the AUR as [gsai-git](https://aur.archlinux.org/packages/gsai-git)

### Manual Installation

Clone the repository and install dependencies:

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

Just run `$ gsai`, or provide an iso with `$ gsai --iso <iso_path>`

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
+ If requested enter password to access protected Secure Boot keys.
+ Configuring Arch Linux ISO image...
DONE! - Successfully created signed ISO: archlinux-2025.12.01-x86_64-signed.iso
--> Save signed ISO image: archlinux-2025.12.01-x86_64-signed.iso? (y/n) y
--> Enter path to back up ISO: /home/user/archlinux-2025.12.01-x86_64-signed.iso
+ Created /home/user/archlinux-2025.12.01-x86_64-signed.iso
+ Removed temporary files, exiting

```

```
$ gsai --help
gsai - Sign Arch Linux ISOs for Secure Boot
version: 0
  Options:
       --autosign                Automatically sign if only one set of Secure Boot signing keys are found
       --escalate-with           Takes one of 'run0' 'sudo' or 'doas'
   -h, --help                    Won't help you much
       --iso                     Specify an Arch Linux ISO image file
       --offline                 Prompt for the paths of necessary files instead of fetching them online
       --output-dir              Output directory for signed iso
       --skip-iso-verification   Do not check iso integrity
       -v, --verbose             Verbose output

EOF
```

## Roadmap
- [ ] Support burning to usb.


## Authors and acknowledgment
[Arch Wiki](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#ISO_repacking)

## License
MIT
