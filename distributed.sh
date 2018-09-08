#!/usr/bin/env bash

SRC=https://github.com/dask/distributed
NAME=$(basename ${SRC})
ENV=${NAME}-$(cat < /dev/urandom | base64 | head -c 4)
DOCSET=Distributed
VERSION=1.23.1

REPO_DIR=$(pwd)/repos/${NAME}
DOCSET_DIR=$(pwd)/docsets/${NAME}
DOCS_DIR=${REPO_DIR}/docs

section()
{
  GREEN='\033[0;32m'
  NC='\033[0m'
  printf "[%s%s%s]\\n" "${GREEN}" "${1}" "${NC}"
}

section "Clone repository" & {
  rm -rf "${REPO_DIR}"
  git clone -q ${SRC} "${REPO_DIR}"
  cd "${REPO_DIR}" || exit
  git checkout ${VERSION}
}

section "Create conda environment" & {
  conda create --yes --quiet -n "${ENV}" python=3
  source activate "${ENV}"
}

section "Install doc2dash" & {
  conda install --yes --quiet lxml=3.8.0  # required by doc2dash 2.2.0

  pip install --upgrade pip
  pip install --quiet doc2dash
}

section "Install dependencies" & {
  pip install --quiet --no-deps -e ".[complete]"
  conda install --yes --quiet --file docs/requirements.txt
  conda install --yes --quiet cython
}

section "Build documentation" & {
  cd "${DOCS_DIR}" || exit
  make html
}

section "Build docset" & {
  rm -rf "${DOCSET_DIR}"
  mkdir -p "${DOCSET_DIR}"
  doc2dash --quiet -n ${DOCSET} --enable-js -d "${DOCSET_DIR}" -I index.html build/html
}

section "Write docset metadata" & {
  cat <<EOF >"${DOCSET_DIR}/README.md"
${DOCSET} Dash Docset
=====

- Docset Description:
    - "A library for distributed computation".

- Docset Author:
    - [Joseph Crail](https://github.com/jbcrail)
EOF

  cat <<EOF >"${DOCSET_DIR}/docset.json"
{
  "name": "${DOCSET}",
  "version": "${VERSION}",
  "archive": "${DOCSET}.tgz",
  "author": {
    "name": "Joseph Crail",
    "link": "https://github.com/jbcrail"
  },
  "aliases": ["task-scheduling parallelism"]
}
EOF
}

section "Archive docset" & {
  cd "${DOCSET_DIR}" || exit
  tar --exclude='.DS_Store' -czf ${DOCSET}.tgz ${DOCSET}.docset
  rm -rf ${DOCSET}.docset
}

section "Cleanup" & {
  source deactivate $"{ENV}"
  conda env remove --yes --quiet -n "${ENV}"
}
