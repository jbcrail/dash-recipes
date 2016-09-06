#!/usr/bin/env bash

SRC=https://github.com/bokeh/bokeh
NAME=`basename ${SRC}`
ENV=${NAME}-`cat /dev/urandom | base64 | head -c 4`
DOCSET=Bokeh
VERSION=0.12.1

REPO_DIR=`pwd`/repos/${NAME}
DOCSET_DIR=`pwd`/docsets/${NAME}
DOCS_DIR=${REPO_DIR}/sphinx

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
  cd ${REPO_DIR}
  conda config --add channels bokeh
  conda install --yes --quiet conda-build jinja2
  conda install bokeh --use-local --yes
  conda install --yes --quiet nodejs
  pip install --quiet doc2dash
}

section "Build documentation" & {
  conda install --yes --quiet -c bokeh sphinx seaborn pyyaml ggplot

  # Localize remote assets
  cd ${DOCS_DIR}
  sed -i "" "s|//{{ css_server }}/theme/css/main.css|{{ pathto('_static/main.css', 1) }}|" source/bokeh_theme/layout.html
  sed -i "" "s|//ajax.googleapis.com/ajax/libs/jquery/2.1.1/jquery.min.js|{{ pathto('_static/jquery.min.js', 1) }}|" source/bokeh_theme/layout.html

  cd ${DOCS_DIR}
  make all

  # Download remote assets
  cd ${DOCS_DIR}/_build/html/_static
  curl --silent -O http://bokehplots.com/theme/css/main.css
  curl --silent -O http://ajax.googleapis.com/ajax/libs/jquery/2.1.1/jquery.min.js

  # Redirect location of static assets
  cd ${DOCS_DIR}/_build/html/
  rm -f static
  ln -s _static static
}

section "Build docset" & {
  mkdir -p ${DOCSET_DIR}
  doc2dash --quiet -n ${DOCSET} --enable-js -d ${DOCSET_DIR} -I index.html ${DOCS_DIR}/_build/html
}

section "Build icons" & {
  cd ${DOCS_DIR}
  mogrify -resize 16x16 -write ${DOCSET_DIR}/icon.png source/bokeh_theme/static/images/logo.png
  mogrify -resize 32x32 -write ${DOCSET_DIR}/icon@2x.png source/bokeh_theme/static/images/logo.png
}

section "Write docset metadata" & {
  cat <<EOF >${DOCSET_DIR}/README.md
${DOCSET} Dash Docset
=====

- Docset Description:
    - "Bokeh is a Python interactive visualization library that targets modern web browsers for presentation".

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
  "aliases": ["Python interactive visualization library",
              "Bokeh Scientific plots",
              "web browser visualization"
              ]
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
