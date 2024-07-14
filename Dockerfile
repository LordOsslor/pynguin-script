FROM python:3.10.14-slim-bullseye

RUN apt-get update && apt-get -y upgrade
RUN apt-get install unzip

RUN mkdir -p /work/
WORKDIR /work/

# Copy stuff needed for setup
COPY requirements.txt ./
COPY setup.sh ./
COPY pynguin.sh ./
COPY iter_modules.py ./

RUN chmod +x setup.sh
RUN chmod +x pynguin.sh

# Run setup
RUN ./setup.sh

# Fix debug spam
RUN grep -rl "logging.getLogger(__name__)" \
    "/usr/local/lib/python3.10/site-packages/pynguin" | xargs sed -io \
    's/^\(\s*\)\(..*\) = \(logging.getLogger(__name__)\)/\1\2 = \3\n\1\2.setLevel(logging.INFO)/'

# Generate modulenames.txt in build dir
RUN --mount=type=bind,source=.,target=/build_dir,rw=True python3.10 iter_modules.py ./extracted/ 1 > /build_dir/modulenames.txt 

# Clean up
RUN rm requirements.txt
RUN rm setup.sh
RUN rm iter_modules.py

# Create directories
RUN mkdir -p prison
RUN mkdir -p output

ENV PYNGUIN_DANGER_AWARE=True

ENTRYPOINT [ "./pynguin.sh" ]