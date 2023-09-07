#!/bin/bash

# Required Linux utilities:
# * bash: Required to run the script
# * sed: Required for some string operations
# * sleep: Required for waiting for SSC to process results


######################################################################################################
###
### Generic utility functions
###
######################################################################################################

# Exit script, providing the following advantages over a regular 'exit':
#   - Doesn't exit shell if script is being sourced
#   - Script exits immediately even if _exit is called from a 
#     function running in a subshell, i.e. no need to do
#     $(getXXX a b c) || exit $?
_exit() {
	kill -INT $$
}

# Print a message to stderr
msg() { 
	cat <<< "$@" >&2; 
}

# Exit with an error code after printing an error message
# Usage: exitWithError <msg>
exitWithError() {
	logError "$@"
	_exit 1
}

# Log info message
# Usage: logInfo <msg>
logInfo() {
	msg "INFO: $@"
}

# Log warn message
# Usage: logWarn <msg>
logWarn() {
	msg "WARN: $@"
}

logError() {
	msg "ERROR: $@"
}

# Evaluate the given string, expanding any variables contained in the string
# Usage: expandedString=$(evalStringWithVars ${stringWithVars})
evalStringWithVars() {
	stringWithVars=$1
	echo $(source <(echo "echo \"${stringWithVars}\""))
}

# Get input value from (environment) variables,
# using both uppercase and lowercase lookup
# Usage: myVar=$(getVar <someVariableName> <defaultValue>)
getVar() {
	local name=$1
	local defaultValue=$2
	local nameUpper=${name^^}
	local nameLower=${name,,}
	
	echoFirstNotBlank \
		"${SCRIPT_VARS[$name]}" \
		"${SCRIPT_VARS[$nameUpper]}" \
		"${SCRIPT_VARS[$nameLower]}" \
		"${!name}" \
		"${!nameUpper}" \
		"${!nameLower}" \
		"$defaultValue"
}

printScriptVars() {
	logInfo "Script configuration:"
	readarray -t sortedScriptVars < <(printf '%s\n' "${!SCRIPT_VARS[@]}" | sort)
	for var in "${sortedScriptVars[@]}"
	do
		local value=${SCRIPT_VARS[${var}]}
		if isNotBlank "${value}"; then
			[[ " ${SENSITIVE_SCRIPT_VARS[@]} " =~ " ${var} " ]] && value="****"
			msg "  ${var}: ${value}"
		fi
	done
}

# Get required input value from (environment) variables,
# using both uppercase and lowercase lookup
# Usage: myVar=$(getReqVar <someVariableName> [messageIfNotDefined])
getReqVar() {
	local name=$1
	local msgIfNotDefined=$2
	local result=$(getVar $name "")
	if isNotBlank "${result}"; then
		echo "${result}"
	else 
		local msg=${msgIfNotDefined}
		if [[ -z ${msg} ]]; then
			msg="Required variable ${name} not defined"
		fi
		exitWithUsage "${msg}"
	fi
}

# Echo first non-blank parameter value
# Usage: echoFirstNotBlank "${someVar}" "${someOtherVar}" "${someThirdVar}"
echoFirstNotBlank() {
	for value in "$@"
	do
		[ -n "${value}" ] && echo "${value}" && break
	done
}

# Check whether the given value equals either 'true' (case-insensitive) or '1'
# Usage: isTrue <value>
isTrue() {
	value=$1
	[[ "${value,,}" == "true" || "${value}" == "1" ]]
}

# Check whether the value for the given variable name equals either 'true' (case-insensitive) or '1'
# Usage: isVarTrue <variableName>
isVarTrue() {
	var=$1
	isTrue $(getVar $var)
}

# Check whether the given value is not blank
# Usage: isNotBlank <value>
isNotBlank() {
	value=$1
	[[ ! -z "${value}" ]]
}

# Check whether the value for the given variable name is not blank
# Usage: isVarNotBlank <variableName>
isVarNotBlank() {
	var=$1
	isNotBlank $(getVar $var)
}

# Check whether the given value is blank
# Usage: isBlank <value>
isBlank() {
	value=$1
	[[ -z "${value}" ]]
}

# Check whether the value for the given variable name is blank
# Usage: isVarBlank <variableName>
isVarBlank() {
	var=$1
	isBlank $(getVar $var)
}

# Echo one of two values depending on whether the given variable is blank or not
# Usage: ifVarNotBlankElse <variableName> <valueIfNotBlank> <valueIfBlank>
ifVarNotBlankElse() {
	var=$1
	valueIfNotBlank=$2
	valueIfBlank=$3
	if isVarNotBlank ${var}; then
		echo "${valueIfNotBlank}"
	else
		echo "${valueIfBlank}"
	fi
}

# Echo one of two values depending on whether the given variable is true or not
# Usage: ifVarTrueElse <variableName> <valueIfTrue> <valueIfNotTrue>
ifVarTrueElse() {
	var=$1
	valueIfTrue=$2
	valueIfNotTrue=$3
	if isVarTrue ${var}; then
		echo "${valueIfTrue}"
	else
		echo "${valueIfNotTrue}"
	fi
}


######################################################################################################
###
### Script logic
###
######################################################################################################

# Print an error message followed by usage instructions, then exit the script
# Usage: exitWithUsage "<error message>"
exitWithUsage() {
	msg "ERROR: $@"
	msg ""
	usage
	_exit 1
}

# Print usage instructions
usage() {
	msg "This utility can be used to start a SAST scan on either FoD or ScanCentral SAST, and optionally export"
	msg "vulnerability data to 3rd-party report formats."
	msg ""
	msg "Usage:"
	msg "  [options] sast-scan.sh"
	msg ""
	msg "[options] is a set of variable definitions. Variables must be specified in either lower case or uppercase"
	msg "case; mixed case variables will not be recognized. Instead of prefixing the command with variable definitions,"
	msg "variables can also be defined through other means, for example using 'export' commands, or passed as CI/CD"
	msg "or Docker variables. All options listed below are optional unless specified otherwise."
	msg ""
	msg "General Options:"
	msg "  WORK_DIR=<dir>"
	msg "    Specify the working directory for this script. Usually this should be set to your workspace directory."
	msg ""
	msg "Control Options:"
	msg "  DO_PACKAGE=true|false"
	msg "    Packaging is enabled by default, but can be disabled if a package has been generated through other"
	msg "    means, or if you're not actually starting a scan (see DO_SCAN below)."
	msg "  DO_SCAN=true|false"
	msg "    Running a scan is enabled by default, but can be disabled. Setting this to false usually only makes"
	msg "    sense if you want to test packaging and/or export steps without actually running a scan."
	msg "  DO_EXPORT=true|false"
	msg "    Exporting is enabled by default if EXPORT_TARGET has been defined (see below). Setting this to false"
	msg "    allows for skipping the export even though an export target has been defined."
	msg "  DO_BLOCK=true|false"
	msg "    Block until scan completion is disabled by default, unless exporting has been enabled (in which case"
	msg "    blocking cannot be disabled). Setting this option to true allows for enabling blocking until scan"
	msg "    completion, for example allowing to process scan results through some other means, when exporting"
	msg "    hasn't been enabled."
	msg ""
	msg "Packaging Options:"
	msg "  PACKAGE_NAME=/path/to/package.zip"
	msg "    Specify the file containing the scan payload. The packaging process will write the scan payload to"
	msg "    this file, and the scanning process will read the scan payload from this file. Defaults to package.zip"
	msg "    in the current working directory."
	msg "  PACKAGE_OPTS=<ScanCentral Client packaging options>"
	msg "    Specify packaging options that will be passed to the scancentral command. See the ScanCentral documentation"
	msg "    for more information about packaging options. As an example, you can use this option to specify '-bt mvn'"
	msg "    or '-bt gradle'. This option doesn't have a default value, and is required if DO_PACKAGE hasn't been set to"
	msg "    false."
	msg ""
	msg "Export Options:"
	msg "  EXPORT_TARGET=<Target supported by FortifyVulnerabilityExporter>"
	msg "    Specify the target for vulnerability data export. This will be used to generate the configuration file name"
	msg "    passed to FortifyVulnerabilityExporter, in the format SSCTo<ExportTarget> or FoDTo<ExportTarget>. As an"
	msg "    example, if EXPORT_TARGET has been set to GitLabSAST and an FoD scan is being run, FortifyVulnerabilityExporter"
	msg "    will be invoked with the FoDToGitLabSAST configuration. See the FortifyVulnerabilityExporter documentation"
	msg "    (or the list of configuration files shipped with FortifyVulnerabilityExporter) for an overview of available"
	msg "    export targets. Some examples: BitBucket, GitHub, GitLab, GitLabSAST, SonarQube."
	msg ""
	msg "FoD Options:"
	msg "  FOD_URL=<FoD portal URL>"
	msg "    Specify the FoD portal URL, for example https://ams.fortify.com. Required for running scans on, and"
	msg "    exporting vulnerability data from FoD."
	msg "  FOD_API_URL=<FoD API URL>"
	msg "    This script automatically determines the API URL based on FOD_URL, but can be overridden if necessary."
	msg "  FOD_TENANT=<FoD tenant>"
	msg "    Specify the FoD tenant. Required for running scans on, and exporting vulnerability data from FoD."
	msg "  FOD_USER=<FoD user> | FOD_USERNAME=<FoD user>"
	msg "    Specify the FoD user name. Required when connecting to FoD using user credentials."
	msg "  FOD_PASSWORD=<FoD password> | FOD_PAT=<FoD PAT>"
	msg "    Specify the FoD password or PAT. Required when connecting to FoD using user credentials."
	msg "  FOD_CLIENT_ID=<FoD client id>"
	msg "    Specify the FoD client id. Required when connecting to FoD using client/API credentials."
	msg "  FOD_CLIENT_SECRET=<FoD client secret>"
	msg "    Specify the FoD client secret. Required when connecting to FoD using client/API credentials."
	msg "  FOD_RELEASE_ID=<FoD release id>"
	msg "    Specify the FoD release id. Required for running scans on, and exporting vulnerability data from FoD."
	msg "  FOD_NOTES=<FoD scan notes>"
	msg "    Specify optional scan notes to be passed to FoD."
	msg "  FOD_UPLOAD_OPTS=<FoD upload options>"
	msg "    Specify any additional options for FoDUploader; see FoDUploader documentation for a list of available"
	msg "    upload options. FoDUploader requires at least the '-ep' option to be passed. Note that any relevant FoD"
	msg "    options listed above are automatically passed to FoDUploader. In addition, the following options are"
	msg "    automatically passed to FoDUploader under certain conditions:"
	msg "      '-I 1': passed if DO_BLOCK or DO_EXPORT are set to true"
	msg "      '-apf': passed if DO_EXPORT is set to true"
	msg ""
	msg "On-premises Options:"
	msg "  SSC_URL=<SSC URL>"
	msg "    Specify the SSC base URL, for example https://my.ssc.host/ssc. Required for running scans on ScanCentral"
	msg "    SAST, and for exporting vulnerability data from SSC."
	msg "  SSC_CI_TOKEN=<SSC CIToken>"
	msg "    Specify the SSC CIToken used for authenticating with SSC. Required for running scans on ScanCentral SAST,"
	msg "    and for exporting vulnerability data from SSC."
	msg "  SSC_VERSION_ID=<SSC application version id>"
	msg "    Specify the SSC application version id. Required for running scans on ScanCentral SAST, and for exporting"
	msg "    vulnerability data from SSC."
	msg "  SSC_PROCESSING_WAIT_TIME=<number><s|m|h>"
	msg "    Specify number of seconds (s), minutes (m) or hours (h) to wait after ScanCentral has completed the scan,"
	msg "    in order to allow for SSC to finish processing the scan results. At the moment, this script nor any of the"
	msg "    standard Fortify CLI tools provide functionality to poll SSC for processing completion, or to check whether"
	msg "    an artifact has been processed successfully. As a result, for now this script only supports a static wait"
	msg "    time. This setting is only applicable if blocking is enabled (see DO_BLOCK). Default value is 5m."
	msg "  SCANCENTRAL_AUTH_TOKEN=<ScanCentral Client auth token>"
	msg "    Specify the client auth token to be used for accessing the ScanCentral Controller."
	msg "  SCANCENTRAL_OPTS=<ScanCentral options>"
	msg "    Specify any additional options for the 'scancentral start' command; see ScanCentral documentation for a"
	msg "    list of available options. Note that any relevant SSC options listed above are automatically passed to"
	msg "    the 'scancentral start' command. In addition, the following options are automatically passed to the"
	msg "    'scancentral start' command under certain conditions:"
	msg "      '-block': passed if DO_BLOCK or DO_EXPORT are set to true"
	
}

# Main function for running this script
# Usage: run
run() {
	local args="$@"
	# This associative array may be used to store variables shared between various functions
	declare -A SCRIPT_VARS
	# This array may be used to store variable names that contain sensitive information
	declare -a SENSITIVE_SCRIPT_VARS
	
	if [[ "$1" == "--help" || "$1" == "-h" ]]; then
		usage
	else
		defineGlobalVars
		if isVarNotBlank FOD_URL; then
			pushd $(getReqVar WORK_DIR) && runFoDScan
			popd > /dev/null
		elif isVarNotBlank SSC_URL; then
			pushd $(getReqVar WORK_DIR) && runOnPremScan
			popd > /dev/null
		else
			exitWithUsage "Either FoD or SSC connection details are required"
		fi
	fi
}

defineGlobalVars() {
	# This option allows for specifying the working directory.
	SCRIPT_VARS[WORK_DIR]=$(getVar WORK_DIR $(pwd))
	# This option allows for skipping packaging, for example if scan payload has been generated in some other way
	SCRIPT_VARS[DO_PACKAGE]=$(getVar DO_PACKAGE "true")
	# This option allows for skipping the actual scan, useful for testing the other steps
	SCRIPT_VARS[DO_SCAN]=$(getVar DO_SCAN "true")
	# Define packaging options
	SCRIPT_VARS[PACKAGE_OPTS]=$(isVarTrue DO_PACKAGE && getReqVar PACKAGE_OPTS)
	# Define name and location of scan payload package
	SCRIPT_VARS[PACKAGE_NAME]=$(getVar PACKAGE_NAME "$(getReqVar WORK_DIR)/package.zip")
	# Define export target. Can be defined/overridden using EXPORT_TARGET variable. Default is set based on
	# what environment we are running in.
	SCRIPT_VARS[EXPORT_TARGET]=$(getVar EXPORT_TARGET)
	# Define whether to export vulnerability data or not. Can be defined/overridden using DO_EXPORT variable.
	# Export is enabled by default if EXPORT_TARGET is defined.
	SCRIPT_VARS[DO_EXPORT]=$(getVar DO_EXPORT $(ifVarNotBlankElse EXPORT_TARGET "true" "false"))
	# Define whether we should block until scan completion. Can be defined/overridden using DO_BLOCK variable.
	# We always block if DO_EXPORT is set to true, otherwise we only block if DO_BLOCK variable is set to true
	SCRIPT_VARS[DO_BLOCK]=$(ifVarTrueElse DO_EXPORT "true" $(getVar DO_BLOCK "false"))
}

runFoDScan() {
	defineFoDVars
	printScriptVars
	packageScanPayload
	scanPackageWithFoD
	exportFoDVulnData
}

defineFoDVars() {
	SENSITIVE_SCRIPT_VARS+=("FOD_PASSWORD" "FOD_CLIENT_SECRET" "FOD_UPLOAD_AUTH_OPTS" "FOD_EXPORT_AUTH_OPTS")
	SCRIPT_VARS[FOD_URL]=$(getReqVar FOD_URL)
	SCRIPT_VARS[FOD_API_URL]=$(getVar FOD_API_URL "$(getReqVar FOD_URL | sed -E -e 's_(.*://)([^/@]*@)?([^/:]+).*_\1api.\3_')")
	SCRIPT_VARS[FOD_TENANT]=$(getReqVar FOD_TENANT)
	SCRIPT_VARS[FOD_USER]=$(getVar FOD_USER "$(getVar FOD_USERNAME)")
	SCRIPT_VARS[FOD_PASSWORD]=$(getVar FOD_PASSWORD "$(getVar FOD_PAT)")
	SCRIPT_VARS[FOD_CLIENT_ID]=$(getVar FOD_CLIENT_ID)
	SCRIPT_VARS[FOD_CLIENT_SECRET]=$(getVar FOD_CLIENT_SECRET)
	SCRIPT_VARS[FOD_RELEASE_ID]=$(getReqVar FOD_RELEASE_ID)
	SCRIPT_VARS[FOD_UPLOAD_OPTS]=$(getVar FOD_UPLOAD_OPTS "$(getVar FOD_UPLOADER_OPTS)")
	SCRIPT_VARS[FOD_NOTES]=$(getVar FOD_NOTES "")
	
	if isVarBlank FOD_USER && isVarBlank FOD_CLIENT_ID; then
		exitWithUsage "Either FoD username & password, or client id & secret must be specified"
	elif isVarNotBlank FOD_USER && isVarBlank FOD_PASSWORD; then
		exitWithUsage "FoD password or PAT must be specified when using user credentials"
	elif isVarNotBlank FOD_CLIENT_ID && isVarBlank FOD_CLIENT_SECRET; then
		exitWithUsage "FoD client secret must be specified when using client credentials"
	fi
	SCRIPT_VARS[FOD_UPLOAD_AUTH_OPTS]=$(ifVarNotBlankElse FOD_USER \
		"-uc \"$(getVar FOD_USER)\" \"$(getVar FOD_PASSWORD)\"" \
		"-ac \"$(getVar FOD_CLIENT_ID)\" \"$(getVar FOD_CLIENT_SECRET)\"")
	SCRIPT_VARS[FOD_EXPORT_AUTH_OPTS]=$(ifVarNotBlankElse FOD_USER \
		"--fod.userName=$(getVar FOD_USER) --fod.password=$(getVar FOD_PASSWORD)" \
		"--fod.client.id=$(getVar FOD_CLIENT_ID) --fod.client.secret=$(getVar FOD_CLIENT_SECRET)")
	
	if isVarTrue DO_BLOCK; then
		SCRIPT_VARS[FOD_UPLOAD_OPTS]+=" -I 1"
	fi
	if isVarTrue DO_EXPORT; then
		SCRIPT_VARS[FOD_UPLOAD_OPTS]+=" -apf"
	fi
}

scanPackageWithFoD() {
	if isVarTrue DO_SCAN; then
		logInfo "Starting FoD SAST scan"
		FoDUpload -z $(getVar PACKAGE_NAME) -aurl $(getVar FOD_API_URL) -purl $(getVar FOD_URL) \
				-rid $(getVar FOD_RELEASE_ID) -tc $(getVar FOD_TENANT) $(getVar FOD_UPLOAD_AUTH_OPTS) \
				$(getVar FOD_UPLOAD_OPTS) -n "$(getVar FOD_NOTES)" \
				|| exitWithError "Error uploading scan payload to FoD"
	else
		logInfo "Skipping FoD SAST scan"
	fi
}

exportFoDVulnData() {
	exportVulnData "FoD" --fod.baseUrl=$(getVar FOD_URL) --fod.tenant=$(getVar FOD_TENANT) $(getVar FOD_EXPORT_AUTH_OPTS) --fod.release.id=$(getVar FOD_RELEASE_ID)
}

runOnPremScan() {
	defineOnPremVars
	printScriptVars
	packageScanPayload
	scanPackageWithScanCentral
	exportSSCVulnData
}

defineOnPremVars() {
	SENSITIVE_SCRIPT_VARS+=("SSC_CI_TOKEN")
	SCRIPT_VARS[SSC_URL]=$(getReqVar SSC_URL)
	SCRIPT_VARS[SSC_CI_TOKEN]=$(getReqVar SSC_CI_TOKEN)
	SCRIPT_VARS[SSC_VERSION_ID]=$(getReqVar SSC_VERSION_ID)
	SCRIPT_VARS[SSC_PROCESSING_WAIT_TIME]=$(getVar SSC_PROCESSING_WAIT_TIME "5m")
	SCRIPT_VARS[SCANCENTRAL_AUTH_TOKEN]=$(getVar SCANCENTRAL_OPTS)
	SCRIPT_VARS[SCANCENTRAL_OPTS]=$(getVar SCANCENTRAL_OPTS)
	if isVarTrue DO_BLOCK; then
		SCRIPT_VARS[SCANCENTRAL_OPTS]+=" -block"
	fi
}

scanPackageWithScanCentral() {
	if isVarTrue DO_SCAN; then
		logInfo "Starting ScanCentral SAST scan"
		if isVarNotBlank SCANCENTRAL_AUTH_TOKEN; then
			echo "client_auth_token=$(getVar SCANCENTRAL_AUTH_TOKEN)" > /opt/Fortify/ScanCentral/Core/config/client.properties
		fi
		scancentral -sscurl $(getVar SSC_URL) -ssctoken $(getVar SSC_CI_TOKEN) start -p $(getVar PACKAGE_NAME) -upload -uptoken $(getVar SSC_CI_TOKEN) -versionid $(getVar SSC_VERSION_ID) $(getVar SCANCENTRAL_OPTS)
		if isVarTrue DO_BLOCK; then
			logInfo "Waiting $(getVar SSC_PROCESSING_WAIT_TIME) to allow for SSC processing"
			sleep $(getVar SSC_PROCESSING_WAIT_TIME)
		fi
	else
		logInfo "Skipping ScanCentral SAST scan"
	fi 
}

exportSSCVulnData() {
	exportVulnData "SSC" --ssc.baseUrl=$(getVar SSC_URL) --ssc.authToken=$(getVar SSC_CI_TOKEN) --ssc.version.id=$(getVar SSC_VERSION_ID)
}

packageScanPayload() {
	if isVarTrue DO_PACKAGE; then
		logInfo "Packaging scan payload"
		scancentral package $(getVar PACKAGE_OPTS) -o $(getVar PACKAGE_NAME) || exitWithError "Error packaging scan payload"
	else
		logInfo "Skipping packaging"
	fi
}

exportVulnData() {
	sourceSystem=$1; shift;
	if isVarTrue DO_EXPORT; then
		logInfo "Exporting ${sourceSystem} vulnerability data to $(getVar EXPORT_TARGET)"
		FortifyVulnerabilityExporter "${sourceSystem}To$(getVar EXPORT_TARGET)" "$@"
	else
		logInfo "Skipping ${sourceSystem} vulnerability data export"
	fi
}

run "$@"
