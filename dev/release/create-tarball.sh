#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

# This script creates a signed tarball in
# dev/dist/apache-arrow-object-store-rs-<version>-<sha>.tar.gz and uploads it to
# the "dev" area of the dist.apache.arrow repository and prepares an
# email for sending to the dev@arrow.apache.org list for a formal
# vote.
#
# Note the tags are expected to be `object_sore_<version>`
#
# See release/README.md for full release instructions
#
# Requirements:
#
# 1. gpg setup for signing and have uploaded your public
# signature to https://pgp.mit.edu/
#
# 2. Logged into the apache svn server with the appropriate
# credentials
#
#
# Based in part on 02-source.sh from apache/arrow
#

set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_TOP_DIR="$(cd "${SOURCE_DIR}/../../" && pwd)"

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <object_store_version> <rc>"
    echo "ex. $0 0.4.0 1"
  exit
fi

object_store_version=$1
rc=$2
tag=v${object_store_version}

release=apache-arrow-object-store-rs-${object_store_version}
distdir=${SOURCE_TOP_DIR}/dev/dist/${release}-rc${rc}
tarname=${release}.tar.gz
tarball=${distdir}/${tarname}
url="https://dist.apache.org/repos/dist/dev/arrow/${release}-rc${rc}"

echo "Attempting to create ${tarball} from tag ${tag}"

release_hash=$(cd "${SOURCE_TOP_DIR}" && git rev-list --max-count=1 ${tag})

if [ -z "$release_hash" ]; then
    echo "Cannot continue: unknown git tag: $tag"
fi

echo "Draft email for dev@arrow.apache.org mailing list"
echo ""
echo "---------------------------------------------------------"
cat <<MAIL
To: dev@arrow.apache.org
Subject: [VOTE][RUST] Release Apache Arrow Rust Object Store ${object_store_version} RC${rc}

Hi,

I would like to propose a release of Apache Arrow Rust Object
Store Implementation, version ${object_store_version}.

This release candidate is based on commit: ${release_hash} [1]

The proposed release tarball and signatures are hosted at [2].

The changelog is located at [3].

Please download, verify checksums and signatures, run the unit tests,
and vote on the release. There is a script [4] that automates some of
the verification.

The vote will be open for at least 72 hours.

[ ] +1 Release this as Apache Arrow Rust Object Store ${version}
[ ] +0
[ ] -1 Do not release this as Apache Arrow Rust Object Store ${version} because...

[1]: https://github.com/apache/arrow-rs-object-store/tree/${release_hash}
[2]: ${url}
[3]: https://github.com/apache/arrow-rs-object-store/blob/${release_hash}/CHANGELOG.md
[4]: https://github.com/apache/arrow-rs-object-store/blob/main/dev/release/verify-release-candidate.sh
MAIL
echo "---------------------------------------------------------"


# create <tarball> containing the files in git at $release_hash
# the files in the tarball are prefixed with {tag=} (e.g. 0.4.0)
mkdir -p ${distdir}
(cd "${SOURCE_TOP_DIR}" && git archive ${release_hash} --prefix ${release}/ | gzip > ${tarball})

echo "Running rat license checker on ${tarball}"
${SOURCE_DIR}/../../dev/release/run-rat.sh ${tarball}

echo "Signing tarball and creating checksums"
gpg --armor --output ${tarball}.asc --detach-sig ${tarball}
# create signing with relative path of tarball
# so that they can be verified with a command such as
#  shasum --check apache-arrow-rs-4.1.0-rc2.tar.gz.sha512
(cd ${distdir} && shasum -a 256 ${tarname}) > ${tarball}.sha256
(cd ${distdir} && shasum -a 512 ${tarname}) > ${tarball}.sha512

echo "Uploading to apache dist/dev to ${url}"
svn co --depth=empty https://dist.apache.org/repos/dist/dev/arrow ${SOURCE_TOP_DIR}/dev/dist
svn add ${distdir}
svn ci -m "Apache Arrow Rust ${object_store_version=} ${rc}" ${distdir}
