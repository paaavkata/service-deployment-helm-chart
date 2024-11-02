#! /bin/bash

APP_NAME=service-deployment-helm-chart
AWS_REGION="eu-west-1"
TAG=$(git rev-parse --short HEAD --)
HELM_CHART_DIR=chart
REGISTRY_ID=$(aws ecr describe-registry --output text --query 'registryId' --region $AWS_REGION)
REGISTRY="${REGISTRY_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
CHART_REPO=file-convert/app
CHART_TARGET_DIR="${HELM_CHART_DIR}/target"
CHART_VERSION="1.0.0-SHA${TAG}"

# # === Build and push Helm chart ===
helm dependency update ${HELM_CHART_DIR}
if [ ! -d ${CHART_TARGET_DIR} ]; then
    mkdir ${CHART_TARGET_DIR}
fi

helm package ${HELM_CHART_DIR} --destination ${CHART_TARGET_DIR} --version $CHART_VERSION
aws ecr describe-repositories --region $AWS_REGION --repository-names ${CHART_REPO}/${APP_NAME} || aws ecr create-repository --repository-name ${CHART_REPO}/${APP_NAME} --region $AWS_REGION
aws ecr get-login-password --region $AWS_REGION | helm registry login --username AWS --password-stdin $REGISTRY
helm push ${CHART_TARGET_DIR}/${APP_NAME}-${CHART_VERSION}.tgz "oci://${REGISTRY}/${CHART_REPO}/"
rm -f ${CHART_TARGET_DIR}/*