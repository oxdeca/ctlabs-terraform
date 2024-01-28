#!/bin/bash

PROJECT=$( cat gcp.conf.yml | awk -F: '{ if ( $1 ~ / id / ) print $2 }' | sed 's@ @@' )
USER=$( cat gcp.conf.yml | awk -F: '{ if ( $1 ~ / user / ) print $2 }' | sed 's@ @@' )

if [ -n "${PROJECT}" ]; then
  gcloud config set account ${USER}
fi

if [ -n "${USER}" ]; then
  gcloud config set project ${PROJECT}
fi

if [ -n "${PROJECT}" ] && [ -n "${USER}" ]; then
  gcloud auth application-default login --no-launch-browser
fi
