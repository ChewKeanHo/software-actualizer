#!/bin/sh
# Copyright 2025 (Holloway) Chew, Kean Ho <hello@hollowaykeanho.com>
# Copyright 2022 (Holloway) Chew, Kean Ho <kean.ho.chew@zoralab.com>
#
#
# Licensed under (Holloway) Chew, Kean Ho's Liberal License (the 'License').
# You must comply with the license to use the content. Get the License at:
#
# https://doi.org/10.5281/zenodo.13770769
#
# You MUST ensure any interaction with the content STRICTLY COMPLIES with
# the permissions and limitations set forth in the license.




____old_IFS="$IFS"
while IFS="" read -r ____library || [ -n "$____library" ]; do
        if [ -f "${LIBS_HESTIA}/${____library}" ]; then
                . "${LIBS_HESTIA}/${____library}"
                if [ $? -ne 0 ]; then
                        1>&2 printf -- "E: Bad Import '%s'.\n" "$____library"
                        unset ____library
                        return 1
                fi

                continue
        fi

        1>&2 printf -- "E: Missing Library '%s'.\n" "$____library"
        unset ____library
        return 1
done<<EOF
HestiaKERNEL/Signals/Codes.sh
EOF
IFS="$____old_IFS"
unset ____library ____old_IFS




HestiaDEBIANS_Bootstrap_Install_Network() {
        #____directory_chroot="$1"
        #____target_shell="$2"


        # validate input
        if [ "$1" = "" ]; then
                return $HestiaSIGNALS_ENTITY_IS_EMPTY
        fi

        if [ ! -d "$1" ]; then
                return $HestiaSIGNALS_ENTITY_IS_NOT_DIRECTORY
        fi

        if [ "$2" = "" ]; then
                return $HestiaSIGNALS_DATA_IS_EMPTY
        fi


        # execute
        chroot "$1" "$2" -c "apt install iwk connman iproute2 -y"
        if [ $? -ne 0 ]; then
                return $HestiaSIGNALS_BAD_EXEC
        fi


        # report status
        return $HestiaSIGNALS_OK
}




# report import status
return 0
