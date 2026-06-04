#!/bin/bash
set -x
bazel shutdown
bazel build --watchfs //:r
sed -i '' 's/VERSION = 1/VERSION = 2/' helper/consts.bzl
echo '# pad' >> nested/BUILD.bazel
sleep 2
bazel build --watchfs //:r
git checkout -- helper/consts.bzl nested/BUILD.bazel
