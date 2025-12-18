#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 cvlc12

ask() {
    local question="$1"
    read -rp "$(printf "%s--> %s%s" "${BOLD}" "${ALL_OFF}" "${question}" >&2)" answer
}

read_yes_no() {
  local prompt="$1"
  while true; do
    read -rp "$(printf "%s--> %s%s" "$BOLD" "$ALL_OFF" "${prompt} (y/n) " >&2)" yn
    case "$yn" in
      [yY]) return 0 ;;
      [nN]) return 1 ;;
      *) echo "Please answer y (yes) or n (no)." ;;
    esac
  done
}

ask_path() {
    local text="$1"
    local varname="$2"
    local prepend="${3:-${HOME:-/home}/}"
    # shellcheck disable=SC2229
    read -rep "$(printf "%s--> %sEnter path to %s: " "${BOLD}" "${ALL_OFF}" "${text}")" -i "$prepend" "$varname"
}

command_exists() {
    command -v "$1" &>/dev/null
}

enable_colors() {
    # prefer terminal safe colored and bold text when tput is supported
    if tput setaf 0 &>/dev/null; then
        ALL_OFF="$(tput sgr0)"
        BOLD="$(tput bold)"
        RED="${BOLD}$(tput setaf 1)"
        GREEN="${BOLD}$(tput setaf 2)"
        YELLOW="${BOLD}$(tput setaf 3)"
        BLUE="${BOLD}$(tput setaf 4)"
    else
        ALL_OFF="\e[0m"
        BOLD="\e[1m"
        RED="${BOLD}\e[31m"
        GREEN="${BOLD}\e[32m"
        YELLOW="${BOLD}\e[33m"
        BLUE="${BOLD}\e[34m"
    fi
    readonly ALL_OFF BOLD BLUE GREEN RED YELLOW
}

err() {
    local msg="$1"; shift
    printf "%s- Error:%s%s %s%s\n" "${RED}" "${ALL_OFF}" "${BOLD}" "$msg" "${ALL_OFF}" >&2
    exit 1
}

info() {
    # info "title" "content"
    local title="$1"
    [[ -n "$2" ]] && local msg=": ${2}"
    printf "%s    > %-20s%s%s\n" "${BOLD}" "$title" "${ALL_OFF}" "$msg" >&2
}

info2() {
    # info2 "title" "content". Info, but without leading "> "
    local title="$1"
    [[ -n "$2" ]] && local msg=": ${2}"
    printf "%s    %-22s%s%s\n" "${BOLD}" "$title" "${ALL_OFF}" "$msg" >&2
}

msg() {
    local msg=$1
    printf "%s+ %s%s\n" "${GREEN}" "${ALL_OFF}" "$msg" >&2
}

msg_yellow() {
    local title="$1"
    local msg="$2"
    printf "%s%s%s - %s%s%s%s\n" "${BOLD}" "${YELLOW}" "${title}" "${ALL_OFF}" "${BOLD}" "$msg" "${ALL_OFF}" >&2
}

msg_green() {
    local title="$1"
    local msg="$2"
    printf "%s%s%s - %s%s%s%s\n" "${BOLD}" "${GREEN}" "${title}" "${ALL_OFF}" "${BOLD}" "$msg" "${ALL_OFF}" >&2
}
