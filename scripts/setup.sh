#!/bin/bash
python3.10 -m pip install pynguin
python3.10 -m pip install -r projects.txt

python3.10 -m pip download --no-deps -r ./projects.txt -d ./downloaded/

mkdir -p ./extracted/

for f in ./downloaded/*.whl; do
    unzip $f -x "*[0-9].[0-9]*" -x "*test*" -x "*example*" -fo -d ./extracted/
done

for f in ./downloaded/*.tar.gz; do
    tar -xzf $f -C ./extracted/ --wildcards "*/*/*" --exclude "*/*.egg-info/*" --strip-components=1
done
