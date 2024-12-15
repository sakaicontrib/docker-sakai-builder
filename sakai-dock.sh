#!/usr/bin/env bash
# Script to build, deploy and run Sakai in docker containers
# TODO Provide option for cleaning up these instances

# Set up some options, TODO make these configurable (pull from the environment if it's set)

# Whether or not to set wicket debug mode on
# This should either be development or deployment
WICKET_CONFIG="development"

# Number of threads, might need to change this for debuggging
THREADS=1C

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

# Which maven container to use
MAVEN_IMAGE="markhobson/maven-chrome:jdk-17"

# Any extra options to pass to maven
MVN_EXTRA_OPTS="-Dmaven.plugin.validation=DEFAULT"

PROXY_IMAGE="esplo/docker-local-ssl-termination-proxy"

# This defaults to detroit timezone. Make this configurable
TIMEZONE="America/Detroit"

echo "WORK:$WORK TOMCAT:$TOMCAT DEPLOY:$DEPLOY WICKET_CONFIG:$WICKET_CONFIG"

CATALINA_OPTS="-server \
               -Djava.awt.headless=true \
               -XX:+UseCompressedOops \
               -XX:+AlwaysPreTouch \
               -XX:+DisableExplicitGC \
               -Djava.net.preferIPv4Stack=true"

CATALINA_OPTS="$CATALINA_OPTS -Dorg.apache.jasper.compiler.Parser.STRICT_QUOTE_ESCAPING=false"

# Jasper config
CATALINA_OPTS="$CATALINA_OPTS -Dorg.apache.jasper.compiler.Parser.STRICT_QUOTE_ESCAPING=false"

# Enable Sakai demo mode
CATALINA_OPTS="$CATALINA_OPTS -Dsakai.demo=true"

# Sets the http agent
CATALINA_OPTS="$CATALINA_OPTS -Dhttp.agent=Sakai"

# Timezone some examples for the U.S.:  US/Eastern, US/Central, US/Mountain, US/Pacific, US/Arizona
CATALINA_OPTS="$CATALINA_OPTS -Duser.timezone=US/Eastern"

# Sets the cookie name
CATALINA_OPTS="$CATALINA_OPTS -Dsakai.cookieName=SAKAIID"

#Skip scanning serializer.jar
CATALINA_OPTS="$CATALINA_OPTS -Dtomcat.util.scan.StandardJarScanFilter.jarsToSkip=serializer.jar"

# Opts from SAK-33595 indicated for JDK11
JAVA_OPTS="--add-opens=java.base/jdk.internal.access=ALL-UNNAMED \
        --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
        --add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
        --add-opens=java.base/sun.util.calendar=ALL-UNNAMED \
        --add-opens=java.management/com.sun.jmx.mbeanserver=ALL-UNNAMED \
        --add-opens=jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED \
        --add-opens=java.base/sun.reflect.generics.reflectiveObjects=ALL-UNNAMED \
        --add-opens=jdk.management/com.sun.management.internal=ALL-UNNAMED \
        --add-opens=java.base/java.io=ALL-UNNAMED \
        --add-opens=java.base/java.nio=ALL-UNNAMED \
        --add-opens=java.base/java.net=ALL-UNNAMED \
        --add-opens=java.base/java.util=ALL-UNNAMED \
        --add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
        --add-opens=java.base/java.util.concurrent.locks=ALL-UNNAMED \
        --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED \
        --add-opens=java.base/java.lang=ALL-UNNAMED \
        --add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
        --add-opens=java.base/java.math=ALL-UNNAMED \
        --add-opens=java.sql/java.sql=ALL-UNNAMED \
        --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
        --add-opens=java.base/java.time=ALL-UNNAMED \
        --add-opens=java.base/java.text=ALL-UNNAMED \
        --add-opens=java.management/sun.management=ALL-UNNAMED \
        --add-opens=java.desktop/java.awt.font=ALL-UNNAMED \
        --add-opens=java.desktop/javax.swing.tree=ALL-UNNAMED"

JAVA_DEBUG_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=8089 -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false" 

container_check_and_rm() {
    local CONTAINER_NAME=$1
    local CONTAINER_ID=$(docker inspect --format="{{.Id}}" ${CONTAINER_NAME} 2> /dev/null)

    if [[ "${CONTAINER_ID}" ]]; then
        echo "${CONTAINER_NAME} exists, removing previous instance"
    	docker stop ${CONTAINER_NAME} > /dev/null && docker rm ${CONTAINER_NAME} > /dev/null
    fi
}

start_proxy() {
    # Startup the https proxy first
    container_check_and_rm "docker-local-ssl-termination-proxy"
    docker run -d -e "HOST_IP=127.0.0.1" -e "PORT=8080" -p 443:443 --name="docker-local-ssl-termination-proxy" --rm ${PROXY_IMAGE}
}

start_tomcat() {
    container_check_and_rm "sakai-tomcat"
	docker run -d --name="sakai-tomcat" --pull always \
	    -p 8080:8080 -p 8089:8089 -p 8000:8000 -p 8025:8025 \
	    -e "CATALINA_BASE=/usr/src/app/deploy" \
	    -e "CATALINA_TMPDIR=/tmp" \
        -e "CATALINA_OPTS=${CATALINA_OPTS}" \
	    -e "JAVA_OPTS=-Xms2g -Xmx2g -Dsakai.home=/usr/src/app/deploy/sakai/ ${JAVA_DEBUG_OPTS} -Dwicket.configuration=${WICKET_CONFIG} ${JAVA_OPTS}" \
	    -e "JPDA_ADDRESS=*:8000" \
	    -v "${DEPLOY}:/usr/src/app/deploy" \
	    -v "${SAKAIHOME}:/usr/src/app/deploy/sakai" \
	    -v "${TOMCAT}/catalina_home/bin:/usr/src/app/deploy/bin" \
	    -v "${TOMCAT}/catalina_home/conf:/usr/src/app/deploy/conf" \
	    -v "${TOMCAT}/deploy/webapps/ROOT:/usr/src/app/deploy/webapps/ROOT" \
	    -u `id -u`:`id -g` \
	    --link sakai-mariadb \
	    tomcat:9-jdk17-temurin \
	    /usr/local/tomcat/bin/catalina.sh jpda run || docker start "sakai-tomcat"
}

start_mariadb() {
	mkdir -p "${WORK}/mysql/data"
    container_check_and_rm "sakai-mariadb"

	# May want to include an opt for docker rm sakai-mariadb
	# Start it if we've already created it, unless we want to re-create
	docker run -p 127.0.0.1:53306:3306 -d --name="sakai-mariadb" --pull always \
	    -e "MARIADB_ROOT_PASSWORD=sakairoot" \
	    -v "${WORK}/mysql/scripts:/docker-entrypoint-initdb.d" \
	    -v "${WORK}/mysql/data:/var/lib/mysql" \
	    -u `id -u`:`id -g` \
	    -d mariadb:10 --lower-case-table-names=1 || docker start "sakai-mariadb"
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
	mkdir -p "$DEPLOY/lib"
	mkdir -p "$WORK/.m2"
	mkdir -p "$WORK/.npm"
	mkdir -p "$WORK/.config"
	mkdir -p "$WORK/.cache"

	# Copy the p6spy files into the lib directory
	cp ${BASEDIR}/p6spy/p6spy-3.9.1.jar ${BASEDIR}/p6spy/spy.properties ${DEPLOY}/lib

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
		--cap-add=SYS_ADMIN \
	    -w /usr/src/app ${MAVEN_IMAGE} \
	    /bin/bash -c "mvn -T ${THREADS} -B ${UPDATES} clean install ${SAKAI_DEPLOY} -Dmaven.test.skip=${MAVEN_TEST_SKIP} -Djava.awt.headless=true -Dmaven.tomcat.home=/usr/src/deploy -Dsakai.cleanup=true -Duser.home=/tmp/ ${MVN_EXTRA_OPTS}"
}

clean_deploy() {
	rm -rf $DEPLOY
}

clean_data() {
	rm -rf ${WORK}/mysql/data
	rm -rf ${SAKAIHOME}/samigo
	rm -rf ${SAKAIHOME}/ignite
}

kill_all() {
	docker kill sakai-tomcat sakai-mariadb
	docker rm sakai-tomcat sakai-mariadb
}

# Turn off command echo
set +x

# Defaults
SAKAI_DEPLOY="sakai:deploy-exploded"
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
    proxy)
        start_proxy;;
    mysql)
    	start_mariadb;;
    mariadb)
        start_mariadb;;
    build)
    	maven_build;;
    clean_deploy)
    	clean_deploy;;
    clean_data)
    	clean_data;;
    bash)
	start_bash;;
    kill)
    	kill_all;;
    *)  
echo "Usage $0
    - mysql or mariadb (Starts MariaDB)
    - tomcat (Starts tomcat)
    - proxy (Starts a 443 proxy to test proxy related things). Need to set force.url.secure=443 in work/tomcat/sakaihome/sakai.properties.
    - build (Build and deploy sakai tool to tomcat)
        By Default tests are skipped AND the artifacts are deployed
        ** Add options after (just currently for build) 
        -t (Don't skip tests)
        -d (Don't deploy to tomcat)
        -U (Force updates)
        -c (Use custom maven image)
    - kill (Stop all instances) 
    - clean_deploy (Clean the deploy directory)
    - clean_data (Clean the database directory)
    - bash (Starts a debugging shell"
exit 1
esac	
