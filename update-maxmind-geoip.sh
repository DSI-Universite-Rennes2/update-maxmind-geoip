#!/bin/bash
#
# Update local MaxMind's DB files
#
# -----------------------------------------------------------------------------
# License : European Union Public License 1.2
#           https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12
#
# SPDX-License-Identifier: EUPL-1.2
# -----------------------------------------------------------------------------
# Copyright (c) 2024 DSI - Université Rennes 2
#               Yann 'Ze' Richard <yann.richard à univ-rennes2.fr>
# -----------------------------------------------------------------------------
LDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
TMPDIR=$(mktemp -d -t 'geoip.XXXXXX')
if [[ ! "$TMPDIR" || ! -d "$TMPDIR" ]]; then
    echoerr "Could not create temp dir"
    exit 5
fi
trap 'rm -rf "$TMPDIR"' EXIT

RED='\033[0;31m'
NC='\033[0m' # No Color
# -----------------------------------------------------------------------------
function log () {
    if [[ $VERBOSE -eq 1 ]]
    then
        echo "$@"
    fi
}

function logerr () {
    echo -en "[${RED}ERROR${NC}] " 1>&2
    echo "$@" 1>&2
}

function usage() {
    echo "Usage :"
    echo "$0 [ </path/to/a/GeoIP.conf> [/path/to/where/u/want/your/files] ]"
    echo "    see README.md"
    echo ""
}

# Update MAXMIND_EDITIONS according to 
function foundEditions() {
    
    if [ -n "$MAXMIND_EDITIONS" ]
    then
        return 0
    elif [ -e "$GEOIP_CONFIG_FILE" ]
    then
        local MAXMIND_EDITIONS_TXT
        MAXMIND_EDITIONS_TXT=$(grep '^EditionIDs' "$GEOIP_CONFIG_FILE" | sed 's/^EditionIDs\s*//')
        # shellcheck disable=SC2206
        MAXMIND_EDITIONS=( $MAXMIND_EDITIONS_TXT )
    else
        MAXMIND_EDITIONS=('GeoLite2-ASN' 'GeoLite2-City' 'GeoLite2-Country')
    fi
}

function foundAccountID() {
    if [ -n "$MAXMIND_ACCOUNT_ID" ]
    then
        # success
        return 0
    elif [ -n "$MAXMIND_ACCOUNT_ID_FILE" ] && [ -f "$MAXMIND_ACCOUNT_ID_FILE" ]
    then
        MAXMIND_ACCOUNT_ID=$(head -1 < "$MAXMIND_ACCOUNT_ID_FILE" )
        # success
        return 0
    elif [ -e "$GEOIP_CONFIG_FILE" ]
    then
        MAXMIND_ACCOUNT_ID=$(grep '^AccountID' "$GEOIP_CONFIG_FILE" | awk '{print $2}' )
        if [ -n "$MAXMIND_ACCOUNT_ID" ]
        then
            return 0
        fi
    fi
    logerr "Cannot retreive Maxmind License key from MAXMIND_LICENSE_KEY or $GEOIP_CONFIG_FILE"
    exit 3
}

function foundLicenseKey() {
    if [ -n "$MAXMIND_LICENSE_KEY" ]
    then
        # success
        return 0
    elif [ -n "$MAXMIND_LICENSE_KEY_FILE" ] && [ -f "$MAXMIND_LICENSE_KEY_FILE" ]
    then
        MAXMIND_LICENSE_KEY=$(head -1 < "$MAXMIND_LICENSE_KEY_FILE" )
        # success
        return 0
    elif [ -e "$GEOIP_CONFIG_FILE" ]
    then
        MAXMIND_LICENSE_KEY=$(grep '^LicenseKey' "$GEOIP_CONFIG_FILE" | awk '{print $2}' )
        if [ -n "$MAXMIND_LICENSE_KEY" ]
        then
            return 0
        fi
    fi
    logerr "Cannot retreive Maxmind License key from MAXMIND_LICENSE_KEY or $GEOIP_CONFIG_FILE"
    exit 4
}

function updateMaxmindDB() {
    local edition=''
    # shellcheck disable=SC2048
    for edition in ${MAXMIND_EDITIONS[*]}
    do
        local TMPDEST="${TMPDIR}/${edition}.mmdb.gz"
        local CURL_OPTS=''
        local CURRENT_MD5
        local UPDATE_URI

        CURRENT_MD5=$(md5sum "${DEST_DIR}/${edition}.mmdb" 2>/dev/null | awk '{print $1}')
        # shellcheck disable=SC2059
        UPDATE_URI=$(printf "$MAXMIND_DOWNLOAD_URI" "$edition")

        if [[ $VERBOSE -eq 0 ]]
        then
            CURL_OPTS="--silent"
        fi
        log "REQUEST  : $TMPDEST"
        log "EDITION  : $edition"

        # shellcheck disable=SC2086
        ret=$(curl -G "$UPDATE_URI" $CURL_OPTS \
            -u "${MAXMIND_ACCOUNT_ID}:${MAXMIND_LICENSE_KEY}" \
            -d "db_md5=$CURRENT_MD5" \
            --retry 3 \
            --retry-delay 3 \
            --write-out '%{http_code}' \
            --dump-header "${TMPDIR}/head-${edition}.txt" \
            --location \
            -o "$TMPDEST" )
        if [[ "$ret" == "304" ]]
        then
            # Pas besoin de mettre à jour
            log "$edition : already have the latest version"
            continue
        elif [[ "$ret" = "200" ]]
        then
            # uncompress file
            if ! gzip -d "$TMPDEST" > /dev/null
            then
                logerr "fail to gunzip $TMPDEST"
                exit 2
            fi
            TMPDEST="${TMPDIR}/${edition}.mmdb"
            # file downloaded in temp location, checking md5
            local EXPECTED_MD5
            local GOT_MD5
            EXPECTED_MD5=$(grep '^x-database-md5:' "${TMPDIR}/head-${edition}.txt" | tr -d '\r' | awk '{print tolower($2)}' )
            GOT_MD5=$(md5sum "$TMPDEST" | awk '{print tolower($1)}')
            if [ "$EXPECTED_MD5" = "$GOT_MD5" ]
            then
                cp -f "$TMPDEST" "$DEST_DIR/"
            else
                logerr "Checksums differs"
                logerr "    Expected MD5  : $EXPECTED_MD5"
                logerr "    File MD5      : $GOT_MD5"
                exit 6
            fi
        else
            # AH..
            logerr "Error when downloading $edition ; server return $ret HTTP Code."
            continue
        fi
    done
}

# -----------------------------------------------------------------------------
VERBOSE=${VERBOSE:-0}
MAXMIND_EDITIONS=('GeoLite2-ASN' 'GeoLite2-City' 'GeoLite2-Country')
MAXMIND_HOST=${MAXMIND_HOST:-"updates.maxmind.com"}
MAXMIND_DOWNLOAD_URI="https://${MAXMIND_HOST}/geoip/databases/%s/update"
DEST_DIR="${MAXMIND_DATADIR:-$LDIR}"

if [ -n "$1" ] && [ -f "$1" ]
then
    GEOIP_CONFIG_FILE="$1"
    if [ -n "$2" ] && [ -d "$2" ]
    then
        DEST_DIR="$2"
    fi
else
    if [ -n "$MAXMIND_CONFIG_FILE" ] && [ -f "$MAXMIND_CONFIG_FILE" ]
    then
        GEOIP_CONFIG_FILE="$MAXMIND_CONFIG_FILE"
    else
        GEOIP_CONFIG_FILE="/etc/GeoIP.conf"
    fi
fi

foundEditions
foundAccountID
foundLicenseKey

log "Updating MaxMind GeoIP DBs : "
log "    - Update URI               : $MAXMIND_DOWNLOAD_URI"
log "    - Try config file          : $GEOIP_CONFIG_FILE"
log "    - Editions                 : ${MAXMIND_EDITIONS[*]}"
log "    - Destination              : $DEST_DIR"
log "    - AccountID                : $MAXMIND_ACCOUNT_ID"
log "    - License Key              : $MAXMIND_LICENSE_KEY"

if [ -z "$DRYRUN" ] || [ "$DRYRUN" == "0" ]
then
    updateMaxmindDB
else
    log "DRYRUN is defined or not equal to 0. Exiting"
    exit 1
fi
