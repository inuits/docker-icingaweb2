#!/bin/bash
# Icinga Web 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+
set -exo pipefail

usage() {
	cat >&2 <<EOF
Usage: get-mods.sh <release|snapshot>

  release:  download the latest release version of all external modules
  snapshot: download a snapshot/development version of all external modules
EOF
	exit 1
}

get_first_line() {
  head -n 1
  cat >/dev/null
}

# Tags sorted by version (newest first), limited to those created at or before $MODULES_AS_OF (if set)
get_tags () {
	git -C dockerweb2-temp for-each-ref --sort=-version:refname --format='%(creatordate:unix) %(refname:short)' refs/tags \
		|awk -v asof="$MODULES_AS_OF" 'asof == "" || $1 <= asof { print $2 }'
}

get_tag () {
	local TAGS
	TAGS="$(get_tags)"

	if [ -z "$TAGS" ]; then
		return 0
	fi

	if grep -vFe - <<<"$TAGS" >/dev/null; then # ex. RCs
		grep -vFe - <<<"$TAGS" |get_first_line
	else
		grep -Fe - <<<"$TAGS" |get_first_line
	fi
}

# Latest commit of branch $1 at or before $MODULES_AS_OF (if set)
get_commit () {
	if [ -n "$MODULES_AS_OF" ]; then
		git -C dockerweb2-temp rev-list -1 --before="@$MODULES_AS_OF" "$1"
	else
		echo "$1"
	fi
}

get_special () {
	if [ ! -e "$2" ]; then
		rm -rf dockerweb2-temp
		git clone --bare "https://github.com/Icinga/${1}.git" dockerweb2-temp

		case "$MODE" in
			release)
				REF="$(get_tag)"
				;;
			snapshot)
				case "$2" in
					icingaweb2/modules/incubator)
						# "HINT: Do NOT install the GIT master, it will not work!"
						# https://github.com/Icinga/icingaweb2-module-incubator/blob/master/README.md
						REF="$(get_tag)"
						;;
					icinga-php/*)
						# Special branch that contains vendored dependencies missing in HEAD
						REF="$(get_commit snapshot/nightly)"
						;;
					*)
						REF="$(get_commit HEAD)"
						;;
				esac
				;;
		esac

		if [ -z "$REF" ]; then
			echo "No version of ${1} at or before ${MODULES_AS_OF}, skipping" >&2
			echo "${1} skipped" >>"$BUILD_INFO"
			rm -rf dockerweb2-temp
			return 0
		fi

		echo "${1} ${REF} $(git -C dockerweb2-temp rev-parse "${REF}^{commit}")" >>"$BUILD_INFO"
		git -C dockerweb2-temp archive "--prefix=${2}/" "$REF" |tar -x
		rm -rf dockerweb2-temp
	fi
}

get_lib () {
	get_special "icinga-php-$1" "icinga-php/$2"
}

get_altname () {
	get_special "$1" "icingaweb2/modules/$2"
}

get_mod () {
	get_altname "icingaweb2-module-$1" "$1"
}

MODE="$1"
case "$MODE" in
	release|snapshot) ;;
	*) usage ;;
esac

# Unix timestamp; when set, use the latest versions available at that moment instead of the latest overall
MODULES_AS_OF="${MODULES_AS_OF:-}"
case "$MODULES_AS_OF" in
	'') ;;
	*[!0-9]*) echo "MODULES_AS_OF must be a unix timestamp, got: ${MODULES_AS_OF}" >&2; exit 1 ;;
esac

BUILD_INFO="$(pwd)/icingaweb2-build-info.txt"
echo "mode=${MODE} modules_as_of=${MODULES_AS_OF:-latest}" >"$BUILD_INFO"

get_lib library ipl
get_lib thirdparty vendor
get_mod audit
get_mod aws
get_mod businessprocess
get_mod cube
get_mod director
get_mod fileshipper
get_mod graphite
get_altname icingadb-web icingadb
get_mod idoreports
get_mod incubator
get_mod monitoring
get_altname icinga-kubernetes-web kubernetes
get_special L10n icinga-L10n
get_altname icinga-notifications-web notifications
get_mod pdfexport
get_mod reporting
get_altname icinga-sso-web sso
get_mod vspheredb
get_mod x509
