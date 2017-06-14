#!/bin/bash

# Error out if there are any failures
set -e
set -o pipefail
set -u

# Notes
# xargs -P2 is used to run 2 parallel processes at once.  This speeds up
# performance on multi-core systems.

if [ -e /proc/cpuinfo ]; then
  cores=$(awk 'BEGIN { c = 0 }; $1 == "processor" { c++ }; END { print c }' /proc/cpuinfo)
else
  cores=2
fi

# Use Puppet Enterprise Ruby to check ruby and yaml files
export PATH="/opt/puppetlabs/puppet/bin:/opt/puppetlabs/bin:$PATH"
# If we need to install a gem, do so into HOME
# e.g. /home/gitlab-runner/.gem/ruby/2.1.0
export GEM_HOME="$(gem env gempath | cut -d: -f1)"
export PATH="${GEM_HOME}/bin:$PATH"

if ! (which bundle 2>/dev/null); then
  gem install bundler --no-ri --no-rdoc
fi

# List the files changes from $BASEBRANCH on stdout
files_changed() {
  # File status flags:
  # M modified - File has been modified
  # C copy-edit - File has been copied and modified
  # R rename-edit - File has been renamed and modified
  # A added - File has been added
  # D deleted - File has been deleted
  # U unmerged - File has conflicts after a merge
  git diff --name-status "${BASEBRANCH:=production}" \
    | awk '$1 ~ /^[MCRA]$/' \
    | cut -f2-
}

bundle install --path .bundle/gems/

# Lint only the manifest files changed
files_changed \
  | awk '/manifests\/.*\.(pp)$/' \
  | xargs --no-run-if-empty -t -P$cores -n1 \
  bundle exec puppet-lint

# vim:tabstop=2
# vim:shiftwidth=2
# vim:expandtab
