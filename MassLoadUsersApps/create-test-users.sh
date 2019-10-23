#!/bin/bash
# AXWAY API Manager - Plattform Verification Test
#
# Purpose: Setup API-Portal test environment to support performance test of API Portal.
#          As API Portal speed depends on API Manager REST API performance we can create a critical count of objects for this tests.
#
# Author:  Rene Kiessling, Axway GmbH
#
# Version: 1.4
#
# ChangeLog:
# 22.10.2019 - some comments and refernced corrected
# 17.10.2019 - apps are now created by the individual user instead of the api-admin in order to
#              create entries for relations between app and owners (whcih is not done for API admins).
# 14.10.2019 - test extended to create one app per user (without API subscription)
#              first the org-id for the refrenced org-name is read (check for org existance)
# 11.12.2018 - newly created to allow for API Portal test preparation; mass loading users
#              incl. CSRF-Token handling needed since API-Manager v7.5.3-SP9 for API-Manager REST API v1.3
# 11.12.2018 - error handling added
#            - cli paramter evaluation added
#

# CLI Parameters
for i in "$@"
do
case $i in
    -f=*|--file=*)
    ACCOUNTSFILE="${i#*=}"
    shift # past argument=value
    ;;
    -u=*|--user=*)
    ADMUSER="${i#*=}"
    shift # past argument=value
    ;;
    -p=*|--password=*)
    ADMPASS="${i#*=}"
    shift # past argument=value
    ;;
    -t=*|--target=*)
    APIMANAGER="${i#*=}"
    shift # past argument=value
    ;;
    -d|--debug)
    DEBUGFLAG="yes"
    shift # past argument=value
    ;;
    *)
          # unknown option
    ;;
esac
done

# Check parameters
if [[ -z "$ADMUSER" || -z "$ADMPASS" || -z "APIMANAGER" ]]; then
  printf "ERROR: Needed parameter not provided\n"
  printf "$0\n"
  printf "  -f=<inputfile> | --file=<inputfile>\n"
  printf "  -u=<apimanageradmin> | --user=<apimanageradmin>\n"
  printf "  -p=<password> | --password=<password>\n"
  printf "  -t=<apimanagerurl> | --target=<apimanagerurl>\n"
  printf "  -d | --debug\n"
  exit 1
fi

# Check if input file exists and is readable
if [[ ! -r "$ACCOUNTSFILE" || ! -f "$ACCOUNTSFILE" ]]; then
  printf "ERROR: User account input file does not exist.\n"
  exit 1
fi

# Function Declarations
function writeDebugText {
  if [[ "$DEBUGFLAG" = "yes" ]]; then
    printf "DEBUG: $1\n"
  fi
}

# ---------------------------------------
# Establish API Manager REST API Session
# ---------------------------------------
curl -vk -G \
-XPOST https://$APIMANAGER/api/portal/v1.3/login \
-H "Content-Type: application/x-www-form-urlencoded" \
--data "username=$ADMUSER&password=$ADMPASS" > callreply.txt 2> callheader.txt

SESSION=`cat callheader.txt | grep "Set-Cookie:" | sed -e "s/.*Set-Cookie: //" | sed -e "s/Version=.*//" | sed 'h;s/.*//;N;G;s/\n//g'`
writeDebugText "Session-Cookie = $SESSION"
CSRFTKN=`cat callheader.txt | grep "CSRF-Token:" | sed -e "s/.*CSRF-Token: //" | sed -e "s/\r//" | sed -e "s/\n//"`
writeDebugText "CSRF-Token = [$CSRFTKN]"
rm -f callreply.txt callheader.txt

if [[ -z "$SESSION" || -z "$CSRFTKN" ]]; then
  printf "ERROR: API-Manager Login failed.\n"
  exit 1
fi

# ------------------------------------------------
# CREATE Accounts for Org "LoadTestOrg"
# ------------------------------------------------

# Expected sample line:
#       ORG         USER-NAME    LOGIN-NAME                      E-MAIL                          PASSWORD   ROLE DESCRIPTION
# -;x;x;LoadTestOrg;David Tester;david.tester@enterprise-tst.com;david.tester@enterprise-tst.com;<password>;user;Account fuer Plattform- und API-Portal-Tests

# init App counter
APPCNT=1
# Loop over all Lines in Input File (customer data)
cat $ACCOUNTSFILE | while read myline; 
do
  writeDebugText "data=$myline"
  IFS=';' read -r -a lineArray <<< "$myline"
  ORGNAME="${lineArray[3]}"
  USRNAME="${lineArray[4]}"
  if [[ -z "$ORGNAME" || -z "$USRNAME" ]]; then
    printf "ERROR: read line did not include organization or account name.\n"
    exit 1
  fi
  printf "CREATING ACCOUNT: $USRNAME within Organization $ORGNAME\n"

  # Get ORGANIZATION Details (ID is needed for subseqent User API calls)
  curl -vk \
  -H "Cookie: $SESSION" \
  -H "CSRF-Token: $CSRFTKN" \
  -XGET "https://$APIMANAGER/api/portal/v1.3/organizations?field=name&op=eq&value=$ORGNAME" > callreply.txt 2> callheader.txt

  ORGID=`cat callreply.txt | grep '{"id":"' | sed -e 's/.*{"id":"//' | sed -e 's/",".*//'`
  writeDebugText "Org-Name=$ORGNAME, Org-ID=$ORGID"
  if [[ -z "$ORGID" ]]; then
    printf "ERROR: No organisation details received for $ORGNAME. Does the organisation exist in API-Manager?\n"
    exit 1
  fi

  CSRFTKN=`cat callheader.txt | grep "CSRF-Token:" | sed -e "s/.*CSRF-Token: //" | sed -e "s/\r//" | sed -e "s/\n//"`
  writeDebugText "CSRF Token = [$CSRFTKN]"
  rm -f callreply.txt callheader.txt

  # compile user account creation message
  DESCRIPTION="${lineArray[9]}"
  DESCRIPTION="${DESCRIPTION//[$'\t\r\n']}"
  LOGINNAME="${lineArray[5]}"
  USEREMAIL="${lineArray[5]}"
  USERROLE="${lineArray[8]}"
  rm -f calldata.txt
  printf "{" >> calldata.txt
  printf "\"organizationId\": \"$ORGID\", " >> calldata.txt
  printf "\"name\": \"$USRNAME\", " >> calldata.txt
  printf "\"description\": \"$DESCRIPTION\", " >> calldata.txt
  printf "\"loginName\": \"$LOGINNAME\", " >> calldata.txt
  printf "\"email\": \"$USEREMAIL\", " >> calldata.txt
  printf "\"role\": \"$USERROLE\", " >> calldata.txt
  printf "\"enabled\": true, " >> calldata.txt
  printf "\"state\": \"approved\", " >> calldata.txt
  printf "\"type\": \"internal\" " >> calldata.txt
  printf "}" >> calldata.txt

  # CREATE USER at API-Manager
  #-H "Content-Type: application/json; charset=utf-8"
  curl -vk \
  -H "Cookie: $SESSION" \
  -H "CSRF-Token: $CSRFTKN" \
  -H "Content-Type: application/json" \
  --url https://$APIMANAGER/api/portal/v1.3/users \
  --data-binary "@calldata.txt" > callreply.txt 2> callheader.txt

  CSRFTKN=`cat callheader.txt | grep "CSRF-Token:" | sed -e "s/.*CSRF-Token: //" | sed -e "s/\r//" | sed -e "s/\n//"`
  writeDebugText "CSRF-Token = [$CSRFTKN]"
  NEWUSERID=`cat callreply.txt | grep '{"id":"' | sed -e 's/{"id":"//' | sed -e 's/",".*//'`
  writeDebugText "New User ID = $NEWUSERID"
  if [[ -z "$NEWUSERID" ]]; then
    printf "ERROR: Creation of account $USRNAME within organisation $ORGNAME failed.\n"
	cat callreply.txt; printf "\n"
  fi
  rm -f callreply.txt callheader.txt calldata.txt

  # SET USER Start Password
  STARTPWD="${lineArray[7]}"
  curl -vk \
  --url "https://$APIMANAGER/api/portal/v1.3/users/$NEWUSERID/changepassword" \
  -H "Cookie: $SESSION" \
  -H "CSRF-Token: $CSRFTKN" \
  --data-urlencode "newPassword=$STARTPWD" > callreply.txt 2> callheader.txt
  HTTPSTATUS=`cat callheader.txt | grep '< HTTP/1.1' | sed -e 's/< HTTP\/1.1 //'`
  if [[ $HTTPSTATUS != *"204"* ]]; then
    printf "ERROR: could not set start password for $USRNAME. Return code: $HTTPSTATUS\n"
  fi
  rm -f callreply.txt callheader.txt

  # REGISTER (add new) APP (one per user - without API subscription)
  rm -f calldata.txt
  printf "{\n" >> calldata.txt
  printf "\"name\": \"TEST-APP-$APPCNT\", \n" >> calldata.txt
  printf "\"organizationId\": \"$ORGID\", \n" >> calldata.txt
  printf "\"description\": \"API-Manager API performance test app.\", \n" >> calldata.txt
  printf "\"email\": \"$USEREMAIL\", \n" >> calldata.txt
  printf "\"apis\": [], \n" >> calldata.txt
  printf "\"enabled\": true, \n" >> calldata.txt
  printf "\"state\": \"approved\"\n" >> calldata.txt
  printf "}" >> calldata.txt

  # App must be added as owning user. If added as apiadmin the link table will not be filled!
  # It seems to be important who the owner of the app is. And always the current user will become app owner.
  # (or we need to give a user app managment rights afterwards)
  curl -vk \
  --user "$LOGINNAME:$STARTPWD" \
  -H "Content-Type: application/json" \
  --url https://$APIMANAGER/api/portal/v1.3/applications \
  --data-binary "@calldata.txt" > callreply.txt 2> callheader.txt
  HTTPSTATUS=`cat callheader.txt | grep '< HTTP/1.1' | sed -e 's/< HTTP\/1.1 //'`
  if [[ $HTTPSTATUS != *"201"* ]]; then
    printf "ERROR: could register an app for $USRNAME. Return code: $HTTPSTATUS\n"
	if [[ $DEBUGFLAG = "yes" ]]; then
      printf "DEBUG INFO (call):\n"
	  cat calldata.txt
      printf "DEBUG INFO (reply):\n"
	  cat callreply.txt
	fi
  fi
  rm -f callreply.txt callheader.txt
  
  APPCNT=$((APPCNT+1))
done
