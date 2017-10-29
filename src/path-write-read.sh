#!/bin/bash

##
#
#  Path reader and writer.
#
#  Copyright 2017 Alex Vesev <alex.vesev@gmail.com>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#


PS4="+:\$( basename "\${0}" ):\${LINENO}: "
set -x
set -e

declare     error_state="Ok"
declare -a  actions_pool


if [ -z "${1}" ] ; then
    set +x
    cat "${0}" >&2
    echo "ERROR:${0}:${LINENO}: Unknown CLI option '${1}'" >&2
    exit 1
fi

while [ -n "${1}" ] ; do
    option="${1%%=*}"
    value="${1#*=}"
    case "${option}" in
    --write|-r)
        actions_pool+=("write")
    ;;
    --read|-r)
        actions_pool+=("read")
    ;;
    --amount-write|-z)
        declare -r data_amount="${value//[,._ ]/}"  # Remove ',' or '.' or '_' or space from the value.
    ;;
    --number-of-laps|-l)
        declare -r num_of_laps="${value//[,._ ]/}"  # Remove ',' or '.' or '_' or space from the value.
    ;;
    --path|-p)
        declare -r target_path="${value}"
    ;;
    --chunk|-c)
        declare -r chunk_write_size="${value//[,._ ]/}"  # Remove ',' or '.' or '_' or space from the value.
    ;;
    --clean-up|-e)
        declare -r clean_up="true"
    ;;
    --help|-h)
        set +x
        echo "INFO:${0}:${LINENO}: Manual replacement is below."
        echo -ne "\n"
        cat "${0}" >&1
        exit 0
    ;;
    *)
        set +x
        echo "ERROR:${0}:${LINENO}: Unknown CLI option '${1}'" >&2
        echo "cat \"${0}\"" >&1
        exit 1
    esac
    shift
done

if [ -z "${data_amount}" ] ; then
    declare -r data_amount=$(( 1*1024*1024 ))
fi
if [ -z "${chunk_write_size}" ] ; then
    declare -r chunk_write_size=$(( 8*1024*1024 ))  # Try to play with. May be equal to an underlying cache size at maximum speed.
fi
if [ -z "${target_path}" ] ; then
    declare -r target_path="/dev/null"
fi
if [ -z "${clean_up}" ] ; then
    declare -r clean_up="false"
fi

if [ "${#actions_pool[@]}" -lt 1 ] ; then
    set +x
    echo "ERROR:${0}:${LINENO}: Need an action to be specified at CLI." >&2
    exit 1
fi


# # #
 # #
# #
 #
#


function do_job {
    for action in "${actions_pool[@]}" ; do
        "${action}" "${target_path}" "${data_amount}" "${chunk_write_size}"
    done
}


function write {
    local -r path="${1}"
    local -r amount="${2}"
    local -r sz_chunk="${3}"
    local    count

    do_dd "/dev/zero" "${path}" \
        "${amount}" "${sz_chunk}" oflag="dsync"
}

function read {
    local -r path="${1}"
    local -r amount="${2}"
    local -r sz_chunk="${3}"
    local    count

    if [ -e "${path}" ] ; then
        echo 3 > "/proc/sys/vm/drop_caches"
        do_dd "${path}" "/dev/null" \
                "${amount}" "${sz_chunk}" iflag="direct"
    else
        echo "ERROR:${0}:${LINENO}: Not found: '${path}'" >&2
        error_state="error"
    fi
}

function do_dd {
    local -r path_donor="${1}"
    local -r path_acceptor="${2}"
    local -r amount="${3}"
    local -r sz_chunk="${4}"
    shift 4

    local    count

    test -n "${path_donor}"
    test -n "${path_acceptor}"
    test -n "${amount}"
    count="$(( ${amount}/${sz_chunk}))"
    if [ "${count}" -lt 1 ] ; then
        count=1
    fi
    if [ -n "${sz_chunk}" ] ; then
        dd if="${path_donor}" \
            of="${path_acceptor}" \
            bs="${sz_chunk}" \
            count="${count}" \
            "${@}"
    else
        echo dd if="${path_donor}" of="/dev/null" "${@}"
    fi
}


# # #
 # #
# #
 #
#


if [ "${num_of_laps,,}" == "infinite" ] ; then  # ',,' is lower case.
    while : ; do
        do_job
    done
else
    for ((x=1; x<="${num_of_laps}"; x++)) ; do
        do_job
    done
fi

if [ "${clean_up,,}" == "true" ] && [ -f "${target_path}" ] ; then  # ',,' is lower case.
    rm -f "${target_path}"
fi

set +x
if [ "${error_state,,}" == "ok" ] ; then  # ',,' is lower case.
    echo -ne "\n"
    echo "INFO:${0}:${LINENO}: Job done." >&2
else
    echo -ne "\n"
    echo "ERROR:${0}:${LINENO}: Job done with errors." >&2
fi
