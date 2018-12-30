#!/usr/bin/env bash
# Script to build, deploy and run Sakai in docker containers
# TODO Provide option for cleaning up these instances

cd $(dirname "${0}") > /dev/null
BASEDIR=$(pwd -L)
cd - > /dev/null

WORK="${BASEDIR}/work"
# Where tomcat files will be
TOMCAT="${WORK}/tomcat"
# Where files will be deployed
DEPLOY="${TOMCAT}/deploy"

echo "WORK:$WORK TOMCAT:$TOMCAT DEPLOY:$DEPLOY"


start_tomcat() {
	docker stop sakai-tomcat && docker rm sakai-tomcat
	docker run -d --name=sakai-tomcat \
	    -p 8080:8080 -p 8089:8089 -p 8000:8000 \
	    -e "CATALINA_BASE=/usr/src/app/deploy" \
	    -e "JAVA_OPTS=-server -d64 -Xms1g -Xmx2g -Djava.awt.headless=true -XX:+UseCompressedOops -XX:+UseConcMarkSweepGC -XX:+DisableExplicitGC -Dhttp.agent=Sakai -Dorg.apache.jasper.compiler.Parser.STRICT_QUOTE_ESCAPING=false” -Dsakai.home=/usr/src/app/deploy/sakai/ -Duser.timezone=US/Eastern -Dsakai.cookieName=SAKAI2SESSIONID -Dsakai.demo=true -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=8089 -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.io.tmpdir=/tmp" \
	    -e "JPDA_ADDRESS=8000" \
	    -v "${DEPLOY}:/usr/src/app/deploy" \
	    -v "${TOMCAT}/sakaihome:/usr/src/app/deploy/sakai" \
	    -v "${TOMCAT}/catalina_base/bin:/usr/src/app/deploy/bin" \
	    -v "${TOMCAT}/catalina_base/conf:/usr/src/app/deploy/conf" \
	    -v "${TOMCAT}/catalina_base/webapps/ROOT:/usr/src/app/deploy/webapps/ROOT" \
	    -u `id -u`:`id -g` \
	    --link sakai-mysql:mysql \
	    tomcat:9.0-jre8-alpine \
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
	    -d mysql:5.6 || docker start sakai-mysql
}

if [ "$1" = "tomcat" ]; then
	start_tomcat
elif [ "$1" = "mysql" ]; then
	start_mysql	
else
	echo "Must specify mysql or tomcat as arguments"
	exit
fi

