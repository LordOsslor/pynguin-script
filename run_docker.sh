Name=$(id -un)
ID=$(id -u)
GName=$(id -gn)
GID=$(id -g)


sudo docker run -it --cpus 10 -m 12G --mount type=bind,source=.,target=/pynguin python:3.10.14-slim-bullseye bash -c "apt update && apt install unzip && groupadd -g $GID $GName && useradd $Name -u $ID -g $GID && cd /pynguin && su $Name -c \"PYNGUIN_DANGER_AWARE=1 ./run.sh run\" | tee -ap log.txt"
