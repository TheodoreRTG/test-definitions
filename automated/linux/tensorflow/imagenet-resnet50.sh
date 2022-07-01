#!/bin/bash
# shellcheck disable=SC1091

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
source ./tensorflow-utils.sh

HOME_DIR='/home/debiand05'
TEST_GIT_URL="https://github.com/mlcommons/inference.git"
TEST_DIR="${HOME_DIR}/src/${TEST_PROGRAM}"
TEST_PROG_VERSION="215c057fc6690a47f3f66c72c076a8f73d66cb12"
TEST_PROGRAM="inference"
MNT_DIR='/mnt'
MNT_EXISTS=true

usage() {
    echo "Usage: $0 [-a <home-directory>]
                    [-m <mount-directory>]
                    [-t <true|false>]
                    [-p <test-dir>]
                    [-v <test-prog-version>]
                    [-u <test-git-url>]
                    [-s <true|false>]" 1>&2
    exit 1
}

while getopts "a:m:t:s:p:v:u:" o; do
    case "$o" in
        a) export HOME_DIR="${OPTARG}";;
        m) MNT_DIR="${OPTARG}" ;;
        t) MNT_EXISTS="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        p) export TEST_DIR="${OPTARG}" ;;
        v) export TEST_PROG_VERSION="${OPTARG}" ;;
        u) export TEST_GIT_URL="${OPTARG}" ;;
        *) usage ;;
    esac
done

pkgs="build-essential git python3-venv python3-dev libhdf5-dev pkg-config curl"
install_deps "${pkgs}" "${SKIP_INSTALL}"
create_out_dir "${OUTPUT}"
rm -rf "${HOME_DIR}"/tf_venv
rm -rf "${HOME_DIR}"/src
rm -rf "${MNT_DIR}"/datasets
mkdir "${HOME_DIR}"/tf_venv
pushd "${HOME_DIR}"/tf_venv || exit
python3 -m venv .
source bin/activate
popd || exit

if [[ "${SKIP_INSTALL}" = *alse ]]; then
    pushd "${HOME_DIR}"/tf_venv || exit
    python -m pip install --upgrade pip wheel
    python -m pip install h5py
    python -m pip install cython
    python -m pip install google protobuf==3.20.1
    python -m pip install --no-binary pycocotools pycocotools
    python -m pip install absl-py pillow
    python -m pip install --extra-index-url https://snapshots.linaro.org/ldcg/python-cache/ numpy==1.19.5
    python -m pip install --extra-index-url https://snapshots.linaro.org/ldcg/python-cache/ matplotlib
    python -m pip install ck
    ck pull repo:ck-env
    python -m pip install scikit-build
    python -m pip install --extra-index-url https://snapshots.linaro.org/ldcg/python-cache/ tensorflow-io-gcs-filesystem==0.24.0 h5py==3.1.0
    python -m pip install tensorflow-aarch64==2.7.0
    popd || exit
    mkdir "${HOME_DIR}"/src
    echo "${TEST_PROG_VERSION}"
    echo -d "${TEST_DIR}"
    get_test_program "${TEST_GIT_URL}" "${TEST_DIR}" "${TEST_PROG_VERSION}" "${TEST_PROGRAM}"
    ls -l
    git checkout 215c057fc6690a47f3f66c72c076a8f73d66cb12
    ls "${HOME_DIR}"/src/"${TEST_PROGRAM}" || exit
    python setup.py develop
    popd || exit
    if [[ "${MNT_EXISTS}" = *alse ]]; then
        get_dataset_imagenet_resnet50
    fi
fi

pushd "${HOME_DIR}"/src/inference/vision/classification_and_detection/ || exit
python setup.py develop

if [[ "${MNT_EXISTS}" = *rue ]]; then
    mkdir "${MNT_DIR}"/datasets
    mount -t nfs 10.40.96.10:/mnt/nvme "${MNT_DIR}"
    export DATA_DIR="${MNT_DIR}"/data/CK-TOOLS/dataset-imagenet-ilsvrc2012-val-min
    export MODEL_DIR="${MNT_DIR}"/datasets/data/models
fi

./run_local.sh tf resnet50
popd || exit