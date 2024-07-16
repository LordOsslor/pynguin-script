#!/bin/bash
podman build -t pynguin-sx -f ./Dockerfile --build-arg "CACHE_BUST=$(date +%s)"
podman build -t pynguin-hmx -f ./Dockerfile --build-arg "CACHE_BUST=$(date +%s)" --build-arg "INJECT=crossover.py:/usr/local/lib/python3.10/site-packages/pynguin/ga/operators/crossover.py,variablereference.py:/usr/local/lib/python3.10/site-packages/pynguin/testcase/variablereference.py"
