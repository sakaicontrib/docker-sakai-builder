Fast Sakai Build

Tested on OSX, Linux(Ubuntu) and Windows Subsystem for Linux (Ubuntu+Windows Enterprise)

TODO: 
* Convert some of this to a docker-compose instead of straight docker commands?
* Support having multiple different branches
* Make build_sakai more configurable, like number of threads whether or not to run sakai:deploy, skip tests, debugging etc

# Pre-requisites
--------------
* Computer with at around 8GB of Memory
* Docker installed for your OS
  * Go into the [Settings->Advanced](https://stackoverflow.com/a/44533437/3708872) of the Docker icon and configure to have at 3GB of Memory for Docker (4GB+ if you have 16GB). You can also increase the CPU's if you want to have faster builds.
  * [This blog has some good tips](https://nickjanetakis.com/blog/setting-up-docker-for-windows-and-wsl-to-work-flawlessly) for setting it up in Windows.
  * If using WSL make sure to put your files on the /mnt/c (or /c) drive somewhere or else (Windows) Docker won't be able to use them.
* Git installed for your OS so that the "git" command works on the command line.

To clean up everything done here run
`Docker stop sakai-mysql; docker stop sakai-tomcat; docker rm sakai-mysql; docker rm sakai-tomcat; docker rm sakai-build; git clean -f -d`

```
# First download Sakai with git in this directory, you may also want to clone your fork instead.
git clone https://github.com/sakaiproject/sakai
cd sakai
```

*Note at this point you can checkout and build another branch. These notes will only currently work with 19.x+ because of the tomcat version.*

# Now build it with maven in Docker! 
Note: (This caches the artifacts at ~/.m2 deploys to /tomcat/deploy)

```
# May need to run this to clean up the deploy, run this if the case
# ../sakai-dock.sh clean_deploy
../sakai-dock.sh build
cd ..
```

# Start up MySQL on port 53306
Remove it if you already made one and want to clean it out! (Optional)
`# \rm -rf ${WORK}/mysql/data`
Start up MySQL!
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
