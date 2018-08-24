#!/usr/bin/env bash
#
# will setup credentials in order to pull parent images
#

# Exit on any error
set -e

export PATH="$PATH":/opt/google-cloud-sdk/bin
rm -rf build
if [[ -n $GCLOUD_SERVICE_KEY ]]; then
  echo $GCLOUD_SERVICE_KEY > ${HOME}/gcloud-service-key.json
  gcloud auth activate-service-account --key-file=${HOME}/gcloud-service-key.json
  gcloud config set project $GCLOUD_PROJECT
  yes | gcloud container clusters get-credentials dl-profiler --zone=us-west1-a
  gcloud auth configure-docker
fi
docker build $@
