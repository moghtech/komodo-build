#!/bin/bash

# release or dev
TAG=$1
# latest or latest-dev (or a specific version)
BINARIES_IMAGE=$2
# passed as komodo variable
KOMODO_VERSION=$3
# passed as komodo variable
MOGH_FORGE_TOKEN=$4

echo "Tag: ${TAG}"
echo "Image: ${BINARIES_IMAGE}"
echo "Version: ${KOMODO_VERSION}"

X86_64_IMAGE=$BINARIES_IMAGE-x86_64
AARCH64_IMAGE=$BINARIES_IMAGE-aarch64

docker pull $X86_64_IMAGE
docker pull $AARCH64_IMAGE

x86_64_id=$(docker create $X86_64_IMAGE sh)
aarch64_id=$(docker create $AARCH64_IMAGE sh)

upload() {
    bin_name=$1
    docker cp $x86_64_id:/$bin_name ./$bin_name-x86_64
    curl --user mbecker20:$MOGH_FORGE_TOKEN \
        --upload-file ./$bin_name-x86_64 \
        https://forge.mogh.tech/api/packages/komodo/generic/$bin_name/$KOMODO_VERSION-$TAG/$bin_name-x86_64
    docker cp $aarch64_id:/$bin_name ./$bin_name-aarch64
    curl --user mbecker20:$MOGH_FORGE_TOKEN \
        --upload-file ./$bin_name-aarch64 \
        https://forge.mogh.tech/api/packages/komodo/generic/$bin_name/$KOMODO_VERSION-$TAG/$bin_name-aarch64
}

upload "periphery"
upload "km"

docker container rm $x86_64_id
docker container rm $aarch64_id