#!/usr/bin/env bash
# Script to build, deploy and run Sakai in docker containers
# TODO Provide option for cleaning up these instances

# Set up some options, TODO make these configurable

# Whether or not to set wicket debug mode on
# This should either be development or deployment
WICKET_CONFIG="development"

# Number of threads, might need to change this for debuggging
THREADS=C1

cd $(dirname "${0}") > /dev/null
BASEDIR=$(pwd -L)
cd - > /dev/null

WORK="${BASEDIR}/work"
# Where tomcat files will be
TOMCAT="${WORK}/tomcat"
# Where files will be deployed
DEPLOY="${TOMCAT}/deploy"
# Sakai home filse
SAKAIHOME="${TOMCAT}/sakaihome"

# Which maven image to use
MAVEN_IMAGE="maven:3.6.3-jdk-8-slim"

echo "WORK:$WORK TOMCAT:$TOMCAT DEPLOY:$DEPLOY WICKET_CONFIG:$WICKET_CONFIG"

start_tomcat() {
	docker stop sakai-tomcat && docker rm sakai-tomcat
	docker run -d --name=sakai-tomcat \
	    -p 8080:8080 -p 8089:8089 -p 8000:8000 \
	    -e "CATALINA_BASE=/usr/src/app/deploy" \
	    -e "CATALINA_TMPDIR=/tmp" \
	    -e "JAVA_OPTS=-server -d64 -Xms1g -Xmx2g -Djava.awt.headless=true -XX:+UseCompressedOops -XX:+UseConcMarkSweepGC -XX:+DisableExplicitGC -Dhttp.agent=Sakai -Dorg.apache.jasper.compiler.Parser.STRICT_QUOTE_ESCAPING=false” -Dsakai.home=/usr/src/app/deploy/sakai/ -Duser.timezone=US/Eastern -Dsakai.cookieName=SAKAI2SESSIONID -Dsakai.demo=true -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=8089 -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dwicket.configuration=${WICKET_CONFIG}" \
	    -e "JPDA_ADDRESS=8000" \
	    -v "${DEPLOY}:/usr/src/app/deploy" \
	    -v "${SAKAIHOME}:/usr/src/app/deploy/sakai" \
	    -v "${TOMCAT}/catalina_base/bin:/usr/src/app/deploy/bin" \
	    -v "${TOMCAT}/catalina_base/conf:/usr/src/app/deploy/conf" \
	    -v "${TOMCAT}/catalina_base/webapps/ROOT:/usr/src/app/deploy/webapps/ROOT" \
	    -u `id -u`:`id -g` \
	    --link sakai-mysql:mysql \
	    tomcat:9-jdk8 \
	    /usr/local/tomcat/bin/catalina.sh jpda run || docker start sakai-tomcat
}

start_mysql() {
	mkdir -p "${WORK}/mysql/data"
	docker stop sakai-mysql
	# May want to include an opt for docker rm sakai-mysql
	# Start it if we've already created it, unless we want to re-create
	docker run -d --name=sakai-mysql -p 53306:3306 \
	    -e "MYSQL_ROOT_PASSWORD=sakairoot" \
	    -v "${WORK}/mysql/scripts:/docker-entrypoint-initdb.d" \
	    -v "${WORK}/mysql/data:/var/lib/mysql" \
	    -u `id -u`:`id -g` \
	    -d mysql:5.7 || docker start sakai-mysql
}

# This is mostly for debugging maven/tomcat
start_bash() {
	docker run --rm -it \
	    -v "${DEPLOY}:/usr/src/deploy" \
	    -v "${WORK}/.m2:/tmp/.m2" \
	    -v "${WORK}/.npm:/.npm" \
	    -v "${WORK}/.config:/.config" \
	    -v "${WORK}/.cache:/.cache" \
	    -v "${PWD}:/usr/src/app" \
	    bash:4.4
}

maven_build() {
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
	    -w /usr/src/app ${MAVEN_IMAGE} \
	    /bin/bash -c "mvn -T ${THREADS} -B ${UPDATES} -P mysql clean install ${SAKAI_DEPLOY} -Dmaven.test.skip=${MAVEN_TEST_SKIP} -Djava.awt.headless=true -Dmaven.tomcat.home=/usr/src/deploy -Dsakai.cleanup=true -Duser.home=/tmp/"
}

clean_deploy() {
	rm -rf $DEPLOY
	rm -rf ${SAKAIHOME}/samigo
	rm -rf ${SAKAIHOME}/ignite
}

clean_mysql() {
	rm -rf ${WORK}/mysql/data
}

kill_all() {
	docker kill sakai-tomcat sakai-mysql
	docker rm sakai-tomcat sakai-mysql
}

# Turn off command echo
set +x

# Defaults
SAKAI_DEPLOY="sakai:deploy"
MAVEN_TEST_SKIP=true

COMMAND=$1; shift

while getopts "tdUc" option; do
    case "${option}" in
    t) MAVEN_TEST_SKIP=false;;
    d) SAKAI_DEPLOY="";;
    U) UPDATES="-U";;
    c) MAVEN_IMAGE="sakai:build";;
    *) echo "Incorrect options provided"; exit 1;;
    esac
done

#TODO Add some of these options (deploy, test skip, etc) as options
case "$COMMAND" in
    tomcat)
	    start_tomcat;;
    mysql)
    	start_mysql;;
    build)
    	maven_build;;
    clean_deploy)
    	clean_deploy;;
    clean_mysql)
    	clean_mysql;;
    bash)
	start_bash;;
    kill)
    	kill_all;;
    *)  
        echo "
        Usage $0
        mysql (Starts MySQL)
        tomcat (Starts tomcat)
        build (Build and deploy sakai tool to tomcat)
            By Default tests are skipped AND the artifacts are deployed
            ** Add options after (just currently for build) 
            -t (Don't skip tests)
            -d (Don't deploy to tomcat)
	    -U (Force updates)
	    -c (Use custom maven image)
        kill (Stop all instances) 
        clean_deploy (Clean the deploy directory)
        clean_mysql (Clean the mysql directory
        bash (Starts a debugging shell"
        exit 1
esac	
