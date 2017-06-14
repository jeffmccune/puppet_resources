#!/bin/bash

# Error out if there are any failures
set -u
set -e

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

set -x

bundle install --path .bundle/gems/
bundle exec puppet-lint manifests
bundle exec puppet-lint site

# vim:tabstop=2
# vim:shiftwidth=2
# vim:expandtab
