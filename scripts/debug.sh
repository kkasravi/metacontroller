#!/usr/bin/env bash
#
# debugs a golang binary
#

tmpfile=$(mktemp)

cleanup()
{
  if [[ -f $tmpfile ]]; then
    rm -f $tmpfile
  fi
  if [[ -n $portforwardcommand ]]; then
    echo killing $portforwardcommand
    pkill -f $portforwardcommand
  fi
}
trap cleanup EXIT

portforward()
{
  local pod=$1 from_port=$2 to_port=$3
  cmd='kubectl port-forward $pod ${from_port}:${to_port} 2>&1>/dev/null &'
  portforwardcommand="${cmd% 2>&1>/dev/null &}"
  ( $verbose && echo $cmd && eval $cmd ) || eval $cmd
}

printpod()
{
  local cmd="kubectl get pods -o go-template --selector=app=$safename --field-selector=status.phase=Running --template '{{range .items}}{{.metadata.name}}{{\"\n\"}}{{end}}'"
  found=$(eval "$cmd")
  while [[ -z $found ]]; do
    sleep 1
    found=$(eval "$cmd")
  done
  echo $found
}

printnamespace()
{
  eval "kubectl config get-contexts | grep ""'*'"" | awk '{print (NF==5 ? \$NF : ""\" \""")}'"
}

printuser()
{
  eval "kubectl config get-contexts | grep ""'*'"" | awk '{print (NF==5 ? \$4 : ""\" \""")}'"
}

printcommand()
{
  local command='command: ['  arg
  while [[ $# > 0 ]]; do
    arg="$1"
    case $# in
      1)
        trailingarg='"]'
        ;;
      *)
        trailingarg='", '
        ;;
    esac
    command=${command}'"'${arg}${trailingarg}
    shift 1
  done
  echo "$command"
}

addsubject()
{
  local user=$1 namespace=$2
  kubectl set subject clusterrolebinding $user --serviceaccount=${namespace}:default
}

if [[ $# < 3 ]]; then
  echo "usage: $0 <name> <pname> <port>"
  exit 0
fi
DEBUG_MODE=${DEBUG_MODE:=attach}
name=$1
safename=$(echo $name|tr _ -)
pname=$2
port=$3
namespace=$(printnamespace)
user=$(printuser)
case $DEBUG_MODE in
  attach)
    pod=$(printpod)
    portforward $pod $port $port
    kubectl exec $pod -it -- /go/src/github.com/IntelAI/app-authz/scripts/godebug attach $pname
    ;;
  exec)
    addsubject $user $namespace
    pod=$(printpod)
    portforward $pod $port $port
    kubectl exec $pod -it -- /go/src/github.com/IntelAI/app-authz/scripts/dlv.sh
    ;;
  *)
    echo invalid DEBUG_MODE=$DEBUG_MODE
    exit 1
    ;;
esac
