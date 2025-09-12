#!/bin/sh
# Copyright 2024 (Holloway) Chew, Kean Ho <hello@hollowaykeanho.com>
#
#
# Licensed under (Holloway) Chew, Kean Ho's Liberal License (the 'License').
# You must comply with the license to use the content. Get the License at:
#
# https://doi.org/10.5281/zenodo.13770769
#
# You MUST ensure any interaction with the content STRICTLY COMPLIES with
# the permissions and limitations set forth in the license.




# setup parameters
LIBS_HESTIA="${LIBS_HESTIA:-"${PWD%/*}"}"
if [ ! -x "${LIBS_HESTIA}/HestiaKERNEL/Test.sh" ]; then
        1>&2 printf -- "E: unable to execute local test run.\n"
        exit 1
fi


case "$QUIET_MODE" in
false)
        QUIET_MODE="false"
        ;;
*)
        QUIET_MODE="true"
        ;;
esac


DIR_WORKSPACE="${LIBS_HESTIA}/HestiaKERNEL"
if [ ! -d "$DIR_WORKSPACE" ]; then
        1>&2 printf -- "E: missing '%s'.\n" "$DIR_WORKSPACE"
fi




# import library
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
HestiaKERNEL/FS/Get-Files.sh
HestiaKERNEL/Unicodes/Init.sh
HestiaKERNEL/Tests/Codes.sh
HestiaKERNEL/Tests/Exec-Case.sh
EOF
IFS="$____old_IFS"
unset ____library ____old_IFS




# check if single script is provided
if [ -f "$1" ]; then
        1>&2 printf -- "I: Executing '%s'...\n" "$1"
        HestiaTESTS_Exec_Case "$1" "" "false"
        return $?
fi




# execute all scripts
____stat_total=0
____stat_passed=0
____stat_skipped=0
____stat_failed=0
____old_test_IFS="$IFS"
while IFS="" read ____script_test || [ -n "$____script_test" ]; do
        if [ ! -f "$____script_test" ]; then
                continue
        fi


        # it's a valid test script - begin testing
        1>&2 printf -- "I: Executing '%s'...\n" "$____script_test"
        ____stat_total=$(($____stat_total + 1))

        if [ "$QUIET_MODE" = "" ]; then
                1>&2 printf -- "\n\n"
        fi

        HestiaTESTS_Exec_Case "$____script_test" "" "$QUIET_MODE"
        case $? in
        $HestiaTESTS_PASSED)
                ____stat_passed=$(($____stat_passed + 1))
                ;;
        $HestiaTESTS_SKIPPED)
                ____stat_skipped=$(($____stat_skipped + 1))
                ;;
        *)
                ____stat_failed=$(($____stat_failed + 1))
                ;;
        esac
done <<EOF
$(HestiaFS_Get_Files "$DIR_WORKSPACE" "_test.sh" "-1")
EOF
IFS="$____old_test_IFS"
unset ____old_test_IFS ____script_test




# print overall test report
1>&2 printf -- "\n
TEST RESULTS
----------------
TOTAL   : %b
PASSED  : %b
SKIPPED : %b
FAILED  : %b
----------------
" "$____stat_total" "$____stat_passed" "$____stat_skipped" "$____stat_failed"




# report status
if [ $____stat_failed -eq 0 ]; then
        return 0
fi

return 1
