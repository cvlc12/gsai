#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 cvlc12

set -e

trap 'echo; exit' SIGINT
trap 'clean' EXIT

# Configuration
#declare -r version=%VERSION%
version=0
download_page="https://archlinux.org/download/"
#cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/gsai"
#config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gsai"

# Clean temporary files before exiting
backup_iso() {

    local target=${1}
    local iso_status=${2}
    if read_yes_no "Save ${iso_status} ISO image: $(basename "$target")?"; then
        ask_path "back up ISO" backup_file "${local_dir:-${HOME}}/$(basename "$target")"
        [[ -n "$backup_file" ]] || err "No path provided"
        if mv "$target" "${backup_file:?}" &>/dev/null; then
            msg "Created ${backup_file}"
        else
            err "Could not backup to ${backup_file}, did not clean up ${work_dir}"
        fi
    fi
}

clean() {

    # If we have not done anything yet, simply exit
    [[ -z "$work_dir" ]] && exit 0

    # If we successfully signed an ISO
    if [[ -f "$signed_iso" ]]; then
        # then suggest to save it before cleaning up if no output dir was selected
        if [[ -z "$output_dir" ]]; then
            backup_iso "$signed_iso" "signed" || err "Could not back up iso."
        fi

    # Else if we downloaded and verified an ISO, then suggest to save it before cleaning up
    elif [[ "$use_local_iso" == 'no' ]] && (( verified_iso )); then
        backup_iso "$iso" "verified (unsigned!)" || err "Could not back up verified (unsigned!) iso."
    fi

    # Then, clean up and exit
    if rm -rf -- "$work_dir"; then
        msg "Removed temporary files, exiting"
        exit 0
    else
        err "Could not remove temporary files"
    fi
}

download_iso() {
    local -a mirrors
    local mirrorlist="/etc/pacman.d/mirrorlist"
    local fallback_mirrors=(
        "https://fastly.mirror.pkgbuild.com"
        "https://geo.mirror.pkgbuild.com"
    )

    # Populate mirrors from local mirrorlist
    if [[ -f "$mirrorlist" ]]; then
        # shellcheck disable=SC2016
        mapfile -t mirrors < <(grep '^Server =' "$mirrorlist" | sed -E 's/^Server = //;s|/\$repo/os/\$arch/?$||')
        if (( ${#mirrors[@]} > 0 )); then
            info "Loaded mirrors from ${mirrorlist}"
        fi
    fi

    # Add fallback mirrors 
    mirrors+=("${fallback_mirrors[@]}")

    (( ${#mirrors[@]} == 0 )) && err "No valid mirrors found!"

    msg "Downloading Arch Linux ${release}..."

    # Try each mirror until one works
    for mirror in "${mirrors[@]}"; do
        local iso_url="${mirror}/iso/${release}/archlinux-${release}-x86_64.iso"
        (( verbose )) && info "Trying mirror" "$mirror"
        if curl --connect-timeout 3 --speed-limit 10240 --output-dir "$work_dir" --progress-bar --remote-name "$iso_url"; then
            msg "Successfully downloaded Arch Linux ISO from ${mirror}"
            iso="${work_dir}/archlinux-${release}-x86_64.iso"
            return 0
        else
            (( verbose )) && info "Failed to download from ${mirror}"
        fi
    done

    err "Failed to download ISO from all mirrors!"
}

verify_iso() {

    msg "Verifying ISO..."

    # Checksum
    read -r checksum _ < <(grep -m 1 "archlinux-x86_64.iso" "$b2sums")
    echo "${checksum} ${iso}" | b2sum -c &>/dev/null || err "Checksum verification failed for ${iso}"
    (( verbose )) && info "Checksum verification ok"

    # release signing key
    gpg --keyserver-options auto-key-retrieve --verify "$sig" "$iso" &>/dev/null || err "Signature verification failed!"
    (( verbose )) && info "Signature verification ok"
    
    verified_iso=1
}

select_keys() {
    
    local -a uki_conf_dirs key_path_list local_keys

    (( verbose )) && msg "Locating keys..."

    # Try to locate existing keys. Maximum 9 items in key_path_list (in local_keys really) or the 'case' code below needs modification.
    # TODO: there 'might' be more than 9 items
    
    # Try uki.conf 
    uki_conf_dirs=(
        "/etc/kernel"
        "/run/kernel"
        "/usr/local/lib/kernel"
        "/usr/lib/kernel"
    )

    for dir in "${uki_conf_dirs[@]}"; do
        uki_conf_path="${dir}/uki.conf"
        if [[ -f "$uki_conf_path" ]]; then
            key=$(grep -E '^\s*SecureBootPrivateKey\s*=' "$uki_conf_path" | sed -E 's/^\s*SecureBootPrivateKey\s*=\s*//')
            cert=$(grep -E '^\s*SecureBootCertificate\s*=' "$uki_conf_path" | sed -E 's/^\s*SecureBootCertificate\s*=\s*//')

            if [[ -n "$key" && -n "$cert" ]]; then
                key_path_list+=("${key} ${cert}")
                (( verbose )) && info "Found keys in ${uki_conf_path}!"
            fi
            break  # Use only the first matching uki.conf
        fi
    done

    # Try other common paths
    key_path_list+=(
        "/etc/kernel/secure-boot-private-key.pem /etc/kernel/secure-boot-certificate.pem"
        "/var/lib/sbctl/keys/db/db.key /var/lib/sbctl/keys/db/db.pem"
        "/usr/share/secureboot/keys/db/db.key /usr/share/secureboot/keys/db/db.pem"
        "/etc/efi-keys/DB.key /etc/efi-keys/DB.cer"
        "/etc/kernel/secure-boot.key.pem /etc/kernel/secure-boot.cert.pem"
        "/etc/systemd/secure-boot.key.pem /etc/systemd/secure-boot.cert.pem"
    )

    # Test key pairs
    declare -A seen_pairs  # Associative array for deduplication

    for key_pair in "${key_path_list[@]}"; do
        read -r key cert <<< "$key_pair"
        if [[ -f "$key" && -f "$cert" && -z "${seen_pairs[$key_pair]}" ]]; then
            local_keys+=("$key_pair")
            (( verbose )) && info "Found valid private key" "$key"
            (( verbose )) && info "Found valid certificate" "$cert" 
            seen_pairs[$key_pair]=1
        fi
    done

    # Select from local keys
    case "${#local_keys[@]}" in
        0)
            (( verbose )) && info "Could not locate any Secure Boot keys..."
            unset key cert
            ;;
        1)              
            msg "Located the following existing Secure Boot keys:"
            read -r key cert <<< "${local_keys[0]}"

            info "Private key" "$key"
            info "Certificate" "$cert"

            # If autosign is not selected
            if [[ -z "$sign" ]]; then
                read_yes_no "Use these keys to sign the Arch Linux ISO image?" && sign=1
            fi

            if (( sign )); then
                read -r key cert <<< "${local_keys[0]}"
            else
                unset key cert
            fi
            ;;
        *)              
            msg "Located the following existing Secure Boot keys:"
            
            local i nb_keys
            i=1

            for key_pair in "${local_keys[@]}"; do
                read -r key cert <<< "$key_pair"
                info2 "(${i}) Private key" "$key"
                info2 "    Certificate" "$cert"
                ((i++))
            done
            
            nb_keys=$((i - 1))      

            while true; do
                ask "Pick a key (1..${nb_keys}), or press Enter to use another key: "

                case "$answer" in
                    "")  
                        # if the user pressed Enter (cancellation)
                        unset key cert
                        break
                        ;;
                    [1-$nb_keys])
                        ((answer--))  # to be usable as an array index
                        read -r key cert <<< "${local_keys[${answer}]}"
                        (( verbose )) && info "Using key ${key}"
                        (( verbose )) && info "Using cert ${cert}"
                        break
                        ;;
                    *)  
                        msg "Invalid choice. Choose between 1 and ${nb_keys}"
                        ;;
                esac
            done            
            ;;
    esac

    # Select keys manually
    if [[ -z "$key" || -z "$cert" ]]; then

        ask_path "Secure Boot private key" key
        [[ -f "$key" ]] || err "${key} is not a file!"

        ask_path "Secure Boot certificate" cert
        [[ -f "$cert" ]] || err "${cert} is not a file!"

        msg "Selected the following Secure Boot keys"
        info "Private key" "$key"
        info "Certificate" "$cert"
    fi

    # Signing util
    signing_utils=("systemd-sbsign" "/usr/lib/systemd/systemd-sbsign")
    for cmd in "${signing_utils[@]}"; do
        if command_exists "$cmd"; then
            sign_util="$cmd"
            (( verbose )) && info "Will sign with" "$sign_util"        
            break
        fi
    done

    [[ -n "$sign_util" ]] || err "Systemd-sbsign is not available!"
        
    # Check the keys are readable
    if (( EUID )); then  
        if [[ -r "$key" && -r "$cert" ]]; then
            info "Keys are readable! This might be a security risk."
            sign_cmd=("$sign_util")
        elif [[ -n "$sudo_cmd" ]]; then
            (( verbose )) && info "Elevating privileges with ${sudo_cmd}."
            sign_cmd=("$sudo_cmd" "$sign_util")
        else
            (( verbose )) && info "Keys are not readable, trying to elevate privileges."
            
            # Verify we can use run0
            min_pk_ver=127

            if command -v pkcheck >/dev/null 2>&1; then
                version=$(pkcheck --version 2>/dev/null | awk '{print $NF}')
                if [[ $version =~ ^[0-9]+$ ]] && (( version >= min_pk_ver )); then
                    (( verbose )) && info "Using run0"
                    sudo_cmd=run0
                fi
            fi
            
            # Else try sudo
            if [[ -z "$sudo_cmd" ]]; then
    
                (( verbose )) && info "Not using run0, polkit too old or version unknown."

                # Verify sudo
                if command_exists 'sudo'; then
                    if sudo -l &>/dev/null; then
                        (( verbose )) && info "Using sudo"
                        sudo_cmd=sudo
                    fi
                fi
            fi

            # Else try doas
            if [[ -z "$sudo_cmd" ]]; then
    
                (( verbose )) && info "Not using 'sudo', not in 'sudoers' or 'sudo' not installed."

                # Verify doas
                if command_exists 'doas'; then
                    sudo_cmd=sudo
                else
                    (( verbose )) && info "Not using 'doas', not installed."
                    err "⚠️  Could not elevate privileges. Try running as root."  
                fi
            fi
            
            msg "If requested by ${sudo_cmd}, enter password to access protected Secure Boot keys."
            sign_cmd=("$sudo_cmd" "$sign_util")
        fi
    else
        info "⚠️  gsai is running as root. Consider running as a normal user."
        sign_cmd=("$sign_util")
    fi
}

parse_args() {
    
    offline=0
    output_dir=""
    verbose=0
    verified_iso=0
    sudo_cmd=""

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --autosign)
                sign=1
                ;;
            --escalate-with)
                shift
                sudo_cmd="$1"
                [[ "$sudo_cmd" == 'run0' || "$sudo_cmd" == 'sudo' || "$sudo_cmd" == 'doas' ]] || err "Not a valid escalation command"
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            --iso)
                shift
                iso="$1"
                ;;
            --offline)
                offline=1
                ;;
            --output-dir)
                shift
                if [[ -d "$1" && -w "$1" ]]; then
                    output_dir="${1%/}"
                else
                    err "${1} is not a directory we can write to !"
                fi
                ;;          
            -v | --verbose)
                verbose=1
                ;;
            *)
                usage
                err "Unknown option: $1"
                ;;
        esac
        shift
    done
}

usage() {
    cat <<EOF
version: ${version}
  Options:
       --autosign                Automatically sign if only one set of Secure Boot signing keys are found
       --escalate-with           Takes one of 'run0' 'sudo' or 'doas'
   -h, --help                    Won't help you much
       --iso                     Specify an Arch Linux ISO image file
       --offline                 Prompt for the paths of necessary files instead of fetching them online
       --output-dir              Output directory for signed iso
   -v, --verbose                 Verbose output
EOF
}

# ----------------------------------------------------------------------------------------
# Script
# ----------------------------------------------------------------------------------------

# Resolve the directory where the script is located, even if it's symlinked
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Source the utility and function files
source "${SCRIPT_DIR}/gsai_utils.sh"

# Enable colors
if [[ -t 2 && -n "$COLORTERM" ]]; then
    if [[ -n "$NO_COLOR" ]]; then
        (( verbose )) && info "Colors disabled by '$NO_COLOR'. See https://no-color.org/" 
    else 
        enable_colors
    fi
fi

msg_green "gsai" "Sign Arch Linux ISOs for Secure Boot"

# Parse arguments
parse_args "$@"

# Check for needed commands
command_exists 'mcopy' || err "Package 'mtools' is required"
command_exists 'xorriso' || err "Package 'libisoburn' is required"

# Create working directory
work_dir=$(mktemp -d --tmpdir ARCH_ISO.XXX || err "Could not create temporary directory!")
(( verbose )) && info "Work directory:" "$work_dir"

if (( offline )); then
    msg "To run offline, valid paths are needed for the Arch Linux ISO, an ISO PGP signature file, and checksums (b2sums.txt)"

    # Use the iso if provided via commandline, else ask for it
    [[ -n "$iso" ]] || ask_path "Arch Linux ISO" "iso"
    [[ -f "$iso" ]] || err "${iso} is not a file"
    use_local_iso='yes'

    # Store local directory name
    local_dir="$(dirname "$iso")"
    (( verbose )) && info "Using source directory:" "$local_dir"

    # Try to find sig in same directory, else ask for it
    sig="${iso}.sig"
    if [[ -f "$sig" ]]; then
        msg "Found ${sig} in same directory!"
    else
        ask_path "Arch Linux ISO PGP signature" "sig" "${local_dir}/"
        [[ -f "$sig" ]] || err "${sig} is not a file"
    fi

    # Try to find b2sums in same directory, else ask for it
    b2sums="${local_dir}/b2sums.txt"
    if [[ -f "$b2sums" ]]; then
        msg "Found ${b2sums} in same directory!"
    else
        ask_path "Arch Linux ISO checksums (b2sums.txt)" "b2sums" "${local_dir}/"
        [[ -f "$b2sums" ]] || err "${b2sums} is not a file"
    fi

    release=$(grep -oP  -m 1 '\b\d{4}\.\d{2}\.\d{2}\b' "$b2sums" || err "Could not determine current release from b2sums file!")

else
    release=$(curl --silent "$download_page" 2>&1 | grep -o -m 1 '[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}' || err "Could not determine current release!")
    sig="https://archlinux.org/iso/${release}/archlinux-${release}-x86_64.iso.sig"
    b2sums="https://archlinux.org/iso/${release}/b2sums.txt"
   
    (( verbose )) && {
        info "sig" "$sig"
        info "b2sums" "$b2sums"
    }

    curl --silent --output-dir "$work_dir" --progress-bar --remote-name "$sig" || err "Could not download signature!"
    sig="${work_dir}/archlinux-${release}-x86_64.iso.sig"

    curl --silent --output-dir "$work_dir" --progress-bar --remote-name "$b2sums" || err "Could not download b2sums!"
    b2sums="${work_dir}/b2sums.txt"

    # Use the iso if it was provided via commandline
    if [[ -n "$iso" ]]; then
        [[ -f "$iso" ]] || err "${iso} is not a file!"
        use_local_iso='yes'
    else
        use_local_iso='no'

        # Suggest to download with bittorrent
        #magnet_link=$(curl -s "$download_page" 2>/dev/null | grep -o -m 1 'magnet:[^"]*' || err "Could not get magnet link!")
        magnet_link=$(curl -s "$download_page" 2>/dev/null | grep -o -m 1 'magnet:[^"]*')
        if [[ -n "$magnet_link" ]]; then
            msg "Consider downloading the ISO image via bittorrent. Press 'q' to quit, then run 'gsai --iso <iso_path>':"
            info "$magnet_link"
        
            ask "Press any other key to continue instead. "
            [[ "$answer" == "q" ]] && exit 0
        else
            (( verbose )) && info "Could not get magnet link!"
        fi

        download_iso
    fi
fi

(( verbose )) && {
    info "ISO" "$iso"
    info "sig" "$sig"
    info "b2sums" "$b2sums"
}

verify_iso

select_keys

msg "Configuring Arch Linux ISO image..."

## First extract the relevant files and El Torito boot images:
(( verbose )) && info "Running osirrox to extract files..."

osirrox -indev "$iso" \
    -extract_boot_images "$work_dir" \
    -cpx /arch/boot/x86_64/vmlinuz-linux \
        /EFI/BOOT/BOOTx64.EFI \
        /EFI/BOOT/BOOTIA32.EFI \
        /shellx64.efi \
        /shellia32.efi "$work_dir" &>/dev/null || err "Could not run osirrox command!"

# Sign all extracted files
files=(BOOTx64.EFI BOOTIA32.EFI shellx64.efi shellia32.efi vmlinuz-linux)

for file in "${files[@]}"; do
    chmod +w "${work_dir}/${file}" || err "Could not make boot files writable!"
    "${sign_cmd[@]}" --private-key "$key" --certificate "$cert" sign "${work_dir}/${file}" --output "${work_dir}/${file}" &>/dev/null || err "Could not sign ${file}!"
    (( verbose )) && info "Signed" "$file"
done

## Repack
mcopy -D oO -i "${work_dir}/eltorito_img2_uefi.img" "${work_dir}/vmlinuz-linux" ::/arch/boot/x86_64/vmlinuz-linux || err "Could not run mcopy command!"
mcopy -D oO -i "${work_dir}/eltorito_img2_uefi.img" "${work_dir}/BOOTx64.EFI" "${work_dir}/BOOTIA32.EFI" ::/EFI/BOOT/ || err "Could not run mcopy command!"
mcopy -D oO -i "${work_dir}/eltorito_img2_uefi.img" "${work_dir}/shellx64.efi" "${work_dir}/shellia32.efi" ::/ || err "Could not run mcopy command!"
(( verbose )) && info "Ran mcopy commands"

# If no output specified or file exists in output dir, revert to workdir 
if [[ -z "$output_dir" ]]; then
    signed_iso="${work_dir}/archlinux-${release}-x86_64-signed.iso"
    output_dir=""
elif [[ -f "${output_dir}/archlinux-${release}-x86_64-signed.iso" ]]; then
    msg "Signed iso already exists in output dir!"
    signed_iso="${work_dir}/archlinux-${release}-x86_64-signed.iso"
    output_dir=""
else
    signed_iso="${output_dir}/archlinux-${release}-x86_64-signed.iso"
fi

(( verbose )) && info "Output path" "$signed_iso"

(( verbose )) && info "Running xorriso to repack"
xorriso -indev "$iso" \
    -outdev "$signed_iso" \
    -map "${work_dir}/vmlinuz-linux" /arch/boot/x86_64/vmlinuz-linux \
    -map_l "${work_dir}/" /EFI/BOOT/ "${work_dir}/BOOTx64.EFI" "${work_dir}/BOOTIA32.EFI" -- \
    -map_l "${work_dir}/" / "${work_dir}/shellx64.efi" "${work_dir}/shellia32.efi" -- \
    -boot_image any replay \
    -append_partition 2 0xef "${work_dir}/eltorito_img2_uefi.img" &>/dev/null || err "Could not repack with xorriso!"

msg_green "DONE!" "Successfully created signed ISO: $(basename "$signed_iso")"
