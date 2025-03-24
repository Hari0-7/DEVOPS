#!/bin/bash
#
# Copyright (c) Ericsson AB 2017
#
# Author: devops-designer@ericsson.com
# Version: 1.00
# Date:
# Description: Build and produce AFG rpm + Unit test + Packaging
#echo "---> Steps from source/stepsRPM.bash file."
# If any command fails, script will terminate.
# set -e

# Set more traces if DEBUG var env. exist.
[ -n "$DEBUG" ] && set -x

# initial the flag to catch unit test failures
UNSTABLE=0

THIS_SCRIPT=`basename $0`

#######################################################################
# Common steps to create build/ folder and save jenkins config        #
#######################################################################
function createBuildFolder() {
        ## create a link in the workspace
        cd $WORKSPACE

        ## checking if all required repo are setup
        if [ ! -d msp ]; then
                echo "ERROR missing MSP repo"
                exit -1
        fi
        if [ ! -d msa ]; then
                echo "ERROR missing MSA repo"
                exit -1
        fi
        cd $WORKSPACE/msp
        export mspSHA=`git log --pretty=format:'%H' -n 1`
        cd $WORKSPACE/msa
        export msaSHA=`git log --pretty=format:'%H' -n 1`

        cd $WORKSPACE
        if [ ! -L devops ]; then
                ln -s $WORKSPACE/msp/devops devops
        fi

        cd  $WORKSPACE/msp/devops/others
        ./common1_steps.bash

}


#######################################################################
# Compile setupBuildEnv  (imported from ci-j1-compile )

function setupBuildEnv() {
        echo "---> ${THIS_SCRIPT}: Setup AFG Build environement START at `date` for: $MS_NAME IN ${WORKSPACE}..."

        cd $WORKSPACE/
        ### BUILD_NUMBER ###
        BUILD_NUMBER=$(echo $BUILD_NUMBER | sed 's/^0*//')

        if [ $BUILD_NUMBER -lt 10 ]; then
           export BUILD_NUMBER=00${BUILD_NUMBER}
        elif [ $BUILD_NUMBER -lt 100 ]; then
           export BUILD_NUMBER=0${BUILD_NUMBER}
        else
           export BUILD_NUMBER=${BUILD_NUMBER}
        fi

        echo  "export AFG_MSPRELMAJ=$MSPRELMAJ" > build.properties
	export LABEL=${AFG_MSPRELMAJ}-${BUILD_NUMBER}
        echo  "export BUILD_NUMBER=$BUILD_NUMBER"  >> build.properties
        echo  "export BPATH=$BPATH" >> build.properties
        echo  "export BRANCH_AFG=$BRANCH_AFG" >> build.properties
        echo  "export BRANCH_IOT=$BRANCH_IOT" >> build.properties
        echo  "export BRANCH_TESTTOOLS=$BRANCH_TESTTOOLS" >> build.properties
        echo  "export BRANCH_RBT=$BRANCH_RBT" >> build.properties
        echo  "export BRANCH_PURELOAD=$BRANCH_PURELOAD" >> build.properties
        echo  "export BRANCH_MSA=$BRANCH_MSA" >> build.properties
        echo  "export PRODUCTVERSION=${MSPRELMAJ}${LABEL}" >> build.properties
        echo  "export MSPRELMAJ=$MSPRELMAJ" >> build.properties
        echo  "export MSPRELMIN=$BUILD_NUMBER" >> build.properties
        echo  "export LOCALDATE=$LOCALDATE" >> build.properties
        echo  "export LOCALBUILDDATE=$LOCALDATE" >> build.properties
        echo  "export LABEL=$LABEL" >> build.properties
        echo  "export AFG_TAR_VCD=${AFG_TAR_VCD}" >> build.properties
        echo  "export AFG_TAR_CEE=${AFG_TAR_CEE}" >> build.properties
        echo  "export JAVA_HOME=//usr/lib64//jvm/java-11-openjdk-11"  >> build.properties
        echo  "export VAFG_BUILD_NUMBER=$BUILD_NUMBER"  >> build.properties
        echo  "export msaSHA=$msaSHA"  >> build.properties
        echo  "export mspSHA=$mspSHA"  >> build.properties
        echo  "export SPVERSION=$SPVERSION"  >> build.properties

        echo "----> ${THIS_SCRIPT} Dumping contents of build.properties"
        echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
        cat build.properties
        echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

        ### Source the build.properties in this workspace
        .  ${WORKSPACE}/build.properties
        ## save a copy in the build artifacts
        mkdir -p ${WORKSPACE}/build/
        cp ${WORKSPACE}/build.properties ${WORKSPACE}/build/build.properties
        # upload the build.proberties to YUM
        echo "--> ${THIS_SCRIPT}: Uploading file $WORKSPACE/build.properties to $YUM/$YUML1/$YUML2/$YUML3/$BRANCH_AFG..."
        curl --silent -u  $funcidu:$armmotoken -T $WORKSPACE/build.properties  -X PUT $YUM/$YUML1/$YUML2/$YUML3/$BRANCH_AFG/ >> $WORKSPACE/build/curl.log

        echo "---> ${THIS_SCRIPT}: Setup AFG Build environement END at `date` for: $MS_NAME IN ${WORKSPACE}..."
}


#######################################################################
function cleanUPbuildSpace() {
        echo "--> AFG DevOps: cleanUPbuildSpace START"

        cd $WORKSPACE/msp/
        git clean -dfx > /dev/null
        git checkout  $BRANCH_AFG
        git pull
        git checkout .

        rm -fr /tmp/cmake_build/

        cd $WORKSPACE/msa/
        git clean -dfx > /dev/null
        git checkout $BRANCH_MSA
        git pull
        git checkout .

        ## YUM TO DELETE Before Rebuild
        yumpath=$YUM/$YUML1/$YUML2/$YUML3/
        yumpath3pp=$YUM/$YUML1/$YUML2/$YUML3PP/

        echo "---> ${THIS_SCRIPT}: Calling command: curl --silent -u $funcidu:$armmotoken -X DELETE $yumpath..."
        curl --silent -u $funcidu:$armmotoken -X DELETE $yumpath >> $WORKSPACE/build/curl.log
        echo "---> ${THIS_SCRIPT}: Status = $?"

        echo "---> ${THIS_SCRIPT}: Calling command: curl --silent  -u $funcidu:$armmotoken -X DELETE $yumpath3pp..."
        curl --silent -u $funcidu:$armmotoken -X DELETE $yumpath3pp >> $WORKSPACE/build/curl.log
        echo "---> ${THIS_SCRIPT}: Status = $?"

        echo "--> AFG DevOps: cleanUPbuildSpace END"
}

#######################################################################
function compileMN() {
        echo "---> ${THIS_SCRIPT}: Compile MN START at `date` for: $MS_NAME IN ${WORKSPACE}..."
        export PROJBASE=$WORKSPACE/msa/
        export MSPREPO=$WORKSPACE/msp/

        export RPMPRODUCTVERSION=$PRODUCTVERSION
        export RPMMSPRELMAJ=$MSPRELMAJ
        export RPMMSPRELMIN=$MSPRELMIN
        export major=$MSPRELMAJ
        export minor=$MSPRELMIN



        echo "---> ${THIS_SCRIPT}: Compile MN RPM for  $WORKSPACE/msa/ZUP/ZUKW/distribution/sles12/mnvm START"
        echo "---> ${THIS_SCRIPT}: Calling:   ./build_MN.sh build ver     Output being redirected to $WORKSPACE/build/build_MN.sh.log "
        cd $WORKSPACE/msa/ZUP/ZUKW/distribution/sles12/mnvm
        bash ./build_MN.sh build ver > $WORKSPACE/build/build_MN.sh.log 2>&1
        echo "---> ${THIS_SCRIPT}: Compile MN RPM for  $WORKSPACE/msa/ZUP/ZUKW/distribution/sles12/mnvm END"



        echo "---> ${THIS_SCRIPT}: Compile MN RPM for  $WORKSPACE/msa/ZUP/ZUAP  ./build_DevOps_rpms.sh $PROJBASE     START"
        echo "---> ${THIS_SCRIPT}: Calling:   ./build_DevOps_rpms.sh $PROJBASE   Output being redirected to $WORKSPACE/build/build_DevOps_rpms.sh.ZUAP.log "
        cd $WORKSPACE/msa/ZUP/ZUAP
        bash ./build_DevOps_rpms.sh $PROJBASE > $WORKSPACE/build/build_DevOps_rpms.sh.ZUAP.log 2>&1
        echo "---> ${THIS_SCRIPT}: Compile MN RPM for  $WORKSPACE/msa/ZUP/ZUAP  ./build_DevOps_rpms.sh $PROJBASE     END"



        echo "---> ${THIS_SCRIPT}: Compile MN RPM for $WORKSPACE/msa/ZUP/ZUPL ./build_DevOps_rpms.sh $PROJBASE    START"
        echo "---> ${THIS_SCRIPT}: Calling:   ./build_DevOps_rpms.sh $PROJBASE   Output being redirected to $WORKSPACE/build/build_DevOps_rpms.sh.ZUPL.log "
        cd $WORKSPACE/msa/ZUP/ZUPL
        bash ./build_DevOps_rpms.sh $PROJBASE > $WORKSPACE/build/build_DevOps_rpms.sh.ZUPL.log 2>&1
        echo "---> ${THIS_SCRIPT}: Compile MN RPM for $WORKSPACE/msa/ZUP/ZUPL ./build_DevOps_rpms.sh $PROJBASE    END"

        mkdir -p $WORKSPACE/build/MNrpm/
        cp /var/tmp/x86_64/*.rpm $WORKSPACE/build/MNrpm/
}

#######################################################################
function buildMspRpm(){
        echo "---> ${THIS_SCRIPT}: buildMspRpm START at `date` for: $MS_NAME IN ${WORKSPACE}..."

        cd $WORKSPACE/msp/ZUP/MSPsoftware-x86/Software/MSPsubmedias
        echo "---> ${THIS_SCRIPT}: output redirected to $WORKSPACE/build/build_DevOps_rpm.sh.log"
        bash ./build_DevOps_rpm.sh $WORKSPACE/msp/ > $WORKSPACE/build/build_DevOps_rpm.sh.log 2>&1

        mkdir -p $WORKSPACE/build/MSPrpm
        cp /var/tmp/x86_64/*.rpm $WORKSPACE/build/MSPrpm
        echo "---> ${THIS_SCRIPT}: buildMspRpm END at `date` for: $MS_NAME IN ${WORKSPACE}..."
}

#######################################################################
# Compile AFG  (imported from ci-j1-compile )

function compileAFG() {
  echo "---> ${THIS_SCRIPT}: Compile AFG START at `date` for: $MS_NAME IN ${WORKSPACE}..."

        cd  ${WORKSPACE}
        . ${WORKSPACE}/build.properties

        echo "---> ${THIS_SCRIPT}: BUILD_NUMBER:  $BUILD_NUMBER  ($BRANCH_AFG)"

        echo "---> ${THIS_SCRIPT}: reset GIT to: $BRANCH_AFG"
        cd $WORKSPACE/msp/
        git checkout $BRANCH_AFG
        git pull

        cd $WORKSPACE/msp/jenkins
        ./stop_afg_and_simulators.sh

        # Clean up /etc/profile.local  DEVOPS-427
        # before calling /home/jenkins/workspace/pre-build-compile/msp/ZUP/kiwi/distribution/sles12/afgvm/build_AFG.sh
        # from compile_clean_afg_with_ninja.sh
  if [ -f /etc/profile.local ]; then
        echo "---> ${THIS_SCRIPT}: clean up /etc/profile.local "
        cp /etc/profile.local /etc/profile.local.bak
        sed -i '/PRODUCTVERSION/d' /etc/profile.local
        sed -i '/MSPRELMAJ/d'      /etc/profile.local
        sed -i '/MSPRELMIN/d'      /etc/profile.local
   fi


   echo "---> ${THIS_SCRIPT}: Calling $WORKSPACE/msp/ZUP/kiwi/distribution/sles12/afgvm/build_AFG.sh build ver   (C++ compilation) START at `date`"
   echo "---> ${THIS_SCRIPT}: Output is being redirected to $WORKSPACE/build/build_AFG.sh.log..."
         cd $WORKSPACE/msp/ZUP/kiwi/distribution/sles12/afgvm/
         bash ./build_AFG.sh build ver  > $WORKSPACE/build/build_AFG.sh.log  2>&1
   echo "---> ${THIS_SCRIPT}: Calling $WORKSPACE/msp/ZUP/kiwi/distribution/sles12/afgvm/build_AFG.sh build ver   (C++ compilation) END at `date`"
   echo "---> TESTING the output of the MSP/AFG build log"
   $WORKSPACE/devops/others/scanForErrors.py --dictionary $WORKSPACE/devops/build/Errors-Pathern-Builds.log --logfile $WORKSPACE/build/build_AFG.sh.log
   if [ "$?" = "0" ]
   then
      echo "OK for analysis on build_AFG.sh.log"
   else
      echo -e "\n---> ${THIS_SCRIPT}: test FAIL for $WORKSPACE/build/build_AFG.sh.log"
      exit 1
   fi

         ## Moving the MSP RPM to a safe place
         mkdir -p $WORKSPACE/build/AFGrpm/
         cp /var/tmp/x86_64/*.rpm $WORKSPACE/build/AFGrpm/

         echo "---> ${THIS_SCRIPT}: Compile AFG END at `date` for: $MS_NAME..."
}

#######################################################################

#######################################################################
# Create the Release notes
function createReleaseNote() {

        echo "---> ${THIS_SCRIPT}:  Create Release notes"
        gitRepoName=`echo $GIT_URL | sed "s/ssh:.*:29418\///"`
        cd $WORKSPACE/msp/devops/others
        perl ./AutoReleaseNotes.pl  y $MS_NAME  1.0  $BRANCH  $BUILD_NUMBER $BUILD_URL $gitRepoName   HEAD  TS-0.00
        cp   releasenotes.html  $WORKSPACE/build/ReleaseNotes.html
}



#######################################################################
function uploadToYUM() {

  echo "---> ${THIS_SCRIPT}: Upload RPM to YUM START at `date`"

  export yumpathUpload=$YUM/$YUML1/$YUML2/$YUML3/

  [ -d $WORKSPACE/build/txYum/ ] && rm -fr $WORKSPACE/build/txYum/
  mkdir $WORKSPACE/build/txYum/
  cp $WORKSPACE/build/AFGrpm/*rpm $WORKSPACE/build/txYum/
  cp $WORKSPACE/build/MNrpm/*rpm $WORKSPACE/build/txYum/
  cp $WORKSPACE/build/MSPrpm/*rpm $WORKSPACE/build/txYum/
  cd $WORKSPACE/build/txYum
  echo "---> ${THIS_SCRIPT}: Uploading RPMs from $WORKSPACE/build/txYum..."
  toYUM ; exitOnFail

  ## 3PP
  export yumpathUpload=$YUM/$YUML1/$YUML2/$YUML3PP/

  if [ -d /opt/afg3pp ]; then
    cd /opt/afg3pp
    ## patch for vsod to have RPM readable.
    echo "---> ${THIS_SCRIPT}: Setting permissions on files in /opt/afg3pp..."
    su emcscm -c "chmod 644 *.rpm"
    echo "---> ${THIS_SCRIPT}: Uploading files in /opt/afg3pp..."
    toYUM ; exitOnFail
  else
    echo "---> ${THIS_SCRIPT}: WARNING missing 3PP directory: /opt/afg3pp"
  fi

  ##TODO: patch for CURL error 60 use local repo
  if [[ ! -z "$YUMSERVERLOCAL" ]]; then
    echo "---> ${THIS_SCRIPT}:  Executing code for CURL patch for error 60 (use local repo $YUMSERVERLOCAL)"
    ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no root@$YUMSERVERLOCAL "[ ! -d /projects/TrafficOptimization/3PPs/afg3pp/ ] && mount seroisproj01006.sero.gic.ericsson.se:/proj010087/TrafficOptimization /projects/TrafficOptimization"
    ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no root@$YUMSERVERLOCAL  rm -fr /srv/www/vhosts/msp.emc.ca/*
    ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no root@$YUMSERVERLOCAL "cd /srv/www/vhosts/msp.emc.ca/; cp -r /projects/TrafficOptimization/3PPs/afg3pp/ ."

    scp -o StrictHostKeyChecking=no -o PasswordAuthentication=no  -r $WORKSPACE/build/AFGrpm root@$YUMSERVERLOCAL:/srv/www/vhosts/msp.emc.ca
    scp -o StrictHostKeyChecking=no -o PasswordAuthentication=no  -r $WORKSPACE/build/MNrpm root@$YUMSERVERLOCAL:/srv/www/vhosts/msp.emc.ca
    scp -o StrictHostKeyChecking=no -o PasswordAuthentication=no  -r $WORKSPACE/build/MSPrpm root@$YUMSERVERLOCAL:/srv/www/vhosts/msp.emc.ca

    ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no root@$YUMSERVERLOCAL  "createrepo  /srv/www/vhosts/msp.emc.ca/"
  fi

  echo "---> ${THIS_SCRIPT}: Upload RPM to YUM END  at `date`"

}

function testToYum() {

  [ ! -d $WORKSPACE/build/txYum/ ] && exitOnFail "vAFG no RPM upload here";
  export yumpathUpload=$YUM/$YUML1/$YUML2/$YUML3/
  cd  $WORKSPACE/build/txYum/
  for rpm in  `ls -1 * | sed 's/.rpm$//g'`
  do
    echo "## vAFG lookup $rpm   "
    zypper -q  -c /dev/null -p $yumpathUpload  search $rpm

    if [ $?  -ne 0 ]
    then
      exitOnFail "vAFG error RPM fetch on $rpm"
    fi
  done

}
#######################################################################
function toYUM() {

  touch ${WORKSPACE}/build/RPMtoYUM.log
  for f in *.rpm
  do
    echo "---> Copy file `pwd`/${f} to $yumpathUpload:  curl -u  $funcidu:$armmotoken -T $f -X PUT $yumpathUpload  START" >> ${WORKSPACE}/build/RPMtoYUM.log
    echo "---> Uploading $f to $yumpathUpload"
    if [ -n "$DEBUG" ]; then
      curl --silent -u  $funcidu:$armmotoken -T $f -X PUT $yumpathUpload >> $WORKSPACE/build/curl.log
    else
      curl --silent -u  $funcidu:$armmotoken -T $f -X PUT $yumpathUpload >> $WORKSPACE/build/curl.log
    fi
    echo "---> Copy file `pwd`/${f} to $yumpathUpload END" >> ${WORKSPACE}/build/RPMtoYUM.log
  done
}

#######################################################################
# Exit 1 if previous command fails
function exitOnFail() {
        if [ "$?" = "0" ]; then
                echo "---> Operation succeeded..." 1>&2
        else
                echo "*** ---> Operation failed... $1" 1>&2
                exit 1
        fi
}

#######################################################################
# Exit 1 if previous command fails, or mark unstable
function exitOnFailOrMarkUnstable() {
   if [ "$1" = "0" ]; then
           echo "---> Operation succeeded..." 1>&2
   elif [ "$1" = "4" ]; then
           echo "*** ---> Operation UNSTABLE..." 1>&2
           UNSTABLE=1
   else
           echo "*** ---> Operation FAILED..." 1>&2
           exit 1
   fi
}


#######################################################################
function buildImages()
{

        echo "-=-=-=-=-=-=-=-=-=-=-=-= VM build on many SSH host -=-=-=-=-=-=-=-=-=-=-STARTING"
        ### MAKE sure SSH pub key are installed TODO:

        for i in 1 2 3 4 5
        do
                NAME=VM$i
                COUNT=`grep ${SPVERSION,,}-pipeline-build ${WORKSPACE}/msp/devops/others/hosts  | grep VM$i | wc -l`
                if [ $COUNT -ne 1 ]; then
                        echo "Failed to locate the IP address for VM$i from devops/others/hosts file. Expected one found $COUNT. Exiting..."
                        exit 1
                fi

                IP=`grep ${SPVERSION,,}-pipeline-build ${WORKSPACE}/msp/devops/others/hosts  | grep VM$i | awk '{print $4}'`
                eval VM$i=$IP
                eval echo "VM$i=\$VM$i"
                ## TEST connection (password less ssh)
                NAME=VM$i
                ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o BatchMode=yes ${USER}@${!NAME} exit
                if [ "$?" != 0 ]; then
                        echo "ERROR: can not do SSH password less to $NAME - ${!NAME} exiting"
                        exit -1
                fi
        done

        #### creating work directories
        for i in 1 2 3 4 5
        do
                NAME=VM$i
                echo "-->AFG creating work directoies on $NAME - ${!NAME} "
                ssh -o StrictHostKeyChecking=no  ${USER}@${!NAME} "[ ! -d  $IMAGESWKDIR ] && mkdir $IMAGESWKDIR"
        done

        ## Copy the start files and run initial setup
        FILE_TX="${WORKSPACE}/build/build.properties ${WORKSPACE}/msp/devops/others/env.bash ${WORKSPACE}/msp/devops/build/image-env-setup.bash"
        for i in 1 2 3 4 5
        do
                NAME=VM$i
                echo "-->AFG Copy the start files and running the initial setup on $NAME - ${!NAME} files: $FILE_TX "
                scp -o StrictHostKeyChecking=no $FILE_TX ${USER}@${!NAME}:$IMAGESWKDIR
                ssh -o StrictHostKeyChecking=no  ${USER}@${!NAME} "cd $IMAGESWKDIR; bash ./image-env-setup.bash"
        done


        echo -e "\n\n---> ${THIS_SCRIPT}:Building the AFG Images in parallel...\n\n"
        #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-RUN SSH jobs#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
        NAME=VM1 ## DDC
        ( ssh -o StrictHostKeyChecking=no -t -t ${USER}@${!NAME} "export WORKSPACE=$IMAGESWKDIR; cd $IMAGESWKDIR; $IMAGESWKDIR/msp/devops/build/images-ddc.bash" </dev/null >  $WORKSPACE/build/ddc-image.log 2>&1 )&
        export pids+=" $!"
        #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
        NAME=VM2 ## MN
        ( ssh -o StrictHostKeyChecking=no -t -t ${USER}@${!NAME} "export WORKSPACE=$IMAGESWKDIR; cd $IMAGESWKDIR; $IMAGESWKDIR/msp/devops/build/images-mn.bash" </dev/null >  $WORKSPACE/build/mn-image.log 2>&1 )&
        export pids+=" $!"
        #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
        NAME=VM3 ## MON
        ( ssh -o StrictHostKeyChecking=no -t -t ${USER}@${!NAME} "export WORKSPACE=$IMAGESWKDIR; cd $IMAGESWKDIR; $IMAGESWKDIR/msp/devops/build/images-mon.bash" </dev/null >  $WORKSPACE/build/mon-image.log 2>&1 )&
        export pids+=" $!"
        #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
        NAME=VM4 ## SLB
        ( ssh -o StrictHostKeyChecking=no -t -t ${USER}@${!NAME} "export WORKSPACE=$IMAGESWKDIR; cd $IMAGESWKDIR; $IMAGESWKDIR/msp/devops/build/images-slb.bash" </dev/null >  $WORKSPACE/build/slb-image.log 2>&1 )&
        export pids+=" $!"
        #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
        NAME=VM5 ## TS
        ( ssh -o StrictHostKeyChecking=no -t -t ${USER}@${!NAME} "export WORKSPACE=$IMAGESWKDIR; cd $IMAGESWKDIR; $IMAGESWKDIR/msp/devops/build/images-ts.bash" </dev/null >  $WORKSPACE/build/ts-image.log 2>&1 )&
        export pids+=" $!"
        #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-


        ps -ef | grep "[s]sh -o StrictHostKeyChecking=no" > $WORKSPACE/build/pidMapFiles.log
        cat $WORKSPACE/build/pidMapFiles.log

        echo "-=-=-=-=-=-=-=-=-=-=-=-= VM build on many SSH host -=-=-=-=-=-=-=-=-=-=-STARTED"

}



#######################################################################

function generateAfgSuppIso()
{

  echo "---> ${THIS_SCRIPT}: Generating Supplementary ISO START at `date`"

  echo
  echo "################################################################################"
  echo "### Generate AFG Supplementary ISO START"
  echo "################################################################################"

  if [ -d /tmp/AFG_supp ]; then
    rm -rf /tmp/AFG_supp
  fi

  # remove of iso files
  if ls /tmp/afg_supp-*.iso  1> /dev/null 2>&1; then
    rm /tmp/afg_supp-*.iso
  fi

  mkdir -p /tmp/AFG_supp/mn_setup
  cp $WORKSPACE/msp/PAL/PALFB/PALCONFIGSRV/config.xml /tmp/AFG_supp/mn_setup/
  cp $WORKSPACE/msp/DMS/config/distributed_data_cache.cfg /tmp/AFG_supp/mn_setup/

  # Exit the script if any of these copy/wget commands fail.

  touch $WORKSPACE/wget.log
  (
    cd  /tmp/AFG_supp/mn_setup/
    echo " ---> ${THIS_SCRIPT}: Downloading MSPwfafg RPMs from $YUM/$YUML1/$YUML2/$YUML3/ ..."
    wget --no-proxy -l 1 -nd -r -A 'MSPwfafg*.rpm' $YUM/$YUML1/$YUML2/$YUML3/  > $WORKSPACE/build/wget.log 2>&1
    exitOnFail " wget of MSPwfafg failed. "
  )

  cp $WORKSPACE/msp/ZUP/kiwi/distribution/sles12/afgvm/init-bsf-template-dashboard.sql /tmp/AFG_supp/mn_setup/; exitOnFail "Failed to copy init-bsf-template-dashboard.sql"
  cp $WORKSPACE/msp/ZUP/kiwi/distribution/sles12/afgvm/init-ap-template-dashboard.sql /tmp/AFG_supp/mn_setup/; exitOnFail "Failed to copy init-ap-template-dashboard.sql"

  mkdir -p /tmp/AFG_supp/software; exitOnFail "Failed to to create directory /tmp/AFG_supp/software"
  (
     cd  /tmp/AFG_supp/software/
     echo " ---> ${THIS_SCRIPT}: Downloading MSPesaconf RPMs from $YUM/$YUML1/$YUML2/$YUML3/ ..."
     wget --no-proxy -l 1 -nd -r -A 'MSPesaconf*.rpm' $YUM/$YUML1/$YUML2/$YUML3/  > $WORKSPACE/build/wget.log 2>&1
     exitOnFail "download of MSPesacon rpms failed"
  )
  if [ -f /opt/afg3pp/esa-20.0.0.1410.rpm ]
  then
    echo "AFG SUP ISO: copy /opt/afg3pp/esa-20.0.0.1410.rpm to AFG_supp iso"
    cp /opt/afg3pp/esa-20.0.0.1410.rpm  /tmp/AFG_supp/software/ ; exitOnFail "Failed to copy esa-20.0.0.1410.rpm"
  else
    echo "AFG SUP ISO: /opt/afg3pp/esa-20.0.0.1410.rpm NOT found"
  fi


  # get the postgresql version used to create the DB (needed for DB upgrade)
  mkdir -p /tmp/AFG_supp/software/upgrade; exitOnFail "Failed to to create directory /tmp/AFG_supp/software/upgrade"
  (
    cd /tmp/AFG_supp/software/upgrade
    echo "---> ${THIS_SCRIPT}: Downloading postgresql94-9.4.13-21.5.1.x86_64.rpm ... "
    cp  /projects/TrafficOptimization/3PPs/afg3pp/postgres/postgresql94/postgresql94-9.4.13-21.5.1.x86_64.rpm  /tmp/AFG_supp/software/upgrade
    exitOnFail "*** FAIL cp of  postgresql94-9.4.13-21.5.1.x86_64.rpm "
    cp  /projects/TrafficOptimization/3PPs/afg3pp/postgres/postgresql94/postgresql94-contrib-9.4.13-21.5.1.x86_64.rpm  /tmp/AFG_supp/software/upgrade
    exitOnFail "*** FAIL cp postgresql94-contrib-9.4.13-21.5.1.x86_64.rpm"
    cp  /projects/TrafficOptimization/3PPs/afg3pp/postgres/postgresql94/postgresql94-server-9.4.13-21.5.1.x86_64.rpm  /tmp/AFG_supp/software/upgrade
    exitOnFail "*** FAIL cp postgresql94-server-9.4.13-21.5.1.x86_64.rpm "
    echo "---> ${THIS_SCRIPT}: Downloading Postgress RPMs Done."
  )

  mkdir -p /tmp/AFG_supp/scripts
  cp -p $WORKSPACE/msp/ZUP/kiwi/distribution/sles12/afgvm/hardening.sh   /tmp/AFG_supp/scripts/
  cp -p $WORKSPACE/msp/ZUP/kiwi/distribution/sles12/afgvm/workarounds.sh /tmp/AFG_supp/scripts/
  mkdir -p /tmp/AFG_supp/scripts/slbspv
  cp -p $WORKSPACE/msp/ZUP/kiwi/distribution/sles12/afgvm/slbspv/* /tmp/AFG_supp/scripts/slbspv/
  mkdir -p /tmp/AFG_supp/scripts/user-data
  cp -p $WORKSPACE/msp/ZUP/kiwi/distribution/sles12/afgvm/scripts/user-data/runcmd* /tmp/AFG_supp/scripts/user-data/


  echo "---> ${THIS_SCRIPT}: Calling genisoimage  -output /tmp/afg_supp-${MSPRELMAJ}-${BUILD_NUMBER}.iso -volid cidata -joliet -rock /tmp/AFG_supp/  ...."
  genisoimage  -output /tmp/afg_supp-${MSPRELMAJ}-${BUILD_NUMBER}.iso -volid cidata -joliet -rock /tmp/AFG_supp/
  echo "--> ${THIS_SCRIPT}: Uploading file /tmp/afg_supp-${MSPRELMAJ}-${BUILD_NUMBER}.iso -X PUT $YUM/$YUML1/$YUML2/$YUML3/"
  curl --silent -u  $funcidu:$armmotoken -T /tmp/afg_supp-${MSPRELMAJ}-${BUILD_NUMBER}.iso -X PUT $YUM/$YUML1/$YUML2/$YUML3/ >> $WORKSPACE/build/curl.log

  echo "---> ${THIS_SCRIPT}: Generating Supplementary ISO END at `date`"
}


#######################################################################
# Upload all artfifacts under build/ folder
function pushArtifactsToArm() {

        echo "---> ${THIS_SCRIPT}: Upload artifacts to ARM START at `date`"


        echo "--> AFG listing build artfacts"
        cd $WORKSPACE/artifacts/
        find .

        for f in `ls ${AFG_TAR_CEE} ${AFG_TAR_VCD}`
        do
    echo "--> ${THIS_SCRIPT}: Uploading file $f to ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ ..."
                curl --silent -u $funcidu:$armmotoken -T $f -X PUT  ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ >> $WORKSPACE/build/curl.log ; exitOnFail
        done

        for f in `ls *${AFG_UNSTRIPPED_PRODNO}*`
        do
    echo "--> ${THIS_SCRIPT}: Uploading file $f to ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ ..."
                curl --silent -u $funcidu:$armmotoken -T $f -X PUT  ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ >> $WORKSPACE/build/curl.log ; exitOnFail
        done

        for f in `ls *${AFG_ENAF_PRONO}*`
        do
    echo "--> ${THIS_SCRIPT}: Uploading file $f to ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ ..."
                curl --silent -u $funcidu:$armmotoken -T $f -X PUT  ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ >> $WORKSPACE/build/curl.log ; exitOnFail
        done

        #for f in `ls *${AFG_LCM_PRODNO}*`
        #do
    #echo "--> ${THIS_SCRIPT}: Uploading file $f to ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ ..."
                #curl --silent -u $funcidu:$armmotoken -T $f -X PUT  ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ >> $WORKSPACE/build/curl.log; exitOnFail
        #done

        for f in `ls *${AFG_TOSCA_CEE_PRODNO}*`
        do
    echo "--> ${THIS_SCRIPT}: Uploading file $f to ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ ..."
                curl --silent -u $funcidu:$armmotoken -T $f -X PUT  ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ >> $WORKSPACE/build/curl.log; exitOnFail
        done

        for f in `ls *${AFG_TOSCA_VCD_PRODNO}*`
        do
    echo "--> ${THIS_SCRIPT}: Uploading file $f to ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ ..."
                curl --silent -u $funcidu:$armmotoken -T $f -X PUT  ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ >> $WORKSPACE/build/curl.log; exitOnFail
        done

        for f in `ls *${AFG_SRC}*`
        do
    echo "--> ${THIS_SCRIPT}: Uploading file $f to ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ ..."
                curl --silent -u $funcidu:$armmotoken -T $f -X PUT  ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ >> $WORKSPACE/build/curl.log; exitOnFail
        done

        for f in `ls $PUBLISH_DIR/$BRANCH_AFG/image-root-*.log`
        do
    echo "--> ${THIS_SCRIPT}: Uploading file $f to ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ ..."
                curl --silent -u $funcidu:$armmotoken -T $f -X PUT  ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/log/ >> $WORKSPACE/build/curl.log; exitOnFail
        done

        for f in `ls *${AFG_MD5SUM_PRODNO}*txt`
        do
    echo "--> ${THIS_SCRIPT}: Uploading file $f to ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ ..."
                curl --silent -u $funcidu:$armmotoken -T $f -X PUT  ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/ >> $WORKSPACE/build/curl.log; exitOnFail
        done

        # Setup the last build number
        if [ -f $WORKSPACE/build.properties ]
        then
                echo "---> ${THIS_SCRIPT}: Upload the last sucessful build.property file to  ${ARTIFACT_LOCATION}/build.properties and ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER} "
                curl --silent -u $funcidu:$armmotoken -T $WORKSPACE/build.properties -X PUT  ${ARTIFACT_LOCATION}/build.properties >> $WORKSPACE/build/curl.log; exitOnFail
                curl --silent -u $funcidu:$armmotoken -T $WORKSPACE/build.properties -X PUT  ${ARTIFACT_LOCATION}/${BRANCH_AFG}/${AFG_MSPRELMAJ}-${BUILD_NUMBER}/build.properties >> $WORKSPACE/build/curl.log; exitOnFail
        fi

        echo "---> ${THIS_SCRIPT}: Upload artifacts to ARM END at `date`"
}



#######################################################################
function generateReleaseNotes() {

  echo "---> ${THIS_SCRIPT}: generateReleaseNotes START "

  # Download the PET tarball which contains all the PET libraries, executable, etc

  echo "---> ${THIS_SCRIPT}: Downloading PET tarball from $PET_DOWNLOAD_URL..."
  cd $WORKSPACE
  wget --quiet --no-proxy $PET_DOWNLOAD_URL
  STATUS=$?

  if [ $STATUS -ne 0 ]; then
    echo "---> ${THIS_SCRIPT}: ERROR Downloading PET tarball from URL $PET_DOWNLOAD_URL\nSTATUS=$STATUS"
    exit 1
  fi

  # Get the filename from the URL

  FILENAME=`basename $PET_DOWNLOAD_URL`

  # Determine the root directory that the tar ball will extract to. We will need it later

  PET_DIR=`tar tvfz $FILENAME | head -1 | awk '{print $NF}'`
  export PET_DIR

  # extract the PET tarball which contains all the PET libraries

  echo "---> ${THIS_SCRIPT}: Untarring the tarball..."
  tar zxf $FILENAME
  STATUS=$?
  if [ $STATUS -ne 0 ]; then
    echo "---> ${THIS_SCRIPT}: ERROR extracting the tarball $FILENAME. Exiting..."
    exit 1
  fi

  # Remove the tar.gz file

  rm $FILENAME

  # Call our script....
  echo "---> ${THIS_SCRIPT}: Generating release notes with command: ${WORKSPACE}/msp/devops/pet/bin/generate_release_notes.bash"
  echo "---> ${THIS_SCRIPT}:       NOTE: Logs are stored in $WORKSPACE/build/GenerateReleaseNotes.log"

  ${WORKSPACE}/msp/devops/pet/bin/generate_release_notes.bash > $WORKSPACE/build/GenerateReleaseNotes.log
  STATUS=$?
  if [ $STATUS -ne 0 ]; then
    echo "---> ${THIS_SCRIPT}: ERROR generating the release notes. Call to ${WORKSPACE}/msp/pet/bin/generate_release_notes.bash failed. Exiting..."
#    exit 1
  fi

  # We need to copy it to the artifacts directory
  # mv   releasenotes.html  $WORKSPACE/build/artifacts/

  echo "---> ${THIS_SCRIPT}: generateReleaseNotes END"

}


#######################################################################
function pushArtifactsToPublishDir() {

        echo "---> ${THIS_SCRIPT}: Store build at TrafficOptimization drive START at `date`"

        PROJDIR=${shareDrive}/CI/AFG2/${PRODUCTVERSION}
        if [ ! -d ${PROJDIR} ]; then
                 su emcscm -c "mkdir -p ${PROJDIR}"
        fi

        echo "---> ${THIS_SCRIPT}: copy ARTIFACTS to $PROJDIR"
        cd      $WORKSPACE/artifacts/
        su emcscm -c "cp -r * $PROJDIR"

        echo "---> ${THIS_SCRIPT}: Share drive $PROJDIR artifacts: "
        ls -lR $PROJDIR
        find $PROJDIR -type f > $WORKSPACE/build/artifact_on_share_drive.txt

        echo "---> ${THIS_SCRIPT}: Store build at TrafficOptimization drive END at `date`"
}


#######################################################################
function checkUnstrippedBinary() {

  echo "---> ${THIS_SCRIPT}: Check if unstripped binary is updated. START at `date`"

  PROJDIR=${shareDrive}/CI/AFG2/${PRODUCTVERSION}

  echo "---> ${THIS_SCRIPT}: untar unstripped binary from $PROJDIR"
  cd /tmp
  if [ -d unstriped ]; then
    rm -rf unstriped
  fi
  tar xf $PROJDIR/*-unstrip*.tar
  cd unstriped

  echo "---> ${THIS_SCRIPT}: verify unstripped file timestamps"
  today=`date +%Y-%m-%d`
  now=`date +%H`
  yesterday=`date --date='yesterday' +%Y-%m-%d`
  for f in `ls .`
  do
    stat -c %y $f | grep $today > /dev/null
    if [ $? -ne  0 ] && [ $now == "00" ]; then
      # in case the build ran over midnight, check yesterday
      stat -c %y $f | grep $yesterday > /dev/null
      if [ $? -ne  0 ]; then
        echo "ERROR: ${f} is not generated on ${today}"
        UNSTABLE=1
      fi
    fi
  done

  echo "---> ${THIS_SCRIPT}: verify unstripped process versions"
  for p in palhttpsync traffic_regulator distributed_data_cache nodesupervisor telserver slbtm whttp
  do
    version=`./${p} -version | awk -F ',' '{print $4}' | awk -F '=' '{print $2}'`
    if [ $PRODUCTVERSION != $version ]; then
      echo "ERROR: The ${p} version, ${version}, does not match the product version, ${PRODUCTVERSION}."
      UNSTABLE=1
    fi
  done

  # Clean up
  cd /tmp
  rm -rf unstriped

  echo "---> ${THIS_SCRIPT}: Checked unstripped binary. Set UNSTABLE in case of anything wrong. END at `date`"
}



#######################################################################
# MAIN function
function main()
{
  echo "Check the current disk usage"
  df -h

  #####################################################
  # Common steps to set variables environments        #
  #####################################################

  if [ ! -f ${WORKSPACE}/msp/devops/others/env.bash ]; then
    echo "ERROR: can not read: ${WORKSPACE}/msp/devops/others/env.bash"
    exit -1
  fi

  . ${WORKSPACE}/msp/devops/others/env.bash
  mountPrj ; exitOnFail

  export SPVERSION="${SPVERSION:-SP3}"

  cd $WORKSPACE
  # Prapare build folder for artifacts
  createBuildFolder ; exitOnFail

  cleanUPbuildSpace ; exitOnFail

  ## setup build environement
  setupBuildEnv ; exitOnFail

  # Compile AFG
  # MON and MON build scripts are semsible to PROJBASE
  sed -e '/export PROJBASE/ s/^#*/#/' -i /etc/profile.local
  compileAFG   ; exitOnFail

  compileMN ; exitOnFail

  buildMspRpm ; exitOnFail

  uploadToYUM ; exitOnFail

  # Workaround for Artifactory upgrade: time delay to allow Artifactory rpm repo index to complete calculation
  sleep 10
  testToYum; exitOnFail

  generateAfgSuppIso ; exitOnFail

  ## prepare to VM storage
  [ ! -d $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG ] && su emcscm -c "mkdir -p $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG"
  [ ! -d $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/Backup ] && su emcscm -c "mkdir -p $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/Backup/"
  if ls $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/Backup/*.* > /dev/null 2>&1; then
    su emcscm -c "rm  $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/Backup/*.*"
  fi

  if ls $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*qcow2 > /dev/null 2>&1; then
    su emcscm -c "mv $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*qcow2 $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/Backup/"
  fi
  if ls $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*vmdk  > /dev/null 2>&1; then
    su emcscm -c "mv $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*vmdk $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/Backup/"
  fi
  if ls $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*.iso > /dev/null 2>&1; then
    su emcscm -c "mv $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*.iso $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/Backup/"
  fi
  if ls $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*.log > /dev/null 2>&1; then
    su emcscm -c "mv $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*.log $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/Backup/"
  fi
  if ls $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*.packages > /dev/null 2>&1; then
    su emcscm -c "mv $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*.packages $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/Backup/"
  fi

  echo "Check the current disk usage"
  df -h


  ## Start image build is parallel
  buildImages ; exitOnFail

  ## Produce FT tar for DEV/RBT testing
  [ -d $WORKSPACE/ft ] && rm -fr  $WORKSPACE/ft
  mkdir $WORKSPACE/ft
  cd $WORKSPACE/ft
  echo "---> ${THIS_SCRIPT}: Creating file $WORKSPACE/ft/ft-dev-${BUILD_NUMBER}.tz..."
  tar --absolute-names -czf ft-dev-${BUILD_NUMBER}.tz  /tmp/cmake_build/APS/APTL/APTLTOOLS/OfflineLicenseGenerator/OfflineLicGen.jar /tmp/msp_release_tmp/
  echo "---> ${THIS_SCRIPT}: uploading file $WORKSPACE/ft/ft-dev-${BUILD_NUMBER}.tz to $YUM/$YUML1/$YUML2/$YUML3/ ..."
  curl --silent -u  $funcidu:$armmotoken -T $WORKSPACE/ft/ft-dev-${BUILD_NUMBER}.tz  -X PUT $YUM/$YUML1/$YUML2/$YUML3/ >> $WORKSPACE/build/curl.log

  ## do Unit test ------ TODO: fix .m2 dependency
  #STMC  ${WORKSPACE}/msp/devops/build/unit_test.bash ; exitOnFailOrMarkUnstable $?
  ${WORKSPACE}/msp/devops/build/unit_test.bash > $WORKSPACE/build/unit_test_results.log 2>&1
  STATUS=$?
  echo "---> ${THIS_SCRIPT}: Verifying the result of the unit test...."
  exitOnFailOrMarkUnstable $STATUS

  # set -e

  ## wait images
  echo "--> AFG: wait for PIDS: $pids"
  for p in $pids; do
    if wait $p; then
      echo "Process $p success"
    else
      echo "Process $p fail"
      exitStatus='YELLOW'
    fi
  done

  ## check for error in image log files
  cd $WORKSPACE/build/
  for log in *-image.log
  do
    echo "-->AFG log analysis on $log"
    $WORKSPACE/devops/others/scanForErrors.py --dictionary $WORKSPACE/devops/build/Errors-Pathern-Images.log --logfile $WORKSPACE/build/$log
    if [ "$?" = "0" ]
    then
      echo "OK for analysis on $log"
    else
      mv $WORKSPACE/build/$log $WORKSPACE/build/FAIL-$log
      echo -e "\n---> ${THIS_SCRIPT}: test FAIL for $WORKSPACE/build/FAIL-$log"
      exit 1
    fi
  done

  ## copy the full image log to build for archiving
  for log in $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/image-root-*.log
  do
    echo "---> ${THIS_SCRIPT}: backup full image log for: $log"
    cp $log  $WORKSPACE/build/
  done

  ## copy the pakages list for archiving
  for pak in $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*.packages
  do
    echo "---> ${THIS_SCRIPT}: backup pakages list for: $pak"
    cp $pak  $WORKSPACE/build/
  done

  echo "---> ${THIS_SCRIPT}: check TS kernel mismatch START "
  echo "   ---> ${THIS_SCRIPT}: Extracting build_kernel_major/minor from $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*TS*.packages..."
  origIFS=$IFS
  build_kernel=`grep kernel-default $PUBLISH_DIR/${MSPRELMAJ}/$BRANCH_AFG/*TS*.packages`
  if [ $? -eq 0 ]; then
     echo "build_kernel: $build_kernel"
  else
     echo "Something went wrong!"
     exit 1
  fi

  IFS='|' build_kernel_array=(${build_kernel})
  build_kernel_major=${build_kernel_array[2]}
  build_kernel_minor=${build_kernel_array[3]}

  server_kernel=`uname -r`
  IFS='-' server_kernel_array=(${server_kernel})
  server_kernel_major=${server_kernel_array[0]}
  server_kernel_minor=${server_kernel_array[1]}

  echo "      Build kernel major : $build_kernel_major , minor: $build_kernel_minor"
  echo "      Server kernel major: $server_kernel_major , minor: $server_kernel_minor"

  #if [[ $build_kernel_major == "$server_kernel_major" ]] && [[ $build_kernel_minor == "$server_kernel_minor"* ]]; then
     #echo "      Kernel checked !"
  #else
     #echo "      Error: Kernel mismatch !"
     #exit 1
  #fi
  IFS=$origIFS
  echo "---> ${THIS_SCRIPT}: check TS kernel mismatch END "

  ## do packaging
  echo "---> ${THIS_SCRIPT}: packaging_artifacts START "
  echo "bash ${WORKSPACE}/msp/devops/build/packaging_artifacts.bash > $WORKSPACE/build/packaging_artifacts.log"
  bash ${WORKSPACE}/msp/devops/build/packaging_artifacts.bash > $WORKSPACE/build/packaging_artifacts.log
  if [ $? -ne 0 ]; then
     echo "*** ---> packaging_artifacts failed..."
     exit 1
  fi
  echo "---> ${THIS_SCRIPT}: packaging_artifacts END "

  ## push artifacts to PUBLISH DIR
  pushArtifactsToPublishDir ; exitOnFail

  ## Generate the release notes
  generateReleaseNotes ; exitOnFail

  ## push artifacts to artifactory
  pushArtifactsToArm ; exitOnFail

  ## check if unstripped binary is updated
  checkUnstrippedBinary ; exitOnFail

  echo "Check the current disk usage"
  df -h

  ## catch unit test failures and mark the build unstable
  if [ $UNSTABLE -eq 1 ]; then
    echo "*** ---> Build is UNSTABLE "
    set +e
    exit 4
  fi
}

#######################################################################
#######################################################################
# Calling the main function

echo "---> script: dirname=`pwd`    filename=$0  ...[START]"
main
echo "---> script: dirname=`pwd`    filename=$0  ...[END]"

