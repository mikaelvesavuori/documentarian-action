# `documentarian-action`

Documentarian is an opinionated bundle of tools that generates docs for (primarily) back-ends written in [TypeScript](https://www.typescriptlang.org) and using [Serverless Framework](https://www.serverless.com) which it will then upload to [Cloudflare Pages](https://pages.cloudflare.com). As far as documenting CloudFormation, Documentarian is assuming you will use Serverless Framework to produce the stack but it could come from any source as long as it's valid CloudFormation.

Under the hood this action uses:

- [Syft](https://github.com/anchore/syft) to generate a software bill of materials
- [TypeDoc](https://typedoc.org) to generate docs from TypeScript code and markdown
- [Madge](https://github.com/pahen/madge) to create code diagrams
- [@asyncapi/generator](https://github.com/asyncapi/generator) to generate API docs from AsyncAPI schema
- [@mhlabs/cfn-diagram](https://github.com/mhlabs/cfn-diagram) to generate diagram from CloudFormation stack
- [catalogist](https://github.com/mikaelvesavuori/catalogist) to publish your service metadata to your Catalogist service
- Pings the [Cloudflare Pages API](https://api.cloudflare.com/#pages-project-properties) to start a rebuild of your [eventcatalog](https://github.com/boyney123/eventcatalog) instance
- [@cloudflare/wrangler](https://github.com/cloudflare/wrangler) to upload your docs to Cloudflare Pages

You can choose to run all or just a subset of the tools. It's recommended that you run this action _after_ any deployments and similar so it won't be in the way. A full run of all tools takes ~3 minutes.

## Limitations

Documentarian will currently only accept a single CloudFormation stack per run.

## Setup and usage

### Requirements to run each tool

Syft, TypeDoc and Madge will all run automatically given the presence of a `package.json` file in the root of your repository.

[@asyncapi/generator](https://github.com/asyncapi/generator) requires a JSON/YML schema at the chosen schema path.

[@mhlabs/cfn-diagram](https://github.com/mhlabs/cfn-diagram) will run given a `serverless.yml` file in the root of your repository. Documentarian will use the command `npx sls package` to generate the CloudFormation file. **You will therefore need to have `serverless` as a (develoer) dependency**.

[catalogist](https://github.com/mikaelvesavuori/catalogist) requires explicitly setting the inputs `catalogist_endpoint` and `catalogist_api_key`. You will also need the `manifest.json` file in the root of your repository for it to actually upload anything.

Starting the [eventcatalog](https://github.com/boyney123/eventcatalog) build requires setting the `cloudflare_account_id`, `cloudflare_catalog_name` and `cloudflare_auth_token` inputs.

### Viewing the published docs

_The below is all given that you are using Cloudflare Pages to publish your docs_.

Your site will be available at [https://YOUR_SITE.pages.dev](https://YOUR_SITE.pages.dev). Check the logs for the exact URL to the preview/draft site.

API docs are at [https://YOUR_SITE.pages.dev/api](https://YOUR_SITE.pages.dev/api).

The SBOM can be found at [https://YOUR_SITE.pages.dev/syft_report.txt](https://YOUR_SITE.pages.dev/syft_report.txt).

## Required input arguments

### `src_folder`

The name of the source code folder is required. If not set explicitly it will default to `src`.

### `docs_folder`

The name for the folder to generate docs in is required. If not set explicitly it will default to `docs`.

## Optional input arguments

### `schema_path`

The path to the AsyncAPI schema. May be either JSON or YML.

### `cloudformation_path`

The path to the CloudFormation JSON. For Serverless Framework, this is typically `.serverless/cloudformation-template-update-stack.json`. This is required for the `cfn-diagram` step to run.

### `catalogist_endpoint`

The Catalogist endpoint URL may be optionally set. This is required for the `catalogist` step to run.

### `catalogist_api_key`

The Catalogist API key may be optionally set. This is required for the `catalogist` step to run.

### `cloudflare_account_id`

The Cloudflare account ID may be optionally set.

This is required for both the Cloudflare publishing step and `eventcatalog` rebuild trigger to run.

### `cloudflare_auth_token`

The Cloudflare authentication token may be optionally set.

This is required for both the Cloudflare publishing step and `eventcatalog` rebuild trigger to run.

### `cloudflare_project_name`

The Cloudflare Pages project name for your docs site may be optionally set.

This is required for the Cloudflare publishing step to run.

### `cloudflare_catalog_name`

The Cloudflare Pages project name for your [eventcatalog](https://www.eventcatalog.dev) may be optionally set.

This is required to trigger a rebuild of your `eventcatalog` instance.

## Example of how to use this action in a workflow

The below example is setting all optional fields in order to get all the benefits and features of Documentarian. This will use the default paths for source code folder (`src`) and docs output folder (`docs`).

```yml
on: [push]

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Publish docs
        uses: mikaelvesavuori/documentarian-action@v1.0.1
        with:
          schema_path: "api/schema.json"
          cloudformation_path: ".serverless/cloudformation-template-update-stack.json"
          catalogist_endpoint: ${{ secrets.CATALOGIST_ENDPOINT }}
          catalogist_api_key: ${{ secrets.CATALOGIST_API_KEY }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          cloudflare_auth_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_project_name: "my-project-site-name"
          cloudflare_catalog_name: "my-eventcatalog-site-name"
```
