#!/bin/bash
podman build -t pynguin-sx -f ./Dockerfile --build-arg "CACHEBUST=$(date +%s)"
podman build -t pynguin-hmx -f ./Dockerfile --build-arg "CACHEBUST=$(date +%s)" --build-arg "INJECT=crossover.py:/usr/local/lib/python3.10/site-packages/pynguin/ga/operators/crossover.py"
