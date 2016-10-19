#!/bin/sh

##############################################################################################
#  Build Script for Motion application.  
#  This script is currently only functional for Debian based systems.
#  The following is the overall flow:
#  0.  Validate distribution, user parameters and packages
#  1.  Create a temporary directory and copy in the Motion code.
#  2.  Clean out any working files from the code base copied.
#  3.  Tar up the code and move up to directory parent.
#  4.  Retrieve from git the package rules (usually debian)
#  5.  Change to the applicable branch of package rules and move them to appropriate location.
#  6.  Call the packager application (dpkg-buildpackage) output result to a buildlog file.
#  7.  Move resulting files to the parent of the original source code directory and clean up
##############################################################################################

#########################################################################################
#  Declaration of variables needed
#########################################################################################
DEBUSERNAME=$1
DEBUSEREMAIL=$2
GITBRANCH=$3
BASEDIR=$(pwd)
DIRNAME=${PWD##*/}
VERSION=""
TARNAME=""
TEMPDIR=""
DEBDATE="$(date +'%a, %d %b %Y %H:%M:%S %z')"
MISSINGPKG=""
DISTO=$(lsb_release -is)
DISTROVERSION=$(lsb_release -is)
DISTRONAME=$(lsb_release -cs)

##############################################################################################
#  0.  Validate distribution, user parameters and packages
##############################################################################################

if [ $DISTO != "Ubuntu" ] &&
   [ $DISTO != "Debian" ] &&
   [ $DISTO != "Raspbian" ] ; then
  echo "This script is only functional for Debian, Ubuntu and Raspbian"
  exit 1
fi

if [ -z "$DEBUSERNAME" ] || [ -z "$DEBUSEREMAIL" ] || [ -z "$GITBRANCH" ]; then
  echo
  echo "Usage:  builddeb.sh name email <optional branch>"
  echo "Name:   Name to use for deb package must not include spaces"
  echo "Email:  Email address to use for deb package"
  echo "Branch: The git branch name of Motion to build (If none specified, uses master)"
  echo
fi

if [ -z "$DEBUSERNAME" ]; then
  DEBUSERNAME="AdhocBuild"
fi

if [ -z "$DEBUSEREMAIL" ]; then
  DEBUSEREMAIL="AdhocBuild@nowhere.com"
fi

if [ -z "$GITBRANCH" ]; then
  GITBRANCH="master"
fi

echo
echo "Using Username: $DEBUSERNAME , User Email: $DEBUSEREMAIL , Git Branch: $GITBRANCH "
echo
sleep 3

#########################################################################################
# Find any packages missing.  (not the best method but functional)
#########################################################################################
if !( dpkg-query -W -f'${Status}' "git" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" git"; fi
if !( dpkg-query -W -f'${Status}' "pkg-config" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" pkg-config"; fi
if !( dpkg-query -W -f'${Status}' "autoconf" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" autoconf"; fi
if !( dpkg-query -W -f'${Status}' "automake" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" automake"; fi
if !( dpkg-query -W -f'${Status}' "libtool" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" libtool"; fi
if !( dpkg-query -W -f'${Status}' "libavcodec-dev" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" libavcodec-dev" ; fi
if !( dpkg-query -W -f'${Status}' "libavformat-dev" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" libavformat-dev"; fi
if !( dpkg-query -W -f'${Status}' "libswscale-dev" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" libswscale-dev"; fi
if !( dpkg-query -W -f'${Status}' "libjpeg-dev" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" libjpeg-dev"; fi
if !( dpkg-query -W -f'${Status}' "libpq-dev" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" libpq-dev"; fi
if !( dpkg-query -W -f'${Status}' "libmysqlclient-dev" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" libmysqlclient-dev"; fi
if !( dpkg-query -W -f'${Status}' "libsqlite3-dev" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" libsqlite3-dev"; fi
if !( dpkg-query -W -f'${Status}' "dpkg-dev" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" dpkg-dev"; fi
if !( dpkg-query -W -f'${Status}' "debhelper" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" debhelper"; fi
if !( dpkg-query -W -f'${Status}' "dh-autoreconf" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" dh-autoreconf"; fi
if !( dpkg-query -W -f'${Status}' "zlib1g-dev" 2>/dev/null | grep -q "ok installed"); then MISSINGPKG=$MISSINGPKG" zlib1g-dev"; fi
if [ "$MISSINGPKG" = "" ]; then
  echo "All packages installed"
else
  echo "The following packages need to be installed with the following command: sudo apt-get install $MISSINGPKG"
  exit 1
fi

#########################################################################################
#  1.  Create a temporary directory and copy in the Motion code.
#########################################################################################
  TEMPDIR=$(mktemp -d /tmp/motion.XXXXXX)

  if [ "$DIRNAME" = "motion" ] && [ -d "raspbian" ]; then
    mkdir $TEMPDIR/motion
    mkdir $TEMPDIR/motion/raspicam
    cp ./* $TEMPDIR/motion/
    cp -R ./.git $TEMPDIR/motion/
    cp ./raspicam/* $TEMPDIR/motion/raspicam/
  else
    cd $TEMPDIR
    git clone https://github.com/Motion-Project/motion.git
  fi

  cd $TEMPDIR/motion
  if ! git checkout $GITBRANCH ; then
    echo Unknown branch
    rm -rf $TEMPDIR
    exit 1
  fi

  cd $BASEDIR
  if [ "$DIRNAME" = "motion-packaging" ] && [ -d "debian" ]; then
    mkdir $TEMPDIR/motion-packaging
    cp -R $BASEDIR $TEMPDIR
  else
    cd $TEMPDIR
    git clone https://github.com/Motion-Project/motion-packaging.git
  fi

  cd $TEMPDIR/motion

#########################################################################################
#  2.  Clean out any working files from the code base copied.
#########################################################################################
  rm -f config.status config.log config.cache Makefile motion.service motion.init-Debian motion.init-FreeBSD.sh
  rm -f camera1-dist.conf camera2-dist.conf camera3-dist.conf camera4-dist.conf motion-dist.conf motion-help.conf motion.spec
  rm -rf autom4te.cache config.h .gitignore .travis.yml
  rm -f *.gz *.o *.m4 *.*~

#########################################################################################
#  3.  Tar up the code and move up to directory parent.
#########################################################################################
  VERSION=$(./version.sh)
  TARNAME=motion_$VERSION.orig.tar.gz

  tar --exclude=.git -zcf $TARNAME *

  mv $TARNAME $TEMPDIR/$TARNAME

  cd ..

#########################################################################################
#  4.  Retrieve from git the package rules (usually debian)
#########################################################################################
####Currently all distributions are set to use master until variantions are identified
#########################################################################################

  cd $TEMPDIR/motion-packaging

  if [ "$DISTO" = "Ubuntu" ]; then
    if [ "$DISTROVERSION" = "14.04" ]; then
      git checkout master
    else
      git checkout master
    fi
  elif [ "$DISTO" = "Debian" ]; then
   MAJOR=`echo $DISTROVERSION | cut -d. -f1`
   if [ "$MAJOR" = "7" ]; then
      git checkout master
    else
      git checkout master
    fi
  elif [ "$DISTO" = "Raspbian" ]; then
   MAJOR=`echo $DISTROVERSION | cut -d. -f1`
   if [ "$MAJOR" = "7" ]; then
      git checkout master
    else
      git checkout master
    fi
  else
    echo "Unsupported Distribution: $DISTO"
    rm -rf $TEMPDIR
    exit 1
  fi
  mv $TEMPDIR/motion-packaging/debian $TEMPDIR/motion/debian

#########################################################################################
#  4a.  Update the packaging changelog
#########################################################################################
  cd $TEMPDIR/motion
  echo "motion ($VERSION-1) $DISTRONAME; urgency=medium\n\n  * See changelog in source\n\n -- $DEBUSERNAME <$DEBUSEREMAIL>  $DEBDATE\n" >./debian/changelog

#########################################################################################
#  6.  Call the packager application (dpkg-buildpackage) output result to a buildlog file.
#########################################################################################
  if ! [ $? -eq 0 ]; then
    echo "Unspecified error"
    rm -rf $TEMPDIR
    exit 1
  fi
  echo "Building package...."
  dpkg-buildpackage -us -uc >$TEMPDIR/motion_$VERSION-buildlog.txt 2>&1
##############################################################################################
#  7.  Move resulting files to the parent of the original source code directory and clean up
##############################################################################################
  cd $BASEDIR
  mv $TEMPDIR/motion_$VERSION* $BASEDIR
  rm -rf $TEMPDIR

#########################################################################################
  if [ $? -eq 0 ]; then
    echo "The deb packages and build logs have been created and placed into $BASEDIR"
    exit 0
  else
    echo "Build Error.  Check build log in directory $BASEDIR"
    exit 1
  fi
##############################################################################################
