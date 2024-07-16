FROM python:3.10.14-slim-bullseye

RUN apt-get update && apt-get -y upgrade
RUN apt-get install unzip

# Set up work dir
RUN mkdir -p /work/
WORKDIR /work/

# Run setup
COPY requirements.txt ./
COPY setup.sh ./
RUN chmod +x setup.sh

RUN ./setup.sh

# Inject files
ARG INJECT=""
COPY inject.sh ./
RUN chmod +x inject.sh

RUN --mount=type=bind,source=.,target=/build_dir ./inject.sh ${INJECT}

# Fix debug spam
ARG DEBUG_FIX="true"
RUN if [ "${DEBUG_FIX}" = "true"  ]; then \
    grep -rl "logging.getLogger(__name__)" \
    "/usr/local/lib/python3.10/site-packages/pynguin" \
    | xargs sed -io \
    's/^\(\s*\)\(..*\) = \(logging.getLogger(__name__)\)/\1\2 = \3\n\1\2.setLevel(logging.INFO)/'; \
    fi

# Generate modulenames.txt in build dir
ARG SEARCH_DEPTH="1"
COPY iter_modules.py ./
RUN --mount=type=bind,source=.,target=/build_dir,rw=True python3.10 \
    iter_modules.py ./extracted/ ${SEARCH_DEPTH} > /build_dir/modulenames${SEARCH_DEPTH}.txt 

# Acknowledge danger
ENV PYNGUIN_DANGER_AWARE=True

# Copy entry script
COPY pynguin.sh ./
RUN chmod +x pynguin.sh

# Create directories used at run time
RUN mkdir -p prison
RUN mkdir -p output

# ENTRYPOINT [ "./pynguin.sh" ]