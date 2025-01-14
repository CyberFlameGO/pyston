#!/bin/bash
set -e
VERSION=2.3
OUTPUT_DIR=${PWD}/release/${VERSION}

PARALLEL=
RELEASES=
while [[ $# -gt 0 ]]; do
    case $1 in
        -j)
            PARALLEL=1
            shift
            ;;
        *)
            RELEASES="$RELEASES $1"
            shift
            ;;
    esac
done

if [ -z "$RELEASES" ]; then
    RELEASES="16.04 18.04 20.04"

    if [ -d $OUTPUT_DIR ]
    then
        echo "Directory $OUTPUT_DIR already exists";
        exit 1
    fi
fi

mkdir -p $OUTPUT_DIR


function make_release {
    DIST=$1

    echo "Creating $DIST release"
    docker build -f pyston/Dockerfile.$DIST -t pyston-build:$DIST .
    docker run -iv${PWD}/release/$VERSION:/host-volume --rm --cap-add SYS_ADMIN pyston-build:$DIST sh -s <<EOF
set -ex
ln -sf /usr/lib/linux-tools/*/perf /usr/bin/perf
make package -j`nproc`
make pyston/build/release_env/bin/python3
pyston/build/release_env/bin/python3 pyston/tools/make_portable_dir.py pyston_${VERSION}_amd64.deb pyston_${VERSION}_${DIST}
chown -R $(id -u):$(id -g) pyston_${VERSION}_amd64.deb
chown -R $(id -u):$(id -g) pyston_${VERSION}_${DIST}
cp -ar pyston_${VERSION}_amd64.deb /host-volume/pyston_${VERSION}_${DIST}.deb
cp -ar pyston_${VERSION}_${DIST} /host-volume/pyston_${VERSION}_${DIST}
# create archive of portable dir
cd /host-volume/pyston_${VERSION}_${DIST}
tar -czf ../pyston_${VERSION}_${DIST}.tar.gz *
EOF
    docker image rm pyston-build:$DIST
}

for DIST in $RELEASES
do
    if [ -n "$PARALLEL" ]; then
        make_release $DIST &
    else
        make_release $DIST
    fi
done
wait

ln -sf $OUTPUT_DIR/pyston_${VERSION}_16.04.tar.gz $OUTPUT_DIR/pyston_${VERSION}_portable.tar.gz

echo "FINISHED: wrote release to $OUTPUT_DIR"
