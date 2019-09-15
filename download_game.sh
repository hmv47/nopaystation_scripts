#!/bin/sh

# AUTHOR sigmaboy <j.sigmaboy@gmail.com>
# Version 0.4

# return codes:
# 1 user errors
# 2 link or key missing
# 5 game archive already exists

# get directory where the scripts are located
SCRIPT_DIR="$(dirname "$(readlink -f "$(which "${0}")")")"

# source shared functions
. "${SCRIPT_DIR}/functions.sh"

my_usage() {
    echo ""
    echo "Usage:"
    echo "${0} \"/path/to/GAME.tsv\" \"PCSE00986\""
}

MY_BINARIES="pkg2zip sed t7z wine file"
sha256_choose; downloader_choose

check_binaries "${MY_BINARIES}"

# Get variables from script parameters
TSV_FILE="${1}"
GAME_ID="${2}"


if [ ! -f "${TSV_FILE}" ]
then
    echo "No TSV file found."
    my_usage
    exit 1
fi
if [ -z "${GAME_ID}" ]
then
    echo "No game ID found."
    my_usage
    exit 1
fi

# check if MEDIA ID is found in download list
if ! grep "^${GAME_ID}" "${TSV_FILE}" > /dev/null
then
    echo "ERROR:"
    echo "Media ID is not found in your *.tsv file"
    echo "Check your input for a valid media ID"
    echo "Search on: \"https://renascene.com/psv/\" for"
    echo "Media IDs or simple open the *.tsv with your Office Suite."
    exit 1
fi

# get link, encryption key and sha256sum
LIST=$(grep "^${GAME_ID}" "${TSV_FILE}" | cut -f"4,5,10")

# save those in separete variables
LINK=$(echo "${LIST}" | cut -f1)
KEY=$(echo "${LIST}" | cut -f2)
LIST_SHA256=$(echo "${LIST}" | cut -f3)

if [ "${KEY}" = "MISSING" ] || [ "${LINK}" = "MISSING" ]
then
    echo "zrif key or link missing. Cannot proceed."
    exit 2
else
    my_download_file "$LINK" "${GAME_ID}.pkg"
    FILE_SHA256="$(my_sha256 "${GAME_ID}.pkg")"

    if [ "${FILE_SHA256}" != "${LIST_SHA256}" ]
    then
        echo "Checksum of downloaded file does not match checksum in list"
        echo "${FILE_SHA256} != ${LIST_SHA256}"
        yesno_checksum
    fi
    pkg2zip -l "${GAME_ID}.pkg" > "${GAME_ID}.txt"
    MY_GAME_NAME="$(cat "${GAME_ID}.txt" | sed 's/\.zip//g')"
    MY_GAME_NAME="$(region_rename "${MY_GAME_NAME}")"
    if [ -f "${MY_GAME_NAME}.7z" ]
    then
        if [ "$(file -b --mime-type "${MY_GAME_NAME}.7z")" = "application/x-7z-compressed" ]
        then
            # print this to stderr
            >&2 echo "File \"${MY_GAME_NAME}.7z\" already exists."
            >&2 echo "Skip compression and remove ${GAME_ID}.pkg file"
            rm "${GAME_ID}.pkg"
            exit 5
        fi
    else
        pkg2zip -x "${GAME_ID}.pkg" "${KEY}"
        t7z a "${MY_GAME_NAME}.7z" "app/"
        rm -rf "app/"
        rm "${GAME_ID}.pkg"
    fi
fi
exit 0
