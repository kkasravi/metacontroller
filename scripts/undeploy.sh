#!/usr/bin/env bash
#
# deletes a deployment
#

name=$1
safename=$(echo $name|tr _ -)
kubectl delete deployment $safename
exit 0
