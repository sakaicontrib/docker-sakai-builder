Fast Sakai Build

Tested on OSX and Linux

TODO: 
  Convert some of this to a docker-compose instead of straight docker commands
  Put the git into the "build" container so that you can skip that step (Though useful to have)

Pre-requisites
--------------
Computer with at least 8GB of Memory
Docker installed for your OS
  Configure to have at 3GB of Memory for Docker (4GB+ if you have 16GB)
  https://stackoverflow.com/a/44533437/3708872
Git installed for your OS so that the "git" command works on the command line.

# To clean up everything done here run
# docker stop sakai-mysql; docker stop sakai-tomcat; docker rm sakai-mysql; docker rm sakai-tomcat; docker rm sakai-build; git clean -f -d

# Define these variables first
# The "work" directory
WORK="${PWD}/work"
# Where tomcat files will be
TOMCAT="${WORK}/tomcat"
# Where files will be deployed
DEPLOY="${TOMCAT}/deploy"

# First download Sakai with git, you may also want to clone your fork instead.
git clone https://github.com/sakaiproject/sakai
cd sakai

# Note at this point you can checkout and build another branch. These notes will only currently work with 19.x+ because of the tomcat version.
# TODO Support having multiple different branches


# Now build it with maven in Docker! 
# (This caches the artifacts at ~/.m2 deploys to /tomcat/deploy)

# Note alpine docker not compatible with frontend-maven-plugin 
# https://github.com/eirslett/frontend-maven-plugin/issues/633

# This needs to install git because of gulp-bower in rubrics
# Maybe that will be fixed someday, doesn't seem worth it for a new image

# \rm -rf "${WORK}/tomcat/deploy"; 

docker run --rm -it --name sakai-build \
    -e "MAVEN_OPTS= -XX:+TieredCompilation -XX:TieredStopAtLevel=1" \
    -v "${DEPLOY}:/usr/src/deploy" \
    -v "${HOME}"/.m2:/root/.m2 \
    -v "${PWD}:/usr/src/app" \
    -w /usr/src/app maven:3.5.4-jdk-8-slim \
    /bin/bash -c "apt-get update && apt-get -y install git --no-install-recommends && mvn -T 1C -B -P mysql install sakai:deploy -Dmaven.test.skip=true -Dmaven.tomcat.home=/usr/src/deploy -Dsakai.cleanup=true" 

cd ..

# Start up MySQL on port 53306
# Remove it if you already made one
# docker stop sakai-mysql; docker rm sakai-mysql

docker run -d --name=sakai-mysql -p 53306:3306 \
    -e "MYSQL_ROOT_PASSWORD=sakairoot" \
    -v "${WORK}/mysql/scripts:/docker-entrypoint-initdb.d" \
    -v "${WORK}/mysql/data:/var/lib/mysql" \
    -d mysql:5.6

# Now deploy it to the Tomcat image!
# https://askubuntu.com/a/604111/365150

# Remove it if you already made one
# docker stop sakai-tomcat; docker rm sakai-tomcat

docker rm sakai-tomcat -f; docker run -d --name=sakai-tomcat -p 8080:8080 \
    -e "CATALINA_BASE=/usr/src/app/deploy" \
    -v "${DEPLOY}:/usr/src/app/deploy" \
    -v "${TOMCAT}/sakaihome:/usr/src/app/deploy/sakai" \
    -v "${TOMCAT}/catalina_base/bin:/usr/src/app/deploy/bin" \
    -v "${TOMCAT}/catalina_base/conf:/usr/src/app/deploy/conf" \
    -v "${TOMCAT}/catalina_base/webapps/ROOT:/usr/src/app/deploy/webapps/ROOT" \
    --link sakai-mysql:mysql \
    tomcat:9.0.11-jre8-alpine

# To see the startup logs run 
`docker logs sakai-tomcat -f`
# To write the logs to a file use
`docker logs sakai-tomcat >& logs.txt
