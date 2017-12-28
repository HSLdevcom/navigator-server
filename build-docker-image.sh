#!/bin/bash

# This is run at ci
#
# Set these environment variables
#DOCKER_USER // dockerhub credentials
#DOCKER_AUTH

ORG=${ORG:-hsldevcom}
DOCKER_TAG=${TRAVIS_COMMIT:-latest}
DOCKER_IMAGE=$ORG/navigator-server
DOCKER_IMAGE_COMMIT=$DOCKER_IMAGE:$DOCKER_TAG
DOCKER_IMAGE_LATEST=$DOCKER_IMAGE:latest
DOCKER_IMAGE_PROD=$DOCKER_IMAGE:prod

if [ -z $TRAVIS_TAG ]; then
  # Build image
  echo Building navigator-server
  docker build --tag="$DOCKER_IMAGE_COMMIT" -f Dockerfile .
fi

if [ "${TRAVIS_PULL_REQUEST}" == "false" ]; then
  docker login -u $DOCKER_USER -p $DOCKER_AUTH
  if [ "$TRAVIS_TAG" ];then
    echo "Processing release $TRAVIS_TAG"
    docker pull $DOCKER_IMAGE_COMMIT
    docker tag $DOCKER_IMAGE_COMMIT $DOCKER_IMAGE_PROD
    docker push $DOCKER_IMAGE_PROD
  else
    echo "Pushing latest image"
    docker push $DOCKER_IMAGE_COMMIT
    docker tag $DOCKER_IMAGE_COMMIT $DOCKER_IMAGE_LATEST
    docker push $DOCKER_IMAGE_LATEST
  fi
fi

echo Build completed


