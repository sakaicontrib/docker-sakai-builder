#!/usr/bin/env bash

cd $(dirname "${0}") > /dev/null
BASEDIR=$(pwd -L)
cd - > /dev/null

WORK="${BASEDIR}/work"
# Where tomcat files will be
TOMCAT="${WORK}/tomcat"
# Where files will be deployed
DEPLOY="${TOMCAT}/deploy"

# If docker creates this directory it does it as the wrong user, so create it first
# These are on the host so they can be re-used between builds
mkdir -p "$DEPLOY"
mkdir -p "$WORK/.m2"
mkdir -p "$WORK/.npm"
mkdir -p "$WORK/.config"
mkdir -p "$WORK/.cache"

# Now build the code
docker run --rm -it --name sakai-build \
    -e "MAVEN_OPTS=-XX:+TieredCompilation -XX:TieredStopAtLevel=1" \
    -e "MAVEN_CONFIG=/tmp/.m2" \
    -v "${DEPLOY}:/usr/src/deploy" \
    -v "${WORK}/.m2:/tmp/.m2" \
    -v "${WORK}/.npm:/.npm" \
    -v "${WORK}/.config:/.config" \
    -v "${WORK}/.cache:/.cache" \
    -v "${PWD}:/usr/src/app" \
    -u `id -u`:`id -g` \
    -w /usr/src/app sakai:build \
    /bin/bash -c "mvn -T 1C -B -P mysql clean install sakai:deploy -Dmaven.test.skip=true -Dmaven.tomcat.home=/usr/src/deploy -Dsakai.cleanup=true -Duser.home=/tmp/" 
