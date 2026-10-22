#!/bin/bash

# release or dev
TAG=$1
# latest or latest-dev (or a specific version)
BINARIES_IMAGE=$2
# passed as komodo variable
KOMODO_VERSION=$3
# passed as komodo variable
UPLOAD_TOKEN=$4

REPO=moghtech/komodo-build
RELEASE=v$KOMODO_VERSION-$TAG

echo "Tag: ${TAG}"
echo "Image: ${BINARIES_IMAGE}"
echo "Version: ${KOMODO_VERSION}"
echo "Release: ${REPO} ${RELEASE}"

X86_64_IMAGE=$BINARIES_IMAGE-x86_64
AARCH64_IMAGE=$BINARIES_IMAGE-aarch64

docker pull $X86_64_IMAGE
docker pull $AARCH64_IMAGE

x86_64_id=$(docker create $X86_64_IMAGE sh)
aarch64_id=$(docker create $AARCH64_IMAGE sh)

github() {
    curl -sS \
        -H "Authorization: Bearer $UPLOAD_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$@"
}

# The release id is the first "id" field in the response
parse_release_id() {
    grep -m1 '"id":' | tr -dc '0-9'
}

# Get the release for this version, creating it if it doesn't exist yet
release_id=$(github https://api.github.com/repos/$REPO/releases/tags/$RELEASE | parse_release_id)
if [ -z "$release_id" ]; then
    prerelease=true
    if [ "$TAG" = "release" ]; then
        prerelease=false
    fi
    release_id=$(github -X POST https://api.github.com/repos/$REPO/releases \
        -d "{\"tag_name\":\"$RELEASE\",\"name\":\"$RELEASE\",\"prerelease\":$prerelease}" | parse_release_id)
fi
if [ -z "$release_id" ]; then
    echo "Failed to get or create release $RELEASE"
    exit 1
fi

upload_asset() {
    file_name=$1
    # Delete existing asset with the same name, otherwise the upload is rejected.
    # In the asset json, "id" comes 2 lines before "name".
    asset_id=$(github "https://api.github.com/repos/$REPO/releases/$release_id/assets?per_page=100" \
        | grep -B2 "\"name\": \"$file_name\"" | grep -m1 '"id":' | tr -dc '0-9')
    if [ -n "$asset_id" ]; then
        github -X DELETE https://api.github.com/repos/$REPO/releases/assets/$asset_id
    fi
    github -f -o /dev/null -X POST \
        -H "Content-Type: application/octet-stream" \
        --data-binary @./$file_name \
        "https://uploads.github.com/repos/$REPO/releases/$release_id/assets?name=$file_name" \
        && echo "Uploaded $file_name"
}

upload() {
    bin_name=$1
    docker cp $x86_64_id:/$bin_name ./$bin_name-x86_64
    upload_asset $bin_name-x86_64
    docker cp $aarch64_id:/$bin_name ./$bin_name-aarch64
    upload_asset $bin_name-aarch64
}

upload "periphery"
upload "km"

docker container rm $x86_64_id
docker container rm $aarch64_id
