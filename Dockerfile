FROM alpine:3.16 AS base

# Set variables
ENV CI=1
ENV BASE_FOLDER=/github/workspace
ENV TEMP_FOLDER=/temp

# Fetch Alpine dependencies
RUN apk update && apk upgrade && apk add bash curl wget git nodejs npm graphviz

# Fetch package dependencies
FROM base as dependencies
RUN curl -fsSL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

FROM dependencies as ci
COPY script.sh /script.sh
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENTRYPOINT ["/script.sh"]

# For local test use
#COPY script.sh $BASE_FOLDER/script.sh
#WORKDIR $BASE_FOLDER
#ENTRYPOINT ["/bin/bash"]
