#!/bin/bash
################################################################################################
#
# Script Name : set-hostname-from-jamf-id.sh
# Author      : Janeesh Jaleel
# Created     : 29 October 2026
# Version     : 2.0.0 (October 2026)
#
# Description :
#   Sets the macOS ComputerName, HostName and LocalHostName using a prefix followed by
#   the device's Jamf Pro computer ID, then submits updated inventory to Jamf Pro.
#
#   Example: prefix "MDS-DXB-", minimum digits 2
#            Computer ID 7    -> MDS-DXB-07
#            Computer ID 1234 -> MDS-DXB-1234   (IDs are never truncated)
#
#   Tip: end the prefix with a hyphen (MDS-DXB-) to separate it from the number.
#
# Jamf Pro Script Parameters:
#   Parameter 4 : Hostname prefix           (required)  e.g. MDS-DXB-
#   Parameter 5 : Minimum number of digits  (optional)  e.g. 2   Default: 2
#
# Exit Codes:
#   0 : Success, or the hostname was already correct
#   1 : Script was not run as root
#   2 : Invalid or missing script parameter
#   3 : Jamf binary not found
#   4 : Inventory update failed or the computer ID could not be determined
#   5 : Failed to set one or more name settings
#   6 : Names were changed but the final inventory update failed
#
################################################################################################
## DISCLAIMER
################################################################################################
## This script is provided "AS IS" without warranty of any kind, express or implied,
## including but not limited to the warranties of merchantability, fitness for a
## particular purpose, and noninfringement. The authors and distributors of this script
## make no guarantees regarding its suitability, reliability, availability, or
## performance. While the script has been tested in various scenarios, no assurance is
## given that it will cover all use cases or operate error-free in every environment.
##
## By using this script, you acknowledge and agree that you do so at your own risk.
## In no event shall the authors, contributors, or associated organisations be held
## liable for any damages, including but not limited to direct, indirect, incidental,
## consequential, or special damages, or loss of data, profits, or business, arising
## from the use of or inability to use this script, even if advised of the possibility
## of such damages.
##
##          If you do not agree to these terms, please do not use this script.
################################################################################################

################################################################################################
# Constants
################################################################################################

readonly SCRIPT_VERSION="2.0.0"
readonly JAMF_BINARY="/usr/local/bin/jamf"
readonly SCUTIL="/usr/sbin/scutil"
readonly DEFAULT_DIGITS=2
readonly MAX_DIGITS=10
readonly MAX_HOSTNAME_LENGTH=63      # macOS LocalHostName limit
readonly NAME_TYPES=(ComputerName HostName LocalHostName)

################################################################################################
# Script Parameters (passed by Jamf Pro; $1-$3 are reserved by Jamf)
################################################################################################

hostnamePrefix="${4:-}"
minDigits="${5:-}"

################################################################################################
# Functions
################################################################################################

# Write a timestamped log line. Usage: log LEVEL "message"
log() {
    local level="$1"
    shift
    printf '[%s] [%-5s] %s\n' "$(/bin/date '+%Y-%m-%d %H:%M:%S')" "$level" "$*"
}

logInfo()  { log "INFO"  "$@"; }
logWarn()  { log "WARN"  "$@"; }
logError() { log "ERROR" "$@"; }

# Log an error and exit with the given code. Usage: die CODE "message"
die() {
    local exitCode="$1"
    shift
    logError "$*"
    logInfo "Script finished with exit code ${exitCode}."
    exit "$exitCode"
}

# Remove leading and trailing whitespace from a string.
trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

# Confirm the script is running with root privileges.
checkRoot() {
    if [[ "$EUID" -ne 0 ]]; then
        die 1 "This script must be run as root."
    fi
}

# Validate and normalise Parameter 4 (prefix) and Parameter 5 (minimum digits).
validateParameters() {
    hostnamePrefix="$(trim "$hostnamePrefix")"
    minDigits="$(trim "$minDigits")"

    # Parameter 4: hostname prefix
    if [[ -z "$hostnamePrefix" ]]; then
        die 2 "Parameter 4 (hostname prefix) is required but was not provided."
    fi
    if [[ ! "$hostnamePrefix" =~ ^[A-Za-z0-9-]+$ ]]; then
        die 2 "Parameter 4 (hostname prefix) '${hostnamePrefix}' is invalid. Use only letters, numbers and hyphens."
    fi
    if [[ "$hostnamePrefix" == -* ]]; then
        die 2 "Parameter 4 (hostname prefix) must not start with a hyphen."
    fi

    # Parameter 5: minimum number of digits
    if [[ -z "$minDigits" ]]; then
        minDigits="$DEFAULT_DIGITS"
        logInfo "Parameter 5 (minimum digits) not provided; using default of ${DEFAULT_DIGITS}."
    fi
    if [[ ! "$minDigits" =~ ^[0-9]+$ ]]; then
        die 2 "Parameter 5 (minimum digits) '${minDigits}' is invalid. It must be a whole number."
    fi
    minDigits=$((10#$minDigits))
    if (( minDigits < 1 || minDigits > MAX_DIGITS )); then
        die 2 "Parameter 5 (minimum digits) must be between 1 and ${MAX_DIGITS}."
    fi

    logInfo "Hostname prefix: ${hostnamePrefix}"
    logInfo "Minimum digits:  ${minDigits}"
}

# Confirm the Jamf binary is present and executable.
checkJamfBinary() {
    if [[ ! -x "$JAMF_BINARY" ]]; then
        die 3 "Jamf binary not found or not executable at ${JAMF_BINARY}."
    fi
}

# Run an inventory update and extract the Jamf Pro computer ID into $computerId.
getComputerId() {
    local reconOutput rawId

    logInfo "Running inventory update to obtain the Jamf Pro computer ID..."
    if ! reconOutput="$("$JAMF_BINARY" recon 2>&1)"; then
        die 4 "Jamf inventory update failed. The hostname was not changed."
    fi

    rawId="$(printf '%s\n' "$reconOutput" \
        | /usr/bin/sed -n 's/.*<computer_id>[[:space:]]*\([0-9][0-9]*\)[[:space:]]*<\/computer_id>.*/\1/p')"

    # Exactly one numeric ID must be present (multiple matches produce multiple lines).
    if [[ ! "$rawId" =~ ^[0-9]+$ ]]; then
        die 4 "Could not extract a single numeric Jamf Pro computer ID. The hostname was not changed."
    fi
    if (( ${#rawId} > 18 )); then
        die 4 "Jamf Pro computer ID '${rawId}' is unexpectedly long. The hostname was not changed."
    fi

    # Force base-10 so leading zeros are removed and not treated as octal.
    computerId=$((10#$rawId))
    if (( computerId == 0 )); then
        die 4 "Jamf Pro computer ID must be greater than zero. The hostname was not changed."
    fi

    logInfo "Jamf Pro computer ID: ${computerId}"
}

# Build the new hostname into $newHostname from the prefix and padded computer ID.
buildHostname() {
    local formattedId

    printf -v formattedId '%0*d' "$minDigits" "$computerId"
    newHostname="${hostnamePrefix}${formattedId}"

    if (( ${#newHostname} > MAX_HOSTNAME_LENGTH )); then
        die 2 "Hostname '${newHostname}' exceeds ${MAX_HOSTNAME_LENGTH} characters. Use a shorter prefix."
    fi

    logInfo "Target hostname: ${newHostname}"
}

# Set each macOS name setting that does not already match. Sets $namesChanged.
setHostnames() {
    local nameType currentValue

    namesChanged=false
    for nameType in "${NAME_TYPES[@]}"; do
        currentValue="$("$SCUTIL" --get "$nameType" 2>/dev/null)"

        if [[ "$currentValue" == "$newHostname" ]]; then
            logInfo "${nameType} is already set to ${newHostname}; no change needed."
            continue
        fi

        if ! "$SCUTIL" --set "$nameType" "$newHostname"; then
            die 5 "Failed to set ${nameType}. Name settings changed earlier in this run remain changed."
        fi

        logInfo "${nameType} changed from '${currentValue:-<not set>}' to '${newHostname}'."
        namesChanged=true
    done
}

# Submit the updated name to Jamf Pro.
updateInventory() {
    logInfo "Submitting updated inventory to Jamf Pro..."
    if ! "$JAMF_BINARY" recon >/dev/null 2>&1; then
        die 6 "Name settings were changed locally, but the final Jamf inventory update failed."
    fi
    logInfo "Inventory update completed."
}

################################################################################################
# Main
################################################################################################

main() {
    logInfo "===== Set Hostname from Jamf Computer ID v${SCRIPT_VERSION} - started ====="

    checkRoot
    validateParameters
    checkJamfBinary
    getComputerId
    buildHostname
    setHostnames

    if [[ "$namesChanged" == true ]]; then
        updateInventory
    else
        logInfo "All name settings were already correct; skipping the final inventory update."
    fi

    logInfo "===== Completed successfully. Hostname: ${newHostname} ====="
    exit 0
}

main
