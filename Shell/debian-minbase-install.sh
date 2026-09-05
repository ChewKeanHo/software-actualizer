#!/bin/sh
# Copyright 2025 (Holloway) Chew, Kean Ho <hello@hollowaykenaho.com>
# Copyright 2022 (Holloway) Chew, Kean Ho <kean.ho.chew@zoralab.com>
#
#
# Zero-Clause BSD
# =============
#
# Permission to use, copy, modify, and/or distribute this software for
# any purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED “AS IS” AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE
# FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY
# DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
# AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
# OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.




# initialize
APP_VERSION="1.2.2"

1>&2 printf -- "%s\n" "\
(Holloway) Chew, Kean Ho's
   db     dP\"\"b8 888888 88   88    db    88     88 8888P 888888 88\"\"Yb 
  dPYb   dP   \`\"   88   88   88   dPYb   88     88   dP  88__   88__dP 
 dP__Yb  Yb        88   Y8   8P  dP__Yb  88  .o 88  dP   88\"\"   88\"Yb  
dP\"\"\"\"Yb  YboodP   88   \`YbodP' dP\"\"\"\"Yb 88ood8 88 d8888 888888 88  Yb 
----------------------------------------------------------------------
Actualize the smallest Debian image possible!

Version           : ${APP_VERSION}
License           : Zero-Clause BSD (BSD0)
Principal Designer: (Holloway) Chew, Kean Ho <hello@hollowaykeanho.com>

"

clean_up() {
        stty echo
}
trap 'clean_up' EXIT INT HUP




# validate is root
1>&2 printf -- "I: Checking Privilege and Access...\n"
if [ ! "$(id -u)" = "0" ]; then
        1>&2 printf -- "%s" "\
E: Current User is Not A Root! Please Change It.
E: Bailing Out...

"
        exit 1
fi




# install critical dependencies
1>&2 printf -- "I: Install Required Apt Packages for Actualizer...\n"
____old_IFS="$IFS"
while IFS="" read ____line || [ -n "$____line" ]; do
        if [ "$____line" = "" ]; then
                continue
        fi


        1>&2 printf -- "I: Installing '%s' Package...\n" "$____line"
        apt install "$____line" -y
        if [ $? -ne 0 ]; then
                1>&2 printf -- "\
E: Installation Failed!
E: Please Try Again or Perform Manual Installation.
E: Bailing Out...

" "$____line"
                IFS="$____old_IFS"
                unset ____line ____old_IFS
                exit 1
        fi
done<<EOF
debootstrap
whois
EOF
IFS="$____old_IFS"
unset ____line ____old_IFS




# validate dependencies
1>&2 printf -- "I: Validating Host OS...\n"
____old_IFS="$IFS"
while IFS="" read ____line || [ -n "$____line" ]; do
        if [ "$____line" = "" ]; then
                continue
        fi


        1>&2 printf -- "I: Checking '%s'...\n" "$____line"
        command -v "$____line" > /dev/null
        if [ $? -ne 0 ]; then
                1>&2 printf -- "\
E: '%s' is Missing! Please Install the Package and Try Again.
E: Bailing Out...

" "$____line"
                IFS="$____old_IFS"
                unset ____line ____old_IFS
                exit 1
        fi


        # CVE-2026-85649: ensure the mkpasswd has yescrypt support.
        if [ "$____line" = "mkpasswd" ]; then
                # simulate mkpasswd check
                ____temp="$(printf "%s" "test" \
                        | mkpasswd --method=yescrypt --stdin \
                        2> /dev/null
                )"

                case "$____temp" in
                '$y$'*)
                        # all good - accepted
                        unset ____temp
                        ;;
                *)
                        # reject build from any outdated or incompatible host
                        # os.
                        unset ____temp
                        1>&2 printf -- "%s" "\
E: The installed 'mkpasswd' does not support 'yescrypt' hashing.
E:
E: This usually happens if:
E:   (1) the 'makepasswd' package is installed instead of 'whois'; AND/OR
E:   (2) your host's libxcrypt is incompatible or too old.
E:
E: This can yield severe security vulnerability for the built image.
E: WILL NOT PROCEED.
E: Bailing Out...
"
                        IFS="$____old_IFS"
                        unset ____line ____old_IFS
                        exit 1
                        ;;
                esac
        fi
done<<EOF
blkid
chroot
cryptsetup
debootstrap
gdisk
lsblk
pvcreate
vgcreate
lvcreate
mkpasswd
mkfs.ext2
mkfs.ext4
mkfs.vfat
openssl
printf
EOF
IFS="$____old_IFS"
unset ____line ____old_IFS




# validate target random
TARGET_RANDOM="/dev/urandom"
1>&2 printf -- "I: Checking '%s'...\n" "$TARGET_RANDOM"
if [ ! -e "$TARGET_RANDOM" ]; then
        # What the heck with this host?! No crypto-random?!
        1>&2 printf -- "%s" "\
E: Missing '/dev/urandom'. Sorry - Cannot Proceed At All. Check CPU quality.
E: Bailing Out...

"
        exit 1
fi
1>&2 printf -- "I: All System Checked. Host is Ready.\n\n"




# load previous run's settings from crashes
# NOTICE: use text parsing to prevent any unwanted executable code injection
if [ -f "${0%.sh}.conf" ]; then
        1>&2 printf -- "I: Detected '%s'. Parsing...\n" "${0%.sh}.conf"
        ____old_IFS="$IFS"
        while IFS="" read ____line || [ -n "$____line" ]; do
                ____line="${____line%%#*}"
                if [ "$____line" = "" ]; then
                        continue
                fi


                ____value="${____line#*=}"
                ____key="${____line%%=*}"
                case "$____key" in
                *[!A-Z_]*)
                        continue
                        ;;
                *)
                        ;;
                esac


                if [ ! "$____key" = "" ] && [ ! "$____value" = "" ]; then
                        export "$____key"="$____value"
                fi
                unset ____key ____value
        done < "${0%.sh}.conf"
        IFS="$____old_IFS"
        unset ____old_IFS

        TARGET_RUN_RECOVERED=true
fi




# validate $TARGET_OWNER
____old_IFS="$IFS"
while true; do
        if [ "$TARGET_OWNER" = "" ]; then
                1>&2 printf -- "%s" "\
?: Target Device Name
?: ==================
?: NOTE: 1) only 'a-z', 'A-Z', and '0-9'
?:       2) cannot start with number
?:       3) use in ID-ing the hardware, network ID, and /etc/hostname
?: Your Input (E.g.'EP1'):
?: > "
                IFS= read -r TARGET_OWNER
                IFS="$____old_IFS"
        fi


        case "$TARGET_OWNER" in
        "")
                continue # mis-pressed enter
                ;;
        *[!a-zA-Z0-9]*)
                1>&2 printf -- "%s\n\n" "E: Value is Not Alphanumeric!"
                TARGET_OWNER=""
                continue
                ;;
        [0-9]*)
                1>&2 printf -- "%s\n\n" "E: Value Cannot Begin with Number!"
                TARGET_OWNER=""
                continue
                ;;
        *)
                # all good
                break
                ;;
        esac
done
IFS="$____old_IFS"
unset ____old_IFS
1>&2 printf -- "I: \$TARGET_OWNER is Set to '%s'.\n\n" "$TARGET_OWNER"




# validate $TARGET_MOUNT
____old_IFS="$IFS"
while true; do
        if [ "$TARGET_MOUNT" = "" ]; then
                1>&2 printf -- "%s" "\
?: Target Mountpoint
?: =================
?: Your Input (E.g.'/mnt'):
?: > "
                IFS= read -r TARGET_MOUNT
                IFS="$____old_IFS"
                case "$TARGET_MOUNT" in
                "")
                        continue # mis-pressed enter
                        ;;
                *)
                        ;;
                esac
        fi


        if [ -e "$TARGET_MOUNT" ] && [ ! -d "$TARGET_MOUNT" ]; then
                1>&2 printf -- "%s\n\n" \
                        "E: invalid \$TARGET_MOUNT (%s). Bailing out..." \
                        "$TARGET_MOUNT"
                TARGET_MOUNT=""
                continue
        fi


        break
done
IFS="$____old_IFS"
unset ____old_IFS
1>&2 printf -- "I: \$TARGET_MOUNT is set to '%s'.\n\n" "$TARGET_MOUNT"




# validate target device
____old_IFS="$IFS"
while true; do
        if [ "$TARGET_DEVICE" = "" ]; then
                1>&2 printf -- "%s" "\
?: Target Device
?: =============
?: Your Input (E.g. '/dev/sda'):
?: > "
                IFS= read -r TARGET_DEVICE
                IFS="$____old_IFS"
                case "$TARGET_DEVICE" in
                "")
                        continue # mis-pressed enter
                        ;;
                *)
                        ;;
                esac
        fi


        if [ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
                # scan device node
                case "${TARGET_DEVICE#"/dev/"}" in
                nvme*n*p*)
                        1>&2 printf -- \
                                "E: '%s' cannot be a partition.\n\n" \
                                "$TARGET_DEVICE"
                        TARGET_DEVICE=""
                        continue
                ;;
                nvme*n*)
                        TARGET_PARTITION_EFI="${TARGET_DEVICE}p1"
                        TARGET_PARTITION_BOOT="${TARGET_DEVICE}p2"
                        TARGET_PARTITION_CORE="${TARGET_DEVICE}p3"
                        ;;
                *[0-9])
                        1>&2 printf -- \
                                "E: '%s' cannot be a partition.\n\n" \
                                "$TARGET_DEVICE"
                        TARGET_DEVICE=""
                        continue
                        ;;
                *)
                        TARGET_PARTITION_EFI="${TARGET_DEVICE}1"
                        TARGET_PARTITION_BOOT="${TARGET_DEVICE}2"
                        TARGET_PARTITION_CORE="${TARGET_DEVICE}3"
                        ;;
                esac


                # ensure it's not the current system root
                while IFS="" read ____line || [ -n "$____line" ]; do
                        if [ ! "${____line##"${TARGET_DEVICE#"/dev/"}"}" = "$____line" ]; then
                                if [ ! "${____line##*"/boot"}" = "$____line" ] ||
                                [ "${____line##*"/"}" = "" ]; then
                                        if [ "$TARGET_RUN_RECOVERED" = "true" ]; then
                                                # this is from recovered run
                                                break
                                        fi


                                        1>&2 printf -- \
                                                "E: %s is the current rootsystem.\n\n" \
                                                "$TARGET_DEVICE"
                                        TARGET_DEVICE=""
                                        TARGET_PARTITION_EFI=""
                                        TARGET_PARTITION_BOOT=""
                                        TARGET_PARTITION_CORE=""
                                        break
                                fi
                        fi
                done<<EOF
$(2>&1 lsblk --list)
EOF
                IFS="$____old_IFS"
                unset ____line

                if [ "$TARGET_DEVICE" = "" ] ||
                [ "$TARGET_PARTITION_EFI" = "" ] ||
                [ "$TARGET_PARTITION_BOOT" = "" ] ||
                [ "$TARGET_PARTITION_CORE" = "" ]; then
                        continue
                fi


                # good target -setup partitioning variables
                TARGET_PARTITION_CRYPT="/dev/mapper/${TARGET_PARTITION_CORE##*/}_crypt"
                TARGET_PARTITION_LVM_VG="${TARGET_OWNER}_VG"
                TARGET_PARTITION_LVM_LV="${TARGET_OWNER}_LV"
                TARGET_PARTITION_LVM="/dev/mapper/${TARGET_PARTITION_LVM_VG}-${TARGET_PARTITION_LVM_LV}"
                1>&2 printf -- \
                        "I: \$TARGET_PARTITION_EFI is set to '%s'.\n" \
                        "$TARGET_PARTITION_EFI"
                1>&2 printf -- \
                        "I: \$TARGET_PARTITION_BOOT is set to '%s'.\n" \
                        "$TARGET_PARTITION_BOOT"
                1>&2 printf -- \
                        "I: \$TARGET_PARTITION_CORE is set to '%s'.\n" \
                        "$TARGET_PARTITION_CORE"
                1>&2 printf -- \
                        "I: \$TARGET_PARTITION_CRYPT is set to '%s'.\n" \
                        "$TARGET_PARTITION_CRYPT"
                1>&2 printf -- \
                        "I: \$TARGET_PARTITION_LVM_VG is set to '%s'.\n" \
                        "$TARGET_PARTITION_LVM_VG"
                1>&2 printf -- \
                        "I: \$TARGET_PARTITION_LVM_LV is set to '%s'.\n" \
                        "$TARGET_PARTITION_LVM_LV"
                1>&2 printf -- \
                        "I: \$TARGET_PARTITION_LVM is set to '%s'.\n" \
                        "$TARGET_PARTITION_LVM"
        fi


        # all good
        break
done
IFS="$____old_IFS"
unset ____old_IFS
1>&2 printf -- "I: \$TARGET_DEVICE is set to '%s'.\n\n" "$TARGET_DEVICE"




# validate init type
____old_IFS="$IFS"
while true; do
        if [ "$TARGET_INIT" = "" ]; then
                1>&2 printf -- "%s" "\
?: Select Init for Target OS
?: =========================
?: (1) Systemd
?: (2) InitV
?: Your Input (E.g. '1'):
?: > "
                IFS= read -r TARGET_INIT
                IFS="$____old_IFS"

                case "$TARGET_INIT" in
                "")
                        continue # mis-pressed enter
                        ;;
                *)
                        ;;
                esac
        fi


        case "$TARGET_INIT" in
        "systemd init")
                ;;
        "sysvinit-core sysvinit-utils")
                ;;
        1)
                TARGET_INIT="systemd init"
                ;;
        2)
                TARGET_INIT="sysvinit-core sysvinit-utils"
                ;;
        *)
                1>&2 printf -- "%s\n\n" "E: Invalid Input. Please Retry!"
                TARGET_INIT=""
                continue
        esac


        # all good
        break
done
IFS="$____old_IFS"
unset ____old_IFS
1>&2 printf -- "I: \$TARGET_INIT is set to '%s'.\n\n" "$TARGET_INIT"




# validate cpu architecture
# Source: https://wiki.debian.org/SupportedArchitectures
____old_IFS="$IFS"
while true; do
        if [ "$TARGET_ARCH" = "" ]; then
                1>&2 printf -- "%s" "\
?: Select Architecture for Target OS
?: =================================
?: (1) alpha
?: (2) arm
?: (3) armel
?: (4) armhf
?: (5) arm64
?: (6) hppa
?: (7) i386
?: (8) x32
?: (9) amd64
?: (10) ia64
?: (11) m68k
?: (12) mips
?: (13) mipsel
?: (14) mips64el
?: (15) powerpc
?: (16) powerspe
?: (17) ppc64
?: (18) ppc64el
?: (19) riscv64
?: (20) s390
?: (21) s390x
?: (22) sh4
?: (23) sparc64
?: Your Input (E.g.'9'):
?: > "
                IFS= read -r TARGET_ARCH
                IFS="$____old_IFS"

                case "$TARGET_ARCH" in
                "")
                        continue # mis-pressed enter
                        ;;
                *)
                        ;;
                esac
        fi


        case "$TARGET_ARCH" in
        1|alpha)
                TARGET_ARCH="alpha"
                ;;
        2|arm)
                TARGET_ARCH="arm"
                ;;
        3|armel)
                TARGET_ARCH="armel"
                ;;
        4|armhf)
                TARGET_ARCH="armhf"
                ;;
        5|arm64)
                TARGET_ARCH="arm64"
                ;;
        6|hppa)
                TARGET_ARCH="hppa"
                ;;
        7|i386)
                TARGET_ARCH="i386"
                ;;
        8|x32)
                TARGET_ARCH="x32"
                ;;
        9|amd64)
                TARGET_ARCH="amd64"
                ;;
        10|ia64)
                TARGET_ARCH="ia64"
                ;;
        11|m68k)
                TARGET_ARCH="m68k"
                ;;
        12|mips)
                TARGET_ARCH="mips"
                ;;
        13|mipsel)
                TARGET_ARCH="mipsel"
                ;;
        14|mips64el)
                TARGET_ARCH="mips64el"
                ;;
        15|powerpc)
                TARGET_ARCH="powerpc"
                ;;
        16|powerspe)
                TARGET_ARCH="powerspe"
                ;;
        17|ppc64)
                TARGET_ARCH="ppc64"
                ;;
        18|ppc64el)
                TARGET_ARCH="ppc64el"
                ;;
        19|riscv64)
                TARGET_ARCH="riscv64"
                ;;
        20|s390)
                TARGET_ARCH="s390"
                ;;
        21|s390x)
                TARGET_ARCH="s390x"
                ;;
        22|sh4)
                TARGET_ARCH="sh4"
                ;;
        23|sparc64)
                TARGET_ARCH="sparc64"
                ;;
        *)
                1>&2 printf -- "%s\n\n" "E: Invalid Input. Please Retry!"
                TARGET_ARCH=""
                continue
                ;;
        esac


        # all good
        break
done
IFS="$____old_IFS"
unset ____old_IFS
1>&2 printf -- "I: \$TARGET_ARCH is set to '%s'.\n\n" "$TARGET_ARCH"




# validate kernel
____old_IFS="$IFS"
while true; do
        if [ "$TARGET_KERNEL" = "" ]; then
                1>&2 printf -- "%s" "\
?: Select Kernel for Target OS
?: ===========================
?: (1) Signed Normal Linux
?: (2) Signed Real-Time Linux
?: (3) Signed Cloud Linux
?: Your Input (E.g. '1'):
?: > "
                IFS= read -r TARGET_KERNEL
                IFS="$____old_IFS"

                case "$TARGET_KERNEL" in
                "")
                        continue # mis-pressed enter
                        ;;
                *)
                        ;;
                esac
        fi


        case "$TARGET_KERNEL" in
        "linux-image-${TARGET_ARCH}")
                ;;
        "linux-image-rt-${TARGET_ARCH}")
                ;;
        "linux-image-cloud-${TARGET_ARCH}")
                ;;
        1)
                TARGET_KERNEL="linux-image-${TARGET_ARCH}"
                ;;
        2)
                TARGET_KERNEL="linux-image-rt-${TARGET_ARCH}"
                ;;
        3)
                TARGET_KERNEL="linux-image-cloud-${TARGET_ARCH}"
                ;;
        *)
                1>&2 printf -- "%s\n\n" "E: Invalid Input. Please Retry!"
                TARGET_KERNEL=""
                continue
                ;;
        esac


        # all good
        break
done
IFS="$____old_IFS"
unset ____old_IFS
1>&2 printf -- "I: \$TARGET_KERNEL is set to '%s'.\n\n" "$TARGET_KERNEL"




# valdiate $TARGET_LANG
____old_IFS="$IFS"
while true; do
        if [ "$TARGET_LANG" = "" ]; then
                1>&2 printf -- "%s" "\
?: Default Language Code
?: =====================
?: NOTE: Please refer '/etc/locale.gen' for supported UTF-8 only language
?:       without the UTF-8 charset definition. Example:
?:         * 'en_US' for 'en_US.UTF-8'
?:
?: IMPORTANT NOTICE: only UTF-8 is supported.
?:
?: Your Input (E.g. 'en_US'):
?: > "
                IFS= read -r TARGET_LANG
                IFS="$____old_IFS"

                case "$TARGET_LANG" in
                "")
                        continue # mis-pressed enter
                        ;;
                *)
                        ;;
                esac
        fi


        ____hit=false
        while IFS="" read ____line || [ -n "$____line" ]; do
                if [ ! "${____line##*"${TARGET_LANG}.UTF-8"}" = "$____line" ]; then
                        ____hit=true
                        break
                fi
        done < "/etc/locale.gen"
        IFS="$____old_IFS"
        unset ____line

        if [ ! "$____hit" = "true" ]; then
                1>&2 printf -- "%s\n\n" "E: Invalid Input. Please Retry!"
                TARGET_LANG=""
                continue
        fi


        # all good
        break
done
IFS="$____old_IFS"
unset ____hit ____old_IFS
1>&2 printf -- "I: \$TARGET_LANG is set to '%s'.\n\n" "$TARGET_LANG"




# valdiate $TARGET_TIMEZONE
____old_IFS="$IFS"
while true; do
        if [ "$TARGET_TIMEZONE" = "" ]; then
                1>&2 printf -- "%s" "\
?: Default Timezone
?: ================
?: NOTE: Please refer '/usr/share/zoneinfo/*' for supported timezones.
?:       Any relative path beyond that 'zoneinfo/' directory is the
?:       value. Example:
?:              'Asia/Kuala_Lumpur' -> '/usr/share/zoneinfo/Asia/Kuala_Lumpur'
?:
?: Your Input (E.g. 'UTC'):
?: > "
                IFS= read -r TARGET_TIMEZONE
                IFS="$____old_IFS"

                case "$TARGET_TIMEZONE" in
                "")
                        continue # mis-pressed enter
                        ;;
                *)
                        ;;
                esac
        fi

        if [ ! -e "/usr/share/zoneinfo/${TARGET_TIMEZONE}" ] ||
        [ -d "/usr/share/zoneinfo/${TARGET_TIMEZONE}" ]; then
                1>&2 printf -- "%s\n\n" "E: Invalid Input. Please Retry!"
                TARGET_TIMEZONE=""
                continue
        fi


        # all good
        break
done
IFS="$____old_IFS"
unset ____hit ____old_IFS
1>&2 printf -- "I: \$TARGET_TIMEZONE is set to '%s'.\n\n" "$TARGET_TIMEZONE"




# validate $TARGET_USERNAME_USER
____old_IFS="$IFS"
while true; do
        if [ "$TARGET_USERNAME_USER" = "" ]; then
                1>&2 printf -- "%s" "\
?: Alpha User's Username
?: =====================
?: Your Input:
?: > "
                IFS= read -r TARGET_USERNAME_USER
                IFS="$____old_IFS"
        fi


        case "$TARGET_USERNAME_USER" in
        "")
                continue # mis-pressed enter
                ;;
        *[!a-zA-Z0-9]*)
                1>&2 printf -- "%s\n\n" "E: Value is Not Alphanumeric!"
                TARGET_USERNAME_USER=""
                continue
                ;;
        [0-9]*)
                1>&2 printf -- "%s\n\n" "E: Value Cannot Begin with Number!"
                TARGET_USERNAME_USER=""
                continue
                ;;
        *)
                # all good
                break
                ;;
        esac
done
IFS="$____old_IFS"
unset ____old_IFS
1>&2 printf -- \
        "I: \$TARGET_USERNAME_USER is Set to '%s'.\n\n" \
        "$TARGET_USERNAME_USER"




# valdiate $TARGET_PASSWORD_USER
____old_IFS="$IFS"
while [ "$TARGET_PASSWORD_USER" = "" ]; do
        1>&2 printf -- "%s" "\
?: Alpha User Password (Hidden Field)
?: ==================================
?: Your Input:
?: > "
        trap 'stty echo' EXIT INT HUP
        stty -echo
        IFS= read -r ____password
        IFS="$____old_IFS"
        stty echo
        1>&2 printf -- "\n"
        case "$____password" in
        "")
                continue # mis-pressed enter
                ;;
        *)
                ;;
        esac

        1>&2 printf -- "%s" "\
?: Verify Password:
?: > "
        stty -echo
        IFS= read -r ____verify
        IFS="$____old_IFS"
        stty echo
        1>&2 printf -- "\n"
        case "$____verify" in
        "")
                continue # mis-pressed enter
                ;;
        *)
                ;;
        esac

        if [ ! "$____password" = "$____verify" ]; then
                1>&2 printf -- "E: Password Mismatched!\n\n"
                unset ____password ____verify
                continue
        fi
        unset ____verify


        # password matched
        TARGET_PASSWORD_USER="$( \
                printf -- "%s" "$____password" \
                | mkpasswd --method=yescrypt --stdin 2> /dev/null \
        )"
        case "$TARGET_PASSWORD_USER" in
        '$y$'*)
                # CVE-2026-85649: ensure the mkpasswd always has the correct
                # value before deployment.
                #
                # This path means the mkpasswd has already generated a valid
                # value. All good to proceed.
                ;;
        *)
                # reject install on outdated or incompatible host os.
                1>&2 printf -- "%s" "\
E: Failed to create password using 'mkpasswd' with 'yescrypt' support.
E:
E: This usually happens if:
E:   (1) the 'makepasswd' package is installed instead of 'whois'; AND/OR
E:   (2) your host's libxcrypt is incompatible or too old.
E:
E: This can yield severe security vulnerability for the built image.
E: WILL NOT PROCEED.
E: Bailing Out...

"
                exit 1
                ;;
        esac

        unset ____password ____verify
        break
done
IFS="$____old_IFS"
unset ____old_IFS
1>&2 printf -- \
        "I: \$TARGET_PASSWORD_USER is set to '%s'.\n\n" \
        "$TARGET_PASSWORD_USER"




# valdiate $TARGET_PASSWORD_ROOT
____old_IFS="$IFS"
while [ "$TARGET_PASSWORD_ROOT" = "" ]; do
        1>&2 printf -- "%s" "\
?: Root User Password (Hidden Field)
?: =================================
?: Your Input:
?: > "
        trap 'stty echo' EXIT INT HUP
        stty -echo
        IFS= read -r ____password
        IFS="$____old_IFS"
        stty echo
        1>&2 printf -- "\n"
        case "$____password" in
        "")
                continue # mis-pressed enter
                ;;
        *)
                ;;
        esac

        1>&2 printf -- "%s" "\
?: Verify Password:
?: > "
        trap 'stty echo' EXIT INT HUP
        stty -echo
        IFS= read -r ____verify
        IFS="$____old_IFS"
        stty echo
        1>&2 printf -- "\n"
        case "$____verify" in
        "")
                continue # mis-pressed enter
                ;;
        *)
                ;;
        esac

        if [ ! "$____password" = "$____verify" ]; then
                1>&2 printf -- "E: Password Mismatched!\n\n"
                unset ____password ____verify
                continue
        fi

        # password matched
        TARGET_PASSWORD_ROOT="$( \
                printf -- "%s" "$____password" \
                | mkpasswd --method=yescrypt --stdin 2> /dev/null \
        )"
        case "$TARGET_PASSWORD_ROOT" in
        '$y$'*)
                # CVE-2026-85649: ensure the mkpasswd always has the correct
                # value before deployment.
                #
                # This path means the mkpasswd has already generated a valid
                # value. All good to proceed.
                ;;
        *)
                # reject install on outdated or incompatible host os.
                1>&2 printf -- "%s" "\
E: Failed to create password using 'mkpasswd' with 'yescrypt' support.
E:
E: This usually happens if:
E:   (1) the 'makepasswd' package is installed instead of 'whois'; AND/OR
E:   (2) your host's libxcrypt is incompatible or too old.
E:
E: This can yield severe security vulnerability for the built image.
E: WILL NOT PROCEED.
E: Bailing Out...
"
                exit 1
                ;;
        esac

        unset ____password ____verify
        break
done
IFS="$____old_IFS"
unset ____old_IFS
1>&2 printf -- \
        "I: \$TARGET_PASSWORD_ROOT is set to '%s'.\n\n" \
        "$TARGET_PASSWORD_ROOT"




# save to conf in case of breakdown
1>&2 printf -- "I: Saving build data into '%s'...\n" "${0%.sh}.conf"
printf -- "%s\n" "\
TARGET_OWNER=${TARGET_OWNER}
TARGET_MOUNT=${TARGET_MOUNT}
TARGET_DEVICE=${TARGET_DEVICE}
TARGET_PARTITION_EFI=${TARGET_PARTITION_EFI}
TARGET_PARTITION_BOOT=${TARGET_PARTITION_BOOT}
TARGET_PARTITION_CORE=${TARGET_PARTITION_CORE}
TARGET_PARTITION_CRYPT=${TARGET_PARTITION_CRYPT}
TARGET_PARTITION_LVM_VG=${TARGET_PARTITION_LVM_VG}
TARGET_PARTITION_LVM_LV=${TARGET_PARTITION_LVM_LV}
TARGET_PARTITION_LVM=${TARGET_PARTITION_LVM}
TARGET_INIT=${TARGET_INIT}
TARGET_ARCH=${TARGET_ARCH}
TARGET_KERNEL=${TARGET_KERNEL}
TARGET_LANG=${TARGET_LANG}
TARGET_TIMEZONE=${TARGET_TIMEZONE}
TARGET_USERNAME_USER=${TARGET_USERNAME_USER}
TARGET_PASSWORD_USER=${TARGET_PASSWORD_USER}
TARGET_PASSWORD_ROOT=${TARGET_PASSWORD_ROOT}
" > "${0%.sh}.conf"
1>&2 printf -- "\n"




# read step so that it doesn't repeat
1>&2 printf -- "I: Installation Begins...\n"
____step=0
if [ -f "${0%.sh}.step" ]; then
        while IFS="" read ____line || [ -n "$____line" ]; do
                case "$____line" in
                *[!0-9]*)
                        ;;
                *)
                        ____step="$____line"
                        break
                        ;;
                esac
        done < "${0%.sh}.step"
fi
1>&2 printf -- "\n"




# create gpt table for target device
if [ "$____step" -eq 0 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- \
                "I: Creating GPT Partition Table for '%s'...\n" \
                "$TARGET_DEVICE"
        gdisk $TARGET_DEVICE <<EOF
o
Y
w
Y
EOF
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# create partition layers for target device
if [ "$____step" -eq 1 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- "I: Partitioning '%s'...\n" "$TARGET_DEVICE"
        gdisk $TARGET_DEVICE <<EOF
n
1

+1G
ef00
n
2

+1G
8300
n
3


8309
c
1
${TARGET_OWNER}_EFI
c
2
${TARGET_OWNER}_BOOT
c
3
${TARGET_OWNER}_CORE
w
Y
EOF
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# bitwiping cryptsetup paritition
if [ "$____step" -eq 2 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- "%s" "\
I: Bitwiping '${TARGET_PARTITION_CORE}'...
I: This can takes a while depending on disk size (e.g. hours for TB)...
"
        dd if=/dev/urandom of="$TARGET_PARTITION_CORE" status=progress


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# create cryptsetup datastore
if [ "$____step" -eq 3 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- "%s\n" "\
I: Formatting '${TARGET_PARTITION_CORE}' with 'cryptsetup luks2'..."
        cryptsetup \
                --verbose \
                --use-urandom \
                --type luks2 \
                --cipher aes-xts-plain64 \
                --hash sha512 \
                --pbkdf argon2id \
                --pbkdf-memory 128000 \
                --pbkdf-parallel 1 \
                luksFormat "$TARGET_PARTITION_CORE"
# IMPORTANT NOTICE
# (1) Eventually we want to move towards chcha20-poly1305 (Adiantum) but at
#     the moment Debian 12 kernel does not have a build method to handle such
#     algorithm. Hence, we park the code here for now.
#        cryptsetup \
#                --verbose \
#                --use-urandom \
#                --type luks2 \
#                --cipher chacha20-poly1305 \
#                --hash sha512 \
#                --pbkdf argon2id \
#                --pbkdf-memory 128000 \
#                --pbkdf-parallel 1 \
#                luksFormat "$TARGET_PARTITION_CORE"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# open crypsetup datastore
if [ "$____step" -eq 4 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- \
                "I: Opening '%s' with 'cryptsetup'...\n" \
                "$TARGET_PARTITION_CORE"
        cryptsetup luksOpen \
                "$TARGET_PARTITION_CORE" \
                "${TARGET_PARTITION_CRYPT##*/}"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# format lvm physical volume
if [ "$____step" -eq 5 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- \
                "I: Setting Up '%s' with 'pvcreate'...\n" \
                "$TARGET_PARTITION_CRYPT"
        pvcreate "$TARGET_PARTITION_CRYPT"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# format lvm volume group
if [ "$____step" -eq 6 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- \
                "I: Setting Up '%s' with 'vgcreate'...\n" \
                "$TARGET_PARTITION_CRYPT"
        vgcreate "$TARGET_PARTITION_LVM_VG" "$TARGET_PARTITION_CRYPT"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# format lvm logical volume
if [ "$____step" -eq 7 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        lvcreate \
                --name "$TARGET_PARTITION_LVM_LV" \
                --extents "100%FREE" \
                "$TARGET_PARTITION_LVM_VG"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# format ext4 logical volume
if [ "$____step" -eq 8 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- \
                "I: Formatting '%s' to 'ext4'...\n" \
                "$TARGET_PARTITION_LVM"
        mkfs.ext4 -m 0 "$TARGET_PARTITION_LVM"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# format legacy boot volume
if [ "$____step" -eq 9 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- \
                "I: Formatting '%s' to 'ext2'...\n" \
                "$TARGET_PARTITION_BOOT"
        mkfs.ext2 -m 0 "$TARGET_PARTITION_BOOT"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# format efi boot volume
if [ "$____step" -eq 10 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- \
                "I: Formatting '%s' to 'vfat'...\n" \
                "$TARGET_PARTITION_EFI"
        mkfs.vfat "$TARGET_PARTITION_EFI"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# mount core data volume
if [ "$____step" -eq 11 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- "I: Creating '%s' Mountpoint...\n" "$TARGET_MOUNT"
        mkdir -p "$TARGET_MOUNT"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi

        1>&2 printf -- \
                "I: Mounting '%s' to '%s'...\n" \
                "$TARGET_PARTITION_LVM" \
                "$TARGET_MOUNT"
        mount "$TARGET_PARTITION_LVM" "$TARGET_MOUNT"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# debootstrap data volume
if [ "$____step" -eq 12 ]; then
        1>&2 printf -- \
                "I: Bootstraping 'debian-%s' into '%s'...\n" \
                "$TARGET_ARCH" \
                "$TARGET_MOUNT"
        debootstrap \
                --variant='minbase' \
                --arch "$TARGET_ARCH" \
                --merged-usr \
                --include "ca-certificates,apt-transport-https" \
                "stable" \
                "$TARGET_MOUNT" \
                "https://deb.debian.org/debian"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# mount boot volume
if [ "$____step" -eq 13 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- \
                "I: Mounting '%s' to '%s'...\n" \
                "$TARGET_PARTITION_BOOT" \
                "${TARGET_MOUNT}/boot"
        mkdir -p "${TARGET_MOUNT}/boot"
        mount "$TARGET_PARTITION_BOOT" "${TARGET_MOUNT}/boot"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# mount efi volume
if [ "$____step" -eq 14 ] &&
[ ! "${TARGET_DEVICE#"/dev/"}" = "$TARGET_DEVICE" ]; then
        1>&2 printf -- \
                "I: Mounting '%s' to '%s'...\n" \
                "$TARGET_PARTITION_EFI" \
                "${TARGET_MOUNT}/boot/efi"
        mkdir -p "${TARGET_MOUNT}/boot/efi"
        mount "$TARGET_PARTITION_EFI" "${TARGET_MOUNT}/boot/efi"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# mount hostsystem for chroot
if [ "$____step" -eq 15 ]; then
        for ____target in /dev /dev/pts /proc /sys /sys/firmware/efi/efivars /run; do
                if [ ! -e "$____target" ]; then
                        continue
                fi


                1>&2 printf -- \
                        "I: Mounting '%s' to '%s' for Target OS...\n" \
                        "$____target" \
                        "${TARGET_MOUNT%/}/${____target#/}"


                mount -B "$____target" "${TARGET_MOUNT%/}/${____target#/}"
                if [ $? -ne 0 ]; then
                        1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                        exit 1
                fi
        done
        unset ____target


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# overwrite target's main apt source.list
if [ "$____step" -eq 16 ]; then
        1>&2 printf -- \
                "I: Overwriting '/etc/apt/sources.list' for Target OS...\n"
        printf -- "%s\n" "\
deb https://deb.debian.org/debian/ stable main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ stable main contrib non-free non-free-firmware

deb https://security.debian.org/debian-security stable-security main contrib non-free non-free-firmware
deb-src https://security.debian.org/debian-security stable-security main contrib non-free non-free-firmware

deb https://deb.debian.org/debian/ stable-updates main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ stable-updates main contrib non-free non-free-firmware

deb https://deb.debian.org/debian/ stable-backports main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ stable-backports main contrib non-free non-free-firmware
" > "${TARGET_MOUNT}/etc/apt/sources.list"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        1>&2 printf -- \
                "I: Updating '/etc/apt/sources.list' Permissions for Target OS...\n"
        chmod 644 "${TARGET_MOUNT}/etc/apt/sources.list"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        1>&2 printf -- \
                "I: Updating '/etc/apt/sources.list' Ownership for Target OS...\n"
        chown root:root "${TARGET_MOUNT}/etc/apt/sources.list"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# apt update target os
if [ "$____step" -eq 17 ]; then
        1>&2 printf -- "I: Apt Updating for Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "apt update -y"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# apt setup target os' locales
if [ "$____step" -eq 18 ]; then
        1>&2 printf -- "I: Apt Reinstalling 'locales' for Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "apt install --reinstall locales -y"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        1>&2 printf -- "I: Setting Default Language for Target OS...\n"
        ____old_IFS="$IFS"
        while IFS="" read ____line || [ -n "$____line" ]; do
                if [ ! "${____line##*"${TARGET_LANG}.UTF-8"}" = "$____line" ]; then
                        ____line="${TARGET_LANG}.UTF-8 UTF-8"
                fi

                printf -- "%s\n" "$____line" \
                        >> "${TARGET_MOUNT}/etc/locale.gen.tmp"
        done < "${TARGET_MOUNT}/etc/locale.gen"
        IFS="$____old_IFS"
        unset ____line ____old_IFS

        if [ ! -f "${TARGET_MOUNT}/etc/locale.gen.tmp" ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi

        mv "${TARGET_MOUNT}/etc/locale.gen.tmp" "${TARGET_MOUNT}/etc/locale.gen"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        1>&2 printf -- "I: Dpkg-reconfiguring 'locales' for Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
dpkg-reconfigure --frontend noninteractive locales \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        1>&2 printf -- "I: Updating Locale for Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
update-locale LANG=${TARGET_LANG}.UTF-8 \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# setup default keyboard
if [ "$____step" -eq 19 ]; then
        1>&2 printf -- \
                "I: Apt Reinstalling 'keyboard-configuration' for Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
DEBIAN_FRONTEND=noninteractive apt install --reinstall keyboard-configuration -y \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        1>&2 printf -- "I: Setting Default Keyboard for Target OS...\n"
        ____lang="en"
        if [ ! "${TARGET_LANG%%_*}" = "en" ]; then
                ____lang="en,${TARGET_LANG%%_*}"
        fi

        printf -- "%s\n" "\
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL=\"pc105\"
XKBLAYOUT=\"${____lang}\"
XKBVARIANT=\"\"
XKBOPTIONS=\"\"

BACKSPACE=\"guess\"
" > "${TARGET_MOUNT}/etc/default/keyboard"
        if [ $? -ne 0 ]; then
                unset ____lang
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi
        unset ____lang


        1>&2 printf -- \
                "I: Dpkg-reconfiguring 'keyboard-configuration' for Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
dpkg-reconfigure --frontend noninteractive keyboard-configuration \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# setup timezone
if [ "$____step" -eq 20 ]; then
        1>&2 printf -- "I: Setting Timezone for Target OS...\n"
        printf -- "%s" "${TARGET_TIMEZONE}" > "${TARGET_MOUNT}/etc/timezone"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        1>&2 printf -- "I: Clean Up Existing Localtime for Target OS...\n"
        rm -f "${TARGET_MOUNT}/etc/localtime" > /dev/null


        1>&2 printf -- \
                "I: Dpkg-reconfiguring 'tzdata' for Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
dpkg-reconfigure --frontend noninteractive tzdata \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# apt setup init
if [ "$____step" -eq 21 ]; then
        1>&2 printf -- \
                "I: Apt Installing '%s' for Target OS...\n" \
                "$TARGET_INIT"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "apt install ${TARGET_INIT} -y"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# setup /etc/hostname
if [ "$____step" -eq 22 ]; then
        1>&2 printf -- "I: Setting Up /etc/hostname for Target OS...\n"
        printf -- "%s" "$TARGET_OWNER" > "${TARGET_MOUNT}/etc/hostname"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# setup /etc/crypttab
if [ "$____step" -eq 23 ]; then
        1>&2 printf -- "I: Setting Up '/etc/crypttab' for Target OS...\n"


        ____uuid_core="$(blkid -s UUID -o value "$TARGET_PARTITION_CORE")"
        if [ "$____uuid_core" = "" ]; then
                1>&2 printf -- \
                        "E: Failed to get UUID for '%s'. Bailing Out...\n\n" \
                        "$TARGET_PARTITION_CORE"
                unset ____uuid_core
                exit 1
        fi

        printf -- "%s\n" "\
# <target name> <source device> <key file> <options>
${TARGET_PARTITION_CRYPT##*/} \
UUID=${____uuid_core} \
none \
luks,discard
" > "${TARGET_MOUNT}/etc/crypttab"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                unset ____uuid_core
                exit 1
        fi
        unset ____uuid_core


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# apt setup cryptsetup
if [ "$____step" -eq 24 ]; then
        1>&2 printf -- \
                "I: Apt Installing 'cryptsetup cryptsetup-initramfs' for Target OS..\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
apt install cryptsetup cryptsetup-initramfs -y \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# apt setup lvm2
if [ "$____step" -eq 25 ]; then
        1>&2 printf -- "I: Apt Installing 'lvm2' for Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "apt install lvm2 -y"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# setup /etc/fstab
if [ "$____step" -eq 26 ]; then
        1>&2 printf -- "I: Setting Up /etc/crypttab for Target OS...\n"


        ____uuid_boot="$(blkid -s UUID -o value "$TARGET_PARTITION_BOOT")"
        if [ "$____uuid_boot" = "" ]; then
                1>&2 printf -- \
                        "E: Failed to get UUID for '%s'. Bailing Out...\n\n" \
                        "$TARGET_PARTITION_BOOT"
                unset ____uuid_boot
                exit 1
        fi


        ____uuid_efi="$(blkid -s UUID -o value "$TARGET_PARTITION_EFI")"
        if [ "$____uuid_efi" = "" ]; then
                1>&2 printf -- \
                        "E: Failed to get UUID for '%s'. Bailing Out...\n\n" \
                        "$TARGET_PARTITION_EFI"
                unset ____uuid_efi
                exit 1
        fi


        printf -- "%s\n" "\
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point> <type> <options> <dump> <pass>
${TARGET_PARTITION_LVM} / ext4 defaults 0 1
UUID=${____uuid_boot} /boot ext2 defaults 0 2
UUID=${____uuid_efi} /boot/efi vfat umask=0077 0 1
" > "${TARGET_MOUNT}/etc/fstab"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                unset ____uuid_boot ____uuid_efi
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# setup signed kernel
if [ "$____step" -eq 27 ]; then
        1>&2 printf -- \
                "I: Apt Installing '%s' for Target OS...\n" \
                "$TARGET_KERNEL"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "apt install ${TARGET_KERNEL} -y"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# setup signed bootloader
if [ "$____step" -eq 28 ]; then
        1>&2 printf -- \
                "I: Apt Installing '%s' for Target OS...\n" \
                "shim-signed grub-efi-${TARGET_ARCH}-signed dkms"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
apt install --reinstall shim-signed grub-efi-${TARGET_ARCH}-signed dkms -y \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        1>&2 printf -- "I: Setting Up Booloader for Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
grub-install \
        --uefi-secure-boot \
        --recheck \
        --no-nvram \
        --removable \
        --efi-directory=/boot/efi \
        --boot-directory=/boot \
        '${TARGET_DEVICE}' \
&& GRUB_DISABLE_OS_PROBER=true update-grub \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# apt setup network
if [ "$____step" -eq 29 ]; then
        1>&2 printf -- \
                "I: Apt Installing '%s' for Target OS...\n" \
                "iwd connman iproute2"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
apt install iwd connman iproute2 -y \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# setup alpha user
if [ "$____step" -eq 30 ]; then
        1>&2 printf -- "I: Add Alpha User to Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
adduser --shell '/bin/bash' --gecos '' --disabled-password '${TARGET_USERNAME_USER}' \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        1>&2 printf -- "I: Setup Alpha User's Password to Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
usermod -p '${TARGET_PASSWORD_USER}' '${TARGET_USERNAME_USER}' \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# create alpha user's home directory
if [ "$____step" -eq 31 ]; then
        1>&2 printf -- \
                "I: Creating Alpha User's Home Directory for Target OS...\n"
        mkdir -p "${TARGET_MOUNT}/home/${TARGET_USERNAME_USER}"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi

        printf -- "%s\n" '#!/bin/sh
# INITIALIZATION
# ==============
# Initialize bash sequences from system-level
[ -f /etc/environment ] && . /etc/environment
[ -f /etc/profile ] && . /etc/profile




# BANNERS
# =======
# Printout message banner
[ -f /etc/banner ] && cat /etc/banner
[ -f "${HOME}/.local/etc/banner" ] && cat "${HOME}/.local/etc/banner"
[ -f "${HOME}/.config/banner" ] && cat "${HOME}/.config/banner"
[ -n "$FAILSAFE" ] && [ -f "/etc/banner.failsafe" ] && cat /etc/banner.failsafe
' > "${TARGET_MOUNT}/home/${TARGET_USERNAME_USER}/.profile"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        printf -- "%s\n" "\
if [ -f \"\${HOME}/.profile\" ]; then
        source \"\${HOME}/.profile\"
fi
" > "${TARGET_MOUNT}/home/${TARGET_USERNAME_USER}/.bashrc"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        printf -- "%s\n" "\
if [ -f \"\${HOME}/.profile\" ]; then
        source \"\${HOME}/.profile\"
fi
" > "${TARGET_MOUNT}/home/${TARGET_USERNAME_USER}/.bash_profile"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
chmod 644 /home/${TARGET_USERNAME_USER}/.profile \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
chmod 644 /home/${TARGET_USERNAME_USER}/.bashrc \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
chmod 644 /home/${TARGET_USERNAME_USER}/.bash_profile \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
chown -R ${TARGET_USERNAME_USER}:${TARGET_USERNAME_USER} /home/${TARGET_USERNAME_USER} \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# setup root user
if [ "$____step" -eq 32 ]; then
        1>&2 printf -- "I: Setup Root User's Password for Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "\
usermod -p '${TARGET_PASSWORD_ROOT}' root \
"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# configure root's home directory
if [ "$____step" -eq 33 ]; then
        1>&2 printf -- \
                "I: Configuring Root User's Home Directory for Target OS...\n"
        cp "${TARGET_MOUNT}/home/${TARGET_USERNAME_USER}/.profile" \
                "${TARGET_MOUNT}/root/.profile"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        cp "${TARGET_MOUNT}/home/${TARGET_USERNAME_USER}/.bashrc" \
                "${TARGET_MOUNT}/root/.bashrc"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        cp "${TARGET_MOUNT}/home/${TARGET_USERNAME_USER}/.bash_profile" \
                "${TARGET_MOUNT}/root/.bash_profile"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        chroot "$TARGET_MOUNT" "/bin/sh" -c "chmod 644 /root/.profile"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        chroot "$TARGET_MOUNT" "/bin/sh" -c "chmod 644 /root/.bashrc"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        chroot "$TARGET_MOUNT" "/bin/sh" -c "chmod 644 /root/.bash_profile"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        chroot "$TARGET_MOUNT" "/bin/sh" -c "chown -R root:root /root"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi


        # track step
        1>&2 printf -- "\n"
        ____step=$(($____step + 1))
        printf -- "%d\n" "$____step" > "${0%.sh}.step"
fi




# purge sudo for resources conservation
____step=9998
if [ "$____step" -eq 9998 ]; then
        1>&2 printf -- \
                "I: Purging 'sudo' To Conserve Resources for Target OS...\n"
        chroot "$TARGET_MOUNT" "/bin/sh" -c "apt purge sudo -y"
        if [ $? -ne 0 ]; then
                1>&2 printf -- "E: Operation Failed. Bailing Out...\n\n"
                exit 1
        fi
fi




# setup completed - ask user for chroot
____step=9999
printf -- "%d\n" "$____step" > "${0%.sh}.step"
while true; do
        1>&2 printf -- "%s" "\
?: Setup Completed SUCCESSFULLY
?: ============================
?: chroot into system?
?: (1) YES
?: (2) No
?: Your Input (E.g. '1'):
?: > "
        IFS= read -r ____input
        IFS="$____old_IFS"

        case "$____input" in
        "")
                continue # mis-pressed enter
                ;;
        1)
                1>&2 printf -- "\n"
                chroot "$TARGET_MOUNT" "/bin/bash"
                exit $?
                ;;
        2)
                1>&2 printf -- "\n"
                exit 0
                ;;
        *)
                ;;
        esac
done
