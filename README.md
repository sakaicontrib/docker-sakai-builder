Fast Sakai Build

Tested on OSX and Linux

TODO: 
  Convert some of this to a docker-compose instead of straight docker commands
  Simplify some of the paths to have a single virtual "HOME"


# Pre-requisites
--------------
Computer with at least 8GB of Memory
Docker installed for your OS
  Configure to have at 3GB of Memory for Docker (4GB+ if you have 16GB)
  https://stackoverflow.com/a/44533437/3708872
Git installed for your OS so that the "git" command works on the command line.

To clean up everything done here run
`Docker stop sakai-mysql; docker stop sakai-tomcat; docker rm sakai-mysql; docker rm sakai-tomcat; docker rm sakai-build; git clean -f -d`

# Define these variables first
# The "work" directory
```
WORK="${PWD}/work"
# Where tomcat files will be
TOMCAT="${WORK}/tomcat"
# Where files will be deployed
DEPLOY="${TOMCAT}/deploy"

# First download Sakai with git, you may also want to clone your fork instead.
git clone https://github.com/sakaiproject/sakai
cd sakai
```

# Note at this point you can checkout and build another branch. These notes will only currently work with 19.x+ because of the tomcat version.
# TODO Support having multiple different branches

# Now build it with maven in Docker! 
(This caches the artifacts at ~/.m2 deploys to /tomcat/deploy)

Note alpine docker not compatible with frontend-maven-plugin 
https://github.com/eirslett/frontend-maven-plugin/issues/633

This needs to install git because of gulp-bower in rubrics
Maybe that will be fixed someday. However we have to build a new image in order to include this.

This cannot be included in the same step because of the user/permission difference.
```
\rm -rf "${WORK}/tomcat/deploy"; 
cd mavenbuild
docker build . -t sakai:build
cd ../sakai
```
Now you can use this to build the actual code.

```
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
    /bin/bash -c "mvn -T 1C -B -P mysql install sakai:deploy -Dmaven.test.skip=true -Dmaven.tomcat.home=/usr/src/deploy -Dsakai.cleanup=true -Duser.home=/tmp/" 

cd ..
```

# Start up MySQL on port 53306
Remove it if you already made one
# docker stop sakai-mysql; docker rm sakai-mysql

```
docker run -d --name=sakai-mysql -p 53306:3306 \
    -e "MYSQL_ROOT_PASSWORD=sakairoot" \
    -v "${WORK}/mysql/scripts:/docker-entrypoint-initdb.d" \
    -v "${WORK}/mysql/data:/var/lib/mysql" \
    -u `id -u`:`id -g` \
    -d mysql:5.6
```
# Now deploy it to the Tomcat image!

Remove it if you already made one
`docker stop sakai-tomcat; docker rm sakai-tomcat`
```
docker rm sakai-tomcat -f; docker run -d --name=sakai-tomcat -p 8080:8080 \
    -e "CATALINA_BASE=/usr/src/app/deploy" \
    -e "JAVA_OPTS=-server -d64 -Xms1g -Xmx2g -Djava.awt.headless=true -XX:+UseCompressedOops -XX:+UseConcMarkSweepGC -XX:+DisableExplicitGC -Dhttp.agent=Sakai -Dorg.apache.jasper.compiler.Parser.STRICT_QUOTE_ESCAPING=false” -Dsakai.home=/usr/src/app/deploy/sakai/ -Duser.timezone=US/Eastern -Dsakai.cookieName=SAKAI2SESSIONID -Dsakai.demo=true -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=8089 -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false" \
    -v "${DEPLOY}:/usr/src/app/deploy" \
    -v "${TOMCAT}/sakaihome:/usr/src/app/deploy/sakai" \
    -v "${TOMCAT}/catalina_base/bin:/usr/src/app/deploy/bin" \
    -v "${TOMCAT}/catalina_base/conf:/usr/src/app/deploy/conf" \
    -v "${TOMCAT}/catalina_base/webapps/ROOT:/usr/src/app/deploy/webapps/ROOT" \
    -u `id -u`:`id -g` \
    --link sakai-mysql:mysql \
    tomcat:9.0-jre8-alpine
```
* To see the startup logs run 
`docker logs sakai-tomcat -f`
* To write the logs to a file use
`docker logs sakai-tomcat >& logs.txt

# References
* https://askubuntu.com/a/604111/365150
