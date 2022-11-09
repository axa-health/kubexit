#!/bin/bash
set -e

DOCKER_ARGS=""
PROXY=
PUSH="no"

USE_DEFAULT_BUILD_CONTAINER="no"

# buildx pre and postfixes the container making the name unique
BUILD_CONTAINER="kubexit"

PUSH="yes"
TAG="0.3.5"
IMAGE_PREFIX="axahealth"

function print_help {
  cat << EndOfMessage
Build the axah kubexit fork image (multiplatform for amd64 and arm64).
Options:
  -p|--proxy       enable axa server proxy in docker image builds
  --use-default    use the already existing buildx container, won't remove it
  --push           push to docker registry, if not set, only the host arch will be built
  -h               print this help dialog
EndOfMessage
}

while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -p|--proxy)
      PROXY="http://techproxy.uk.axa-tech.intraxa:8080"
      DOCKER_ARGS="$DOCKER_ARGS --build-arg HTTP_PROXY=$PROXY --build-arg HTTPS_PROXY=$PROXY"
      echo "using proxy"
      shift # past argument
      ;;
    --push)
      PUSH="yes"
      shift # past argument
      ;;
    --use-default)
      USE_DEFAULT_BUILD_CONTAINER="yes"
      echo "Using default buildx container"
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)    # unknown option
      echo "unknown option $1"
      print_help
      exit 1
      ;;
  esac
done

# allow users to use pre existing build containers so they don't have to be rebuilt every time
if [ "$USE_DEFAULT_BUILD_CONTAINER" = "no" ]; then
    # Create buildx container, removed afterwards
    docker buildx create --use --name $BUILD_CONTAINER > /dev/null

    function remove_container() {
        docker buildx rm $BUILD_CONTAINER
        echo "Removed buildx build container"
    }

    # always remove the container afterwards
    trap remove_container EXIT
fi


if [ "$PUSH" = "yes" ]; then
  docker buildx build \
    ${DOCKER_ARGS} \
    --platform linux/arm64,linux/amd64 \
    --push \
    -t "$IMAGE_PREFIX"/kubexit:${TAG} \
    ./mirror/.
else
  # only build for the host platform if the image is not pushed (https://github.com/docker/buildx/issues/59)
  docker buildx build  \
    ${DOCKER_ARGS} \
    --load \
    -t "$IMAGE_PREFIX"/kubexit:${TAG} \
    ./mirror/.
fi
