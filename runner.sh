#!/bin/bash

# Vars definition
ci_role=${PLUGIN_USE_CI_ROLE:-'ci'}
session_id="${DRONE_COMMIT_SHA:0:10}-${DRONE_BUILD_NUMBER}"
account_id=${PLUGIN_ACCOUNT:-'none'}

# Functions
function pdebug {
  if [ -n "${PLUGIN_DEBUG}" ] || [ -n "${debug}" ]; then
    echo "+ DEBUG: ${1}"
  fi
}

if [ "${account_id}" == "none" ]; then
  account_id="IAM Role"
fi

# Print authentication infos
echo "AWS credentials meta:"
echo "  CI Role: ${ci_role}"
echo "  Account ID: ${account_id}"
echo "  IAM Role Session ID: ${session_id}"

# Get authentified if a role is specified
if [ "${account_id}" != "IAM Role" ]; then
  iam_creds=$(aws sts assume-role --role-arn "arn:aws:iam::${account_id}:role/${ci_role}" --role-session-name "drone-${session_id}" --region=${PLUGIN_AWS_REGION:-'us-east-1'} | python -m json.tool)

  if [ -z "${iam_creds}" ]; then
    echo "ERROR: Unable to assume AWS role"
    exit 1
  fi

  export AWS_ACCESS_KEY_ID=$(echo "${iam_creds}" | grep AccessKeyId | tr -d '" ,' | cut -d ':' -f2)
  export AWS_SECRET_ACCESS_KEY=$(echo "${iam_creds}" | grep SecretAccessKey | tr -d '" ,' | cut -d ':' -f2)
  export AWS_SESSION_TOKEN=$(echo "${iam_creds}" | grep SessionToken | tr -d '" ,' | cut -d ':' -f2)
fi

# Retrieve some manual added variable from .drone.yml
if [ -n "${PLUGIN_VARIABLES}" ]; then
  echo "${PLUGIN_VARIABLES}" > build_variables.json
else
  echo "{}" > build_variables.json
fi

pdebug "Declared variables:"
pdebug "$(cat build_variables.json)"

# Getting the target to build
target="${PLUGIN_TARGET:-${target}}"
if [ "${target}" = "" ]; then
  echo "Missing required attribute target"
fi

echo "Build Target: ${target}"

# Add variable files from a given path
inclusions="--var-file build_variables.json"
if [ -n "${PLUGIN_INCLUDE_FILES}" ]; then
  for inc_name in ${PLUGIN_INCLUDE_FILES//,/ }; do
    inclusions="${inclusions} --var-file ${inc_name/<target>/${target}}"
  done
fi

# Add the secret variables read from the environment
include_vars=""
if [ -n "${PLUGIN_SECRET_VARIABLES}" ]; then
  for sec_var in ${PLUGIN_SECRET_VARIABLES//,/ }; do
    include_vars="${include_vars} --var ${sec_var}=$(printenv ${sec_var^^})"
  done
fi

# Builders blacklist
to_skip=""
if [ -n "${PLUGIN_EXCLUDE}" ]; then
  to_skip="--except ${PLUGIN_EXCLUDE}"
fi

# Builders whitelist
to_build=""
if [ -n "${PLUGIN_ONLY}" ]; then
  to_build="--only ${PLUGIN_ONLY}"
fi

# Set debugging mode
if [ -n "${PLUGIN_DEBUG}" ] || [ -n "${debug}" ]; then
  set -x
fi

# Check if it's a dry run
dryrun="${PLUGIN_DRY_RUN:-${dryrun}}"
if [ "${dryrun}" == "true" ]; then
  packer validate ${inclusions} ${to_skip} ${to_build} ${include_vars} "${target}"
else
  packer build ${inclusions} ${to_skip} ${to_build} ${include_vars} "${target}"
fi
