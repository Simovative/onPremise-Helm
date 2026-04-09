#!/usr/bin/env bash
#
# Erstellt VHosts, Users, Permissions, Exchanges, Queues und Bindings
# entsprechend der definition.json.
#
# ➜  Vor Benutzung: URL der RabbitMQ-Management-API anpassen.
#     Beispiel für AWS MQ: https://b-<id>.mq.eu-central-1.on.aws
# ➜  Standard-Port lokal: http://localhost:15672
#
# Aufruf-Beispiel:
#   ./setup_rabbitmq.sh
#

set -uo pipefail
set -o nounset

function errcho() {
  (>&2 echo "[ FAIL ] $*" )
}

function errxit() {
  errcho "$@"
  exit 1
}

function script_usage() {
    cat << EOF
Usage:
     -h|--help                     Displays this help
     -tid|--tenantid               Tenant ID
     -mqa|--rabbitmq-admin         Rabbit-MQ admin username
     -mqp|--rabbitmq-passsword     Rabbit-MQ admin password
     -mqu|--rabbitmq-url           Rabbit-MQ-API URL
     -n|--namespace                Kubernetes namespace for academy
EOF
}

parse_params() {
  while :; do
    case "${1-}" in
      -h|--help) script_usage && exit 0 ;;
      -tid|--tenantid)
        tenantId="${2-}"
        shift
      ;;
      -mqa|--rabbitmq-admin)
        mqAdmin="${2-}"
        shift
      ;;
      -mqp|--rabbitmq-passsword)
        mqPassword="${2-}"
        shift
      ;;
      -mqu|--rabbitmq-url)
        mqUrl="${2-}"
        shift
      ;;
      -n|--namespace)
        namespace="${2-}"
        shift
      ;;
      -?*) script_usage && echo "[ FAIL ] Unknown parameter ${1}" && exit 1 ;;
      *) break ;;
    esac
    shift
  done

  reqParams="";
  # check required params
  [[ -z "${tenantId-}" ]] && reqParams="${reqParams} tenantid"
  [[ -z "${mqAdmin-}" ]] && reqParams="${reqParams} rabbitmq-admin"
  [[ -z "${mqPassword-}" ]] && reqParams="${reqParams} rabbitmq-passsword"
  [[ -z "${mqUrl-}" ]] && reqParams="${reqParams} rabbitmq-url"
  [[ -z "${namespace-}" ]] && reqParams="${reqParams} namespace"
  [[ -n "${reqParams}" ]] && errcho "Missing required parameter: ${reqParams}" && script_usage && exit 1;
  return 0
}

get_random_pw() {
  echo "$(openssl rand -base64 40)"
}

parse_params "$@"

RMQ_URL="$mqUrl"
a5_user="a5-user"
n8n_user="n8n-user"
userpass="$mqAdmin:$mqPassword"

###############################################################################
# K8s secret setup for RabbitMQ users
###############################################################################
# 1. admin password
###############################################################################
a5_userpassword=$(kubectl get secret "a5-rabbitmq-user-pass" -o jsonpath='{.data.password}' -n "$namespace" | base64 --decode || echo 'NotFound')
if [[ $a5_userpassword =~ "NotFound" ]]; then
  a5_userpassword=$(get_random_pw)
  kubectl create secret generic "a5-rabbitmq-user-pass" \
  --from-literal=username=$a5_user \
  --from-literal=password="$a5_userpassword" \
  -n $namespace
  [[ $? -ne 0 ]] && errxit "failed to create the kubernetes secret a5-rabbitmq-user-pass"
fi
###############################################################################
# 2. user password
###############################################################################
n8n_userpassword=$(kubectl get secret "a5-rabbitmq-n8n-user-pass" -o jsonpath='{.data.password}' -n "$namespace" | base64 --decode || echo 'NotFound')
if [[ $n8n_userpassword =~ "NotFound" ]]; then
  n8n_userpassword=$(get_random_pw)
  kubectl create secret generic "a5-rabbitmq-n8n-user-pass" \
  --from-literal=username=$n8n_user \
  --from-literal=password="$n8n_userpassword" \
  -n $namespace
  [[ $? -ne 0 ]] && errxit "failed to create the kubernetes secret a5-rabbitmq-n8n-user-pass"
fi

###############################################################################
# RABBITMQ SETUP
###############################################################################
# 1. VHosts
###############################################################################
curl -u "${userpass}" -X PUT "$RMQ_URL/api/vhosts/$tenantId" --fail-with-body
[[ $? -ne 0 ]] && errxit "failed to create vhost: $tenantId"

###############################################################################
# 2. Users (create admin and user)
###############################################################################
curl -u "${userpass}" -X PUT  "$RMQ_URL/api/users/$a5_user" \
-H "Content-Type: application/json" \
-d '{"password":"'$a5_userpassword'","tags":"'$a5_user'"}' --fail-with-body
[[ $? -ne 0 ]] && errxit "failed to create user: $a5_user"

curl -u "${userpass}" -X PUT  "$RMQ_URL/api/users/$n8n_user" \
-H "Content-Type: application/json" \
-d '{"password":"'$n8n_userpassword'","tags":"'$n8n_user'"}' --fail-with-body
[[ $? -ne 0 ]] && errxit "failed to create user: $n8n_user"

###############################################################################
# 3. Permissions (admin gets all rights, n8n-user only read on a5 workflows)
###############################################################################
curl -u "${userpass}" -X PUT  "$RMQ_URL/api/permissions/$tenantId/$a5_user" \
-H "Content-Type: application/json" \
-d '{"configure":".*","write":".*","read":".*", "username":"'$a5_user'", "vhost":"'$tenantId'"}' --fail-with-body
[[ $? -ne 0 ]] && errxit "failed to create permissions for $a5_user"

curl -u "${userpass}" -X PUT  "$RMQ_URL/api/permissions/$tenantId/$n8n_user" \
-H "Content-Type: application/json" \
-d '{"configure":"","write":"","read":"a5.n8n.workflows.*", "username":"'$n8n_user'", "vhost":"'$tenantId'"}' --fail-with-body
[[ $? -ne 0 ]] && errxit "failed to create permissions for $n8n_user"

echo "RabbitMQ user setup done, the corresponding secrets names are a5-rabbitmq-n8n-user-pass and a5-rabbitmq-user-pass"
exit 0
