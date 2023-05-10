#! /usr/bin/env bash

# If error process fails (exits without zero) this will cause the script to halt.
set -e

#
# FIN Framework extension PODs file build script
#
# See http://office.j2inn.com:4040/view/FIN%205/job/FIN-5%20FinStack%20Ext/configure
#

#
# Requirements
#
# * The base FIN image must be installed.
# * The Java 8 JDK must be installed.
#   * Ensure the JAVA_HOME environment variable is set. 
# * The ANT build system must be available
#   * For Linux try - sudo apt-get install ant
#   * For Windows, install ANT on the command line.
# * The FAN_HOME environment variable must be configured.
#   * If using bash on Windows, the variable will need extra escaping. For example - \/c:\/Program Files\/AdoptOpenJDK\/jdk-8.0.202.08\/
# * The FAN_BUILD_JDKHOME environment variable must be configured.
#   * If using bash on Windows, the variable will need extra escaping. For example - \/c:\/Program Files (x86)\/FIN Framework\/FIN Framework 5.0.3.2359\/
#

if [ -z "$FAN_HOME" ] 
then
	echo "Could not find FAN_HOME! Please set this environment variable before using this build script. For example, export FAN_HOME=~/finstack"
	exit 1
fi

if [ -z "$FAN_BUILD_JDKHOME" ]
then
	echo "Could not find FAN_BUILD_JDKHOME! Please set this environment variable before using this build script. For example, export FAN_BUILD_JDKHOME=/usr/lib/jvm/java-8-openjdk-amd64/"
	exit 1
fi

if [ -z "$BUILD_VERSION" ]
then
	export BUILD_VERSION="5.1.4"
fi

if [ -z "$SKY_SPARK_VERSION" ]
then
	export SKY_SPARK_VERSION="3.1.5"
fi

# Setting this to a space means we can build higher than Java 7
export FAN_BUILD_JAVACPARAMS=" "

CWD=$(pwd)

function buildPod() {
  echo "*** Building $1 ***"
	"$FAN_HOME/bin/fan" "$1/build.fan"
  echo "*** Successfully built $1 ***"
}

function buildAllPods {
	echo "*** Building customized Haxall PODs. Version: $SKY_SPARK_VERSION ***"

	# As per FIN-5 FinStack Ext Jenkins build step.
	# http://office.j2inn.com:4040/view/FIN%205/job/FIN-5%20FinStack%20Ext/configure
	cd src/conn
  buildPod hxHaystack
  cd "$CWD"
	echo "*** Successfully built customized Haxall PODs ***"
}

buildAllPods