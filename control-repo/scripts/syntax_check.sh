#!/bin/bash

# Error out if there are any failures
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
export PATH="/opt/puppetlabs/puppet/bin:$PATH"

# Check the Puppetfile
echo -n "Checking Puppetfile ... "
ruby -c Puppetfile

# Find all the script and run syntax check
find . -name '.git' -o -name '*.sh' -print0 \
  | xargs --no-run-if-empty -0 -t -P$cores -n1 \
  bash -n

# Check all YAML files
# See: http://stackoverflow.com/questions/3971822/yaml-syntax-validator
find . -name '.git' -o -name '*.yml' -print0 \
  | xargs --no-run-if-empty -0 -t -P$cores -n1 \
  ruby -r yaml -e 'YAML.load_file(ARGV[0])'

find . -name '.git' -o -name '*.yaml' -print0 \
  | xargs --no-run-if-empty -0 -t -P$cores -n1 \
  ruby -r yaml -e 'YAML.load_file(ARGV[0])'

# Check all JSON files
find . -name '.git' -o -name '*.json' -print0 \
  | xargs --no-run-if-empty -0 -t -P$cores -n1 \
  ruby -r json -e 'JSON.load(File.read(ARGV[0]))'

find . -name '.git' -o -name '*.rb' -print0 \
  | xargs --no-run-if-empty -0 -t -P$cores -n1 \
  ruby -c
