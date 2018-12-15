Fast Sakai Build

Tested on OSX and Linux

TODO: 
  Convert some of this to a docker-compose instead of straight docker commands
  Simplify some of the paths to have a single virtual "HOME"
  Continue cleanup to make these into shell scripts


# Pre-requisites
--------------
* Computer with at least 8GB of Memory
* Docker installed for your OS
  * Configure to have at 3GB of Memory for Docker (4GB+ if you have 16GB)
  * https://stackoverflow.com/a/44533437/3708872
* Git installed for your OS so that the "git" command works on the command line.

To clean up everything done here run
`Docker stop sakai-mysql; docker stop sakai-tomcat; docker rm sakai-mysql; docker rm sakai-tomcat; docker rm sakai-build; git clean -f -d`

# Define this variable first for the "work" directory
```
WORK="${PWD}/work"

# First download Sakai with git, you may also want to clone your fork instead.
git clone https://github.com/sakaiproject/sakai
cd sakai
```

*Note at this point you can checkout and build another branch. These notes will only currently work with 19.x+ because of the tomcat version.*

*TODO Support having multiple different branches*

# Now build it with maven in Docker! 
(This caches the artifacts at ~/.m2 deploys to /tomcat/deploy)

Note alpine docker not compatible with frontend-maven-plugin 
https://github.com/eirslett/frontend-maven-plugin/issues/633

This needs to install git because of gulp-bower in rubrics
Maybe that will be fixed someday. However we have to build a new image in order to include this.

This cannot be included in the same step because of the user/permission difference.
```
cd mavenbuild
docker build . -t sakai:build

```
Now you can use this to build the actual code.

```
cd ../sakai
# May need to run this to clean up the deploy, make sure WORK is defined. (TODO: Work this into the script)
# \rm -rf "${WORK}/tomcat/deploy"; 
../maven-build.sh
cd ..
```

# Start up MySQL on port 53306
Remove it if you already made one and want to clean it out!
`# docker rm sakai-mysql`
`./sakai-dock.sh mysql`

# Now startup tomcat!
Remove it if you already made one and want to clean it out!
`# docker rm sakai-tomcat`
`./sakai-dock.sh tomcat`

* To see the startup logs run 
`docker logs sakai-tomcat -f`
* To write the logs to a file use
`docker logs sakai-tomcat >& logs.txt`

# References
* https://askubuntu.com/a/604111/365150
