#!/usr/bin/env bash
#
# deploys a pod into a cluster
#

tmpfile=$(mktemp)

cleanup()
{
  if [[ -f $tmpfile ]]; then
    rm -f $tmpfile
  fi
}
trap cleanup EXIT

waitforpod()
{
  local cmd="kubectl get pods -o go-template --selector=app=$safename --field-selector=status.phase=Running --template '{{range .items}}{{.metadata.name}}{{\"\n\"}}{{end}}'"
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

if [[ $# < 3 ]]; then
  echo "usage: $0 <name> <tag> <port> <command>"
  exit 0
fi
name=$1
safename=$(echo $name|tr _ -)
tag=$2
port=$3
echo "Image Name: $name , Tag: $tag and Port: $port"
shift 3
command=''
case $# in
  0)
    ;;
  1)
    case $1 in
      sleep)
        command=$(printcommand "/bin/bash"  "-c"  "trap : TERM INT; sleep infinity & wait")
        ;;
      *)
        if [[ -n $1 ]]; then
          command=$(printcommand "$@")
        fi
        ;;
    esac
    ;;
  *)
    command=$(printcommand "$@")
    ;;
esac
if [ -z "$(printnamespace)" ]; then
    namespace=$USER
else
    namespace=$(printnamespace)
fi;

echo "Creating deployment $safename in namespace: $namespace"
  cat << DEPLOY_YAML > $tmpfile
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: $safename
  name: $safename
  namespace: $namespace
spec:
  template:
    metadata:
      labels:
        app: $safename
      namespace: $namespace
    spec:
      containers:
      - image: gcr.io/constant-cubist-173123/$name:$tag
        $command
        name: $safename
        ports:
        - containerPort: $port
        imagePullPolicy: Always
        env:
        - name: DEBUG
          value: "${DEBUG:=false}"
        resources:
          limits:
            cpu: "4"
            memory: 4Gi
          requests:
            cpu: "1"
            memory: 2Gi
        securityContext:
          privileged: true
          allowPrivilegeEscalation: true

DEPLOY_YAML

kubectl create -f $tmpfile >/dev/null 2>&1
waitforpod
