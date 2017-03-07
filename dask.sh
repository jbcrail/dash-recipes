#!/usr/bin/env bash

SRC=https://github.com/dask/dask
NAME=`basename ${SRC}`
ENV=${NAME}-`cat /dev/urandom | base64 | head -c 4`
DOCSET=Dask
VERSION=0.14.0

REPO_DIR=`pwd`/repos/${NAME}
DOCSET_DIR=`pwd`/docsets/${NAME}
DOCS_DIR=${REPO_DIR}/docs

section()
{
  GREEN='\033[0;32m'
  NC='\033[0m'
  printf "[${GREEN}${1}${NC}]\n"
}

section "Clone repository" & {
  rm -rf ${REPO_DIR}
  git clone -q ${SRC} ${REPO_DIR}
  cd ${REPO_DIR}
  git checkout ${VERSION}
}

section "Create conda environment" & {
  conda create --yes --quiet -n ${ENV} python
  source activate ${ENV}
}

section "Install dependencies" & {
  pip install --quiet --no-deps -e .[complete]
  pip install --quiet -r docs/requirements-docs.txt
  pip install --quiet doc2dash
  pip install --quiet docutils==0.12 # Temporary downgrade to resolve build error
}

section "Build documentation" & {
  cd ${DOCS_DIR}
  make html
}

section "Build docset" & {
  mkdir -p ${DOCSET_DIR}
  doc2dash --quiet -n ${DOCSET} --enable-js -d ${DOCSET_DIR} -I index.html build/html
}

section "Build icons" & {
  mogrify -format png -size 16x16 -write ${DOCSET_DIR}/icon.png source/images/dask_icon.svg
  mogrify -format png -size 32x32 -write ${DOCSET_DIR}/icon@2x.png source/images/dask_icon.svg
}

section "Write docset metadata" & {
  cat <<EOF >${DOCSET_DIR}/README.md
${DOCSET} Dash Docset
=====

- Docset Description:
    - "Versatile parallel programming with task scheduling".

- Docset Author:
    - [Joseph Crail](https://github.com/jbcrail)
EOF

  cat <<EOF >${DOCSET_DIR}/docset.json
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
  cd ${DOCSET_DIR}
  tar --exclude='.DS_Store' -czf ${DOCSET}.tgz ${DOCSET}.docset
  rm -rf ${DOCSET}.docset
}

section "Cleanup" & {
  source deactivate ${ENV}
  conda env remove --yes --quiet -n ${ENV}
}
