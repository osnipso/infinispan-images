#!/bin/sh
# ===================================================================================
# Entry point for the image which initiates any pre-launch config required before
# executing the server.
# ===================================================================================

printLn() {
  format='# %-76s #\n'
  printf "$format" "$1"
}

printBorder() {
  printf '#%.0s' {1..80}
  printf "\n"
}

generate_user_or_password() {
  echo $(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
}

generate_identities_yaml() {
  # If no identities file provided, then use provided user/pass or generate as required
  if [ -z ${IDENTITIES_PATH} ]; then
    printBorder
    printLn
    printLn "IDENTITIES_PATH not specified"
    if [ -n "${USER}" ] && [ -n "${PASS}" ]; then
      printLn "Generating Identities yaml using USER and PASS env vars."
    else
      USER=$(generate_user_or_password)
      PASS=$(generate_user_or_password)
      printLn "USER and/or PASS env variables not specified."
      printLn "Auto generating user and password."
      printLn
      printLn "Generated User: ${USER}"
      printLn "Generated Password: ${PASS}"
      printLn
      printLn "These credentials should be passed via environment variables when adding"
      printLn "new nodes to the cluster to ensure that clients can access the exposed"
      printLn "endpoints, on all nodes, using the same credentials."
      printLn
      printLn "For example:"
      printLn "    'docker run -e USER=${USER} -e PASS=${PASS}''"
      printLn
    fi
    printBorder

identities=$(cat <<-YamlEnd
credentials:
  - username: ${USER}
    password: ${PASS}
    roles:
      - admin
YamlEnd
)
    export IDENTITIES_PATH=${ISPN_HOME}/server/conf/generated-identities.yaml
    echo "${identities}" > ${IDENTITIES_PATH}
  fi
}

generate_content() {
  if [ "${MANAGED_ENV^^}" != "TRUE" ]; then
    generate_identities_yaml
  fi
}

# ===================================================================================
# Script Execution
# ===================================================================================

set -e
if [ -n "${DEBUG}" ]; then
  set -x
fi

# Set the umask otherwise created files are not-writable by the group
umask 0002

generate_content

[[ -n ${ADMIN_IDENTITIES_PATH} ]] && ADMIN_IDENTITES_OPT="--admin-identities=${ADMIN_IDENTITIES_PATH}"
[[ -n ${IDENTITIES_PATH} ]] && IDENTITES_OPT="--identities=${IDENTITIES_PATH}"
[[ -n ${CONFIG_PATH} ]] && CONFIG_OPT="--config=${CONFIG_PATH}"

CONFIG_GENERATOR="${ISPN_HOME}/bin/config-generator"
CONFIG_GENERATOR_ARGS="${ADMIN_IDENTITES_OPT} ${IDENTITES_OPT} ${CONFIG_OPT} ${ISPN_HOME}/server/conf"

# If *.jar, java otherwise native
if [[ -f "${CONFIG_GENERATOR}.jar" ]]; then
  java -jar ${ISPN_HOME}/bin/config-generator.jar $CONFIG_GENERATOR_ARGS
else
  bin/config-generator $CONFIG_GENERATOR_ARGS
fi

if [ -n "${DEBUG}" ]; then
  cat ${ISPN_HOME}/server/conf/*.xml
fi

exec ${ISPN_HOME}/bin/server.sh
