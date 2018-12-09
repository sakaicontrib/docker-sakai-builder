#!/usr/bin/env bash

cd $(dirname "${0}") > /dev/null
BASEDIR=$(pwd -L)
cd - > /dev/null

WORK="${BASEDIR}/work"
# Where tomcat files will be
TOMCAT="${WORK}/tomcat"
# Where files will be deployed
DEPLOY="${TOMCAT}/deploy"

echo $WORK $TOMCAT $DEPLOY
docker rm sakai-tomcat -f; docker run -d --name=sakai-tomcat \
    -p 8080:8080 -p 8089:8089 -p 9080:9080 \
    -e "CATALINA_BASE=/usr/src/app/deploy" \
    -e "JAVA_OPTS=-server -d64 -Xms1g -Xmx2g -Djava.awt.headless=true -XX:+UseCompressedOops -XX:+UseConcMarkSweepGC -XX:+DisableExplicitGC -Dhttp.agent=Sakai -Dorg.apache.jasper.compiler.Parser.STRICT_QUOTE_ESCAPING=false” -Dsakai.home=/usr/src/app/deploy/sakai/ -Duser.timezone=US/Eastern -Dsakai.cookieName=SAKAI2SESSIONID -Dsakai.demo=true -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=8089 -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false" \
    -e "JPDA_ADDRESS=9080" \
    -v "${DEPLOY}:/usr/src/app/deploy" \
    -v "${TOMCAT}/sakaihome:/usr/src/app/deploy/sakai" \
    -v "${TOMCAT}/catalina_base/bin:/usr/src/app/deploy/bin" \
    -v "${TOMCAT}/catalina_base/conf:/usr/src/app/deploy/conf" \
    -v "${TOMCAT}/catalina_base/webapps/ROOT:/usr/src/app/deploy/webapps/ROOT" \
    -u `id -u`:`id -g` \
    --link sakai-mysql:mysql \
    tomcat:9.0-jre8-alpine \
    /usr/local/tomcat/bin/catalina.sh jpda run
