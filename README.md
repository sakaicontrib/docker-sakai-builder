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

If you already have this checked out and want to start fresh in this folder, run
```
docker stop sakai-mysql; docker stop sakai-tomcat; docker rm sakai-mysql; docker rm sakai-tomcat; docker rm sakai-build; git clean -f -d
```
Make sure you have a copy of Sakai in the `sakai` folder:
```
# You may also want to clone your fork/repo instead of the sakaiproject repo
git clone https://github.com/sakaiproject/sakai
```

*Note at this point you can checkout and build another branch. These notes will only currently work with 19.x+ because of the tomcat version.*

# Now build it with maven in Docker! 
Note: (This caches the artifacts at ~/.m2 deploys to /tomcat/deploy)

```
# May need to run this to clean up the deploy, run clean_deploy if the case
cd sakai
../sakai-dock.sh clean_deploy
../sakai-dock.sh build
cd ..
```

Start up MariaDB on port 53306.
Remove database data if you already made one and want to clean it out! (Optional)

```
./sakai-dock.sh clean_data
./sakai-dock.sh mariadb
```

You can connect to mariadb to look around using a password of `sakairoot`.  It takes a moment for
mariadb to come up so you might want to make sure this connection works before starting tomcat.
```
mysql -h 127.0.0.1 -P 53306 -u root -p
```

# Now startup tomcat!
```
# Remove if you already made a sakai-tomcat docker image and you want to a fresh one!
# docker rm sakai-tomcat
./sakai-dock.sh tomcat
```

* To watch the sakai logs as it runs run 
`docker logs sakai-tomcat -f`
* To get a complete log and write it to a file use
`docker logs sakai-tomcat >& logs.txt`

# Partial builds - Run from a subfolder
```
cd sakai/basiclti
../../sakai-dock.sh build
```

Sometimes it works but sometimes you also have to restart tomcat afer a build:
```
../../sakai-dock.sh tomcat
```

# Custom Maven
You may need to build a custom Maven to get this to work from time to time. I've got a maven that includes git for instance.
```
cd mavenbuild
docker build . -t sakai:build
```

Then if you build with it -c option it will use this custom build instead of a default one.

# References
* https://askubuntu.com/a/604111/365150
