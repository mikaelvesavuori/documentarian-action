#!/bin/bash -l

set -o pipefail

# Set user inputs
SRC_FOLDER="${1}"
echo "SRC_FOLDER is: $SRC_FOLDER"

DOCS_FOLDER="${2}"
echo "DOCS_FOLDER is: $DOCS_FOLDER"

SCHEMA_PATH="${3}"
echo "SCHEMA_PATH is: $SCHEMA_PATH"

CLOUDFORMATION_PATH="${4}"
echo "CLOUDFORMATION_PATH is: $CLOUDFORMATION_PATH"

CATALOGIST_ENDPOINT="${5}"
echo "CATALOGIST_ENDPOINT is: $CATALOGIST_ENDPOINT"

CATALOGIST_API_KEY="${6}"
if [[ $CATALOGIST_API_KEY ]]; then echo "CATALOGIST_API_KEY is set"; else echo "CATALOGIST_API_KEY is not set"; fi

CLOUDFLARE_ACCOUNT_ID="${7}"
if [[ $CLOUDFLARE_ACCOUNT_ID ]]; then echo "CLOUDFLARE_ACCOUNT_ID is set"; else echo "CLOUDFLARE_ACCOUNT_ID is not set"; fi

CLOUDFLARE_AUTH_TOKEN="${8}"
if [[ $CLOUDFLARE_AUTH_TOKEN ]]; then echo "CLOUDFLARE_AUTH_TOKEN is set"; else echo "CLOUDFLARE_AUTH_TOKEN is not set"; fi

CLOUDFLARE_PROJECT_NAME="${9}"
echo "CLOUDFLARE_PROJECT_NAME is: $CLOUDFLARE_PROJECT_NAME"

CLOUDFLARE_CATALOG_NAME="${10}"
echo "CLOUDFLARE_CATALOG_NAME is: $CLOUDFLARE_CATALOG_NAME"

main() {
  # Ensure we have the directories set up for later
  mkdir -p "$DOCS_FOLDER/api"

  # For convenience, let's just bundle all Node stuff into a single check
  if [ -f "package.json" ]; then
    installNodeDependencies
    setOwnership
    runSyft
    generateTypedoc
    generateMadge
  fi

  # All of these have their own respective checks before running
  generateApiDocs
  diagramCloudformation
  uploadToCatalogist
  buildEventCatalog
  publish
}

installNodeDependencies() {
  echo "Installing dependencies..."
  npm ci
  npm install @asyncapi/generator typedoc madge @mhlabs/cfn-diagram wrangler@2 --save-dev --no-audit --no-optional
}

setOwnership() {
  # Set ownership to ensure things don't break; probably redundant stuff here
  chown -R "$(whoami)" "$SRC_FOLDER"
  chown -R "$(whoami)" "$DOCS_FOLDER"
  chown -R "$(whoami)" /github/home/
  chown -R "$(whoami)" /github/workspace/
  chown -R "$(whoami)" /github/workspace/$SCHEMA_PATH
  chown -R "$(whoami)" /github/workspace/$CLOUDFORMATION_PATH
  chmod u+x /github/workspace/$CLOUDFORMATION_PATH
}

runSyft() {
  echo "Running syft..."
  syft packages dir:. >"$DOCS_FOLDER/syft_report.txt"
}

generateTypedoc() {
  echo "Running typedoc..."
  npx typedoc --entryPoints "$SRC_FOLDER" --entryPointStrategy expand --exclude "**/*+(test).ts" --externalPattern 'node_modules/**/*' --excludeExternals --out "$DOCS_FOLDER"
}

generateMadge() {
  echo "Running madge..."
  npx madge --image "./$DOCS_FOLDER/code-diagram.svg" --exclude '(testdata|interfaces|application/errors)/.{0,}.(ts|js|json)' --extensions ts "$SRC_FOLDER"
}

generateApiDocs() {
  if ls "$SCHEMA_PATH" 1>/dev/null 2>&1; then
    echo "Running API docs generator..."
    npx ag "$SCHEMA_PATH" @asyncapi/html-template --output "$DOCS_FOLDER/api" --force-write
  fi
}

diagramCloudformation() {
  if ls serverless.yml 1>/dev/null 2>&1; then
    if ls "$CLOUDFORMATION_PATH" 1>/dev/null 2>&1; then
      # This needs to be done so the files actually exist for cfn-diagram
      echo "Packaging serverless app..."
      npx sls package

      echo "Running cfn-diagram..."
      npx cfn-dia draw.io -t "$CLOUDFORMATION_PATH" --ci-mode -o "$DOCS_FOLDER/cfn-diagram.drawio"
    fi
  fi
}

uploadToCatalogist() {
  if [[ $CATALOGIST_ENDPOINT ]] && [[ $CATALOGIST_API_KEY ]]; then
    if ls manifest.json 1>/dev/null 2>&1; then
      echo "Uploading service metadata to Catalogist service..."
      curl -X POST "${CATALOGIST_ENDPOINT}" -d "@manifest.json" -H "Authorization: ${CATALOGIST_API_KEY}"
    fi
  fi
}

buildEventCatalog() {
  if [[ $CLOUDFLARE_ACCOUNT_ID ]] && [[ $CLOUDFLARE_CATALOG_NAME ]] && [[ $CLOUDFLARE_AUTH_TOKEN ]]; then
    echo "Requesting build of EventCatalog..."
    curl --request POST \
      --url "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/$CLOUDFLARE_CATALOG_NAME/deployments" \
      --header "Authorization: Bearer $CLOUDFLARE_AUTH_TOKEN" \
      --header "Content-Type: application/json"
  fi
}

publish() {
  if [[ $CLOUDFLARE_ACCOUNT_ID ]] && [[ $CLOUDFLARE_PROJECT_NAME ]] && [[ $CLOUDFLARE_AUTH_TOKEN ]]; then
    echo "Publishing documentation to Cloudflare Pages..."
    export CLOUDFLARE_ACCOUNT_ID=$CLOUDFLARE_ACCOUNT_ID
    export CLOUDFLARE_API_TOKEN=$CLOUDFLARE_AUTH_TOKEN
    npx wrangler pages publish "$DOCS_FOLDER" --project-name="$CLOUDFLARE_PROJECT_NAME"
  fi
}

main "$@"
exit
