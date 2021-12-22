#!/bin/sh

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


###############################################################################
# Script to ensure health of instructions through nightly builds
# Safe to ignore for the purposes of the intended solution/lab
###############################################################################

PROJECT_ID="$(gcloud config get-value project)"
sed -i.org "s/eval/$APIGEE_X_ENV/g" edge.json

echo "[INFO] CI and artifact storage using Cloud Build"
SUBSTITUTIONS_X="_APIGEE_ORG=$APIGEE_X_ORG"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_APIGEE_ENV=$APIGEE_X_ENV"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_APIGEE_RUNTIME_HOST=$APIGEE_X_HOSTNAME"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_APIGEE_BUILD_BUCKET=${PROJECT_ID}_cloudbuild"
gcloud builds submit --config=./cloudbuild.yaml \
  --substitutions="$SUBSTITUTIONS_X"

echo ""
echo ""
echo "Test: Artifact generated and persisted in GCS"
if ! gsutil ls -r gs://"${PROJECT_ID}"_cloudbuild/MockTarget/* | grep MockTarget-1.0
then
  exit 1
fi

echo ""
echo "Test: nonprod API created"
if ! gcloud apigee apis list --organization="$APIGEE_X_ORG" | grep MockTarget 
then
  exit 1
fi

echo "Test: nonprod API deployed to env"
if ! gcloud apigee deployments list  --organization="$APIGEE_X_ORG" --api=MockTarget | grep "${APIGEE_X_ENV}"
then
    exit 1
fi

# In nonprod, GCB doesn't populate COMMIT_SHA for cli builds 
# setting COMMIT_SHA to null so release build picks the built artifact
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_COMMIT_SHA="
gcloud builds submit --config=./cloudbuild-release.yaml \
  --substitutions="$SUBSTITUTIONS_X"

echo ""
echo "Test: release API created"
if ! gcloud apigee apis list --organization="$APIGEE_X_ORG" | grep MockTarget 
then
  exit 1
fi

echo "Test: release API deployed to env"
if ! gcloud apigee deployments list  --organization="$APIGEE_X_ORG" --api=MockTarget | grep "${APIGEE_X_ENV}"
then
    exit 1
fi
