#!/bin/bash
set -u

# The use of `eval` is to support deployment to multiple PE Monolithic masters.
# The CI jobs defined in `/.gitlab-ci.yml` should set SITE=A or SITE=B.  Then,
# in the Gitlab "variables" configuration of the control-repository, the
# following variables should be defined, as examples:
#
# * SITE_A_URL=https://master1.site1.acme.com:8170/code-manager/v1/deploys
# * SITE_A_TOKEN=XXXXXXX
# * SITE_B_URL=https://master1.site2.acme.com:8170/code-manager/v1/deploys
# * SITE_B_TOKEN=YYYYYYY

if [ -n "$SITE" ]; then
  echo "Deploying to SITE=$SITE ..."
  eval "export URL=\"\$SITE_${SITE}_URL\""
  echo "Set URL=${URL} based on SITE_${SITE}_URL variable"
  eval "export PUPPET_TOKEN=\"\$SITE_${SITE}_PUPPET_TOKEN\""
  echo "Set PUPPET_TOKEN=******** based on SITE_${SITE}_PUPPET_TOKEN variable"
fi

if [ -z "${PUPPET_TOKEN:-}" ]; then
  echo "ERROR: PUPPET_TOKEN environment variable must be set!" >&2
  echo "SUGGESTION: Did you push to origin instead of upstream?" >&2
  exit 1
fi

# Allow these environment variable to be overriden
: ${URL:='https://puppet:8170/code-manager/v1/deploys'}
# CI_BUILD_REF_NAME is a variable set by gitlab
: ${ENVIRONMENT:="$CI_BUILD_REF_NAME"}

# The data to send in the notification.  Documentation:
# https://docs.puppet.com/pe/2016.4/code_mgr_scripts.html#deploys-endpoint
JSON_DATA="{\"environments\": [\"$ENVIRONMENT\"], \"wait\": true}"

echo "Sending notification to ${URL} ..."
echo "Deploying to Puppet environment ${ENVIRONMENT}"
echo "Notification ${JSON_DATA}"

scratch="$(mktemp -d)"
remove_scratch() {
  [ -e "${scratch:-}" ] && rm -rf "$scratch"
}
trap remove_scratch EXIT
body="${scratch}/body.txt"

response=$(curl --silent -S -k -X POST \
  --output "$body" \
  -H 'Content-Type: application/json' \
  -H "X-Authentication: $PUPPET_TOKEN" \
  --write-out %{http_code} \
  "$URL" \
  -d "$JSON_DATA")

echo "# Response Body:"

# Read the body and look for errors
/opt/puppetlabs/puppet/bin/ruby -rjson <<EOSCRIPT
deployments=JSON.load(File.read('${body}'))
puts JSON.pretty_generate(deployments)
puts
deployments.each do |deployment|
  if deployment['status'] != 'complete'
    puts "ERROR: Deployment did not complete!"
    puts "Full repsonse for deployment:"
    puts JSON.pretty_generate(deployment)
    puts
    puts deployment['error']['msg']
    Kernel.exit(7)
  end
end
EOSCRIPT
rval=$?
if [ $rval -ne 0 ]; then
  exit $rval
fi

echo -n "Checking if HTTP 200 <= $response < 300 ... "
if [ $response -gt 199 -a $response -lt 300 ]; then
  echo "SUCCESS"
  rval=0
else
  echo "FAILURE"
  rval=22
fi

echo "Exiting with exit value $rval"
exit $rval
