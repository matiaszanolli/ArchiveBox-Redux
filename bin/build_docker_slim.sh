#!/usr/bin/env bash

### Bash Environment Setup
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
# set -o xtrace
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
IFS=$'\n'

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd .. && pwd )"
VERSION="$(jq -r '.version' < "$REPO_DIR/package.json")"
SHORT_VERSION="$(echo "$VERSION" | perl -pe 's/(\d+)\.(\d+)\.(\d+)/$1.$2/g')"
cd "$REPO_DIR"

which docker > /dev/null

echo "[+] Building archivebox-redux:$VERSION docker image..."
docker-slim build --dockerfile Dockerfile \
               --dockerfile-context . \
               --tag archivebox-redux:latest-slim \
               --tag archivebox-redux:$VERSION-slim \
               --tag archivebox-redux:$SHORT_VERSION-slim \
               --tag matiaszanolli/archivebox-redux:latest-slim \
               --tag matiaszanolli/archivebox-redux:$VERSION-slim \
               --tag matiaszanolli/archivebox-redux:$SHORT_VERSION-slim \
               --tag docker.io/matiaszanolli/archivebox-redux:latest-slim \
               --tag docker.io/matiaszanolli/archivebox-redux:$VERSION-slim \
               --tag docker.io/matiaszanolli/archivebox-redux:$SHORT_VERSION-slim \
