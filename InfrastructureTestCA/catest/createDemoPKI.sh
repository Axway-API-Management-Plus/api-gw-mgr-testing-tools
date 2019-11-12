#!/bin/bash
# This script will use openSSL in order to create some key/cert combinations to be able to
# test PKI infrastructures like Axway API Gateway and API Manager from end-to-end (client to backend).
# The demo CA also produces the files needed for CRL or OCSP responders. But those functions are
# not yet part of the demo CA.
# The script was originally inspired by a article at http://www.securityfocus.com/print/infocus/1466.
# As for many POC's it was difficult to receive appropriate keys and X.509 certs for an end-to-end test
# we simply create our own ones. Doing so it's even possible to add special attributes to certificates.
# Someting that man enterprise PKI's do not allow via their standard interfaces.
#
# Author:       Rene Kiessling, Axway GmbH, DE
# last changed: 11.09.2019
# 
# Change Log:
# 11.09.2019
#  - correction of the reference to client cert options within openssl config file (mismatch before)
#  - some debug expressions to verify the openssl commands that are created and executed
#  - changed some comments for better descriptions
# 27.03.2019
#  - parameter file for generating certs changed to create extended key usage for servers and clients
#    according to their use as TLS server of client (different template files for server and client certs)
# 25.02.2019
#  - added days parameter creating certs for a certain validity period
#  - certificate serials now start at a random number between 1 an 10000
# 
clear

# environment definitions
curPath=`pwd`
paramPath=$curPath/inputdata
certPath=$curPath/cert
clrPath=$curPath/crl
seedPath=$curPath/seed
tempPath=$curPath/tmp
caConfig=$curPath/config/ca.conf
serialPath=$curPath/serial
serialFile=$serialPath/caSerial.srl
caConfigFile=$curPath/config/testCa.conf

# key/cert defaults
#rsaKeySize=1024/2048/4096
rsaKeySize=4096
validityDays=360
# for our testing we don't have strong security requirements
# we conveniently use the same password to protect keys and p12 containers
securityPwd=passw0rd

# local functions
function pause {
  read -p "Press [Enter] key to continue..."
}

function dir {
  ls -al
}

function readCsrParameterFile {
  printf "\nDo you want to import data from prepared data file? (Y/n) "
  read desicion
  if [ "$desicion" == "n" ] || [ "$desicion" != "N" ]
  then
    while true; do
      ls -1 $paramPath/*.sh | sed -r 's/^.+\///'
      printf "Please enter filename to use: "
      read paramfile
      if [ -e "$paramPath/$paramfile" ]
      then
        source $paramPath/$paramfile
        # resulting openssl subject string
        if [ -n "$pkiCommonName" ]; then
          pkiSubject="/C=$pkiCountry/ST=$pkiState/L=$pkiLocation/O=$pkiOrganization/OU=$pkiOrgUnit/CN=$pkiCommonName"
          printf "Subject from file: $pkiSubject\n"
        else
          printf "No PKI attribute definitions found. Wrong parameter file?"
          exit 1
        fi
        break
      fi
    done
  fi
}

printf "\nShall we create a new PKI or use the existing one? (K)eep/(n)ew: "
read reply
if [ "$reply" == "n" ] || [ "$reply" == "N" ]
then
    # === Housekeeping ===
    printf "\nAt first: housekeeping!\n"
    printf "I am going to delete all existing PKI files (keys, certs, CRLs, seeds). Continue? (y/N) "
    read reply
    if [ "$reply" == "" ] && [ "$reply" != "y" ]; then
       printf "OK, no approval. I stopp here!\nOtherwise I don't get a clean environment to start from.\n"
       exit 1
    fi

    rm -rf $certPath/*.pem $certPath/*.der $certPath/*.csr $certPath/*.srl
    rm -rf $clrPath/*
    rm -rf $serialPath/*
    rm -rf $tempPath/*

    # init serial numbers for CA certificate numbers (we must not start with 1 as this can be used to hack the PKI)
	printf "%u\n" "$(( ( RANDOM % 9999 )  + 1 ))" > $serialFile

    # === Root CA ===
    printf "++++++++++++++++++++++++++++++++++++++++++++\n"
    printf "First step: creating random seed parameters\n"
    printf "++++++++++++++++++++++++++++++++++++++++++++\n"
    openssl dsaparam $rsaKeySize \
     -out $seedPath/randSeedParams.pem

    printf "For testing purposes, always 'passw0rd' is useed as passphrase for keys and certs!\n"
    printf "\n"
    readCsrParameterFile
    printf "Creating the root CA key and cert...\n"
    # this command creates key + self-signed certificate at once (could be done in individual steps too)
    if [ -z "$pkiSubject" ]; then
      openssl req \
       -newkey rsa:$rsaKeySize \
       -rand $seedPath/randSeedParams.pem \
       -keyout $certPath/catest-RootCaKey.pem \
       -new \
       -sha256 \
       -x509 \
       -days $validityDays \
       -passout "pass:$securityPwd" \
       -out $certPath/catest-RootCaCert.pem
    else
      openssl req \
       -subj "$pkiSubject" \
       -newkey rsa:$rsaKeySize \
       -rand $seedPath/randSeedParams.pem \
       -keyout $certPath/catest-RootCaKey.pem \
       -new \
       -sha256 \
       -x509 \
       -days $validityDays \
       -passout "pass:$securityPwd" \
       -out $certPath/catest-RootCaCert.pem
    fi

    # creating CAfile for trust chain
    cat $certPath/catest-RootCaCert.pem > $certPath/catest-pkiTrustChain.pem

    printf "\nWould you like to see created root CA cert (Y/n)?"
    read reply
    if [ "$reply" != "n" ] && [ "$reply" != "N" ]
    then
      openssl x509 -text -noout -in $certPath/catest-RootCaCert.pem | more
    fi

    # === Intermediate CA ===
    printf "\nLet's create intermediate CA now."
    readCsrParameterFile
	echo "CERT will be valid for $validityDays days"
    if [ -z "$pkiSubject" ]; then
      openssl req \
       -newkey rsa:$rsaKeySize \
       -keyout $certPath/catest-interimCaKey.pem \
       -new \
       -sha256 \
       -passout "pass:$securityPwd" \
       -out $certPath/catest-interimCaCsr.pem
    else
      openssl req \
       -subj "$pkiSubject" \
       -newkey rsa:$rsaKeySize \
       -keyout $certPath/catest-interimCaKey.pem \
       -new \
       -sha256 \
       -passout "pass:$securityPwd" \
       -out $certPath/catest-interimCaCsr.pem
    fi

    printf "\nSigning new intermediate CA certificate with the root CA key now"
    # parameter -CAceateserial should/must(?) only be issued once per PKI
    openssl x509 \
     -req \
     -in $certPath/catest-interimCaCsr.pem \
     -sha256 \
     -CA $certPath/catest-RootCaCert.pem\
     -passin "pass:$securityPwd" \
     -CAkey $certPath/catest-RootCaKey.pem \
     -CAcreateserial \
     -CAserial $serialFile \
     -extfile $caConfigFile \
     -extensions sub_ca_cert \
	 -days $validityDays \
     -out $certPath/catest-interimCaCert.pem

    # adding to CAfile for trust chain
    cat $certPath/catest-interimCaCert.pem >> $certPath/catest-pkiTrustChain.pem

    printf "\nWould you like to see created imterim CA cert (Y/n)?"
    read reply
    if [ "$reply" != "n" ] && [ "$reply" != "N" ]
    then
      openssl x509 -text -noout -in $certPath/catest-interimCaCert.pem | more
    fi
else
    printf "OK, we keep the existing PKI.\n"
fi


# === USER Certificates ===
while true; do
  printf "\n\nDo you need another (server) certificate within the PKI? (Y/n): "
  read reply

  if [ "$reply" != "n" ] && [ "$reply" != "N" ]
  then
    printf "\nCreating new KEY and CSR now..."
    readCsrParameterFile
    if [ -z "$pkiSubject" ]; then
      username=$(uuidgen)
    else
      username=${pkiCommonName// /-}
    fi
    keyFile="key_$username.pem"
    csrFile="csr_$username.pem"
    crtFile="crt_$username.pem"
    cnfFile="cnf_$username.cnf"
    p12File="$username.p12"

    if [ -z "$pkiSubject" ]; then
      openssl req \
       -newkey rsa:$rsaKeySize \
       -keyout $certPath/$keyFile \
       -new \
       -sha256 \
       -passout "pass:$securityPwd" \
       -out $certPath/$csrFile
    else
      openssl req \
       -subj "$pkiSubject" \
       -newkey rsa:$rsaKeySize \
       -keyout $certPath/$keyFile \
       -new \
       -sha256 \
       -passout "pass:$securityPwd" \
       -out $certPath/$csrFile
    fi

    if [ -z "$pkiType" ]; then
      printf "\n\nShall this certificate be used for a server? (Y/n): "
      read localReply
      if [ "$localReply" != "n" ] && [ "$localReply" != "N" ]; then
        printf "\nServers need the certificate extensions \"Subject Alternative Name\".\n"
        printf "\nPlease enter the FQDN name for the subjectAltName attribute and press <ENTER>: "
        read pkiSubAltName
      fi
    fi

    # preparing signing parameter file
    if [ -n "$pkiSubAltName" ]; then
      cp $curPath/config/serverCert.conf $tempPath/$cnfFile
      # server authentication
      printf "\n# Following option is needed for server certificates verifiable by clients\n" >> $tempPath/$cnfFile
      printf "\nsubjectAltName=DNS.1:%s\n\n" "$pkiSubAltName" >> $tempPath/$cnfFile
      # printf "\ndefault_days=%s" "$validityDays" >> $tempPath/$cnfFile
    else
      cp $curPath/config/userCert.conf $tempPath/$cnfFile
      # client authentication
      printf "\n# Following option is needed for client authentication certificates verifiable by servers\n" >> $tempPath/$cnfFile
      printf "\nextendedKeyUsage=clientAuth\n" >> $tempPath/$cnfFile
      # printf "\ndefault_days=%s" "$validityDays" >> $tempPath/$cnfFile
    fi

    echo "DEBUG-START: temporary configuration file"
    cat $tempPath/$cnfFile
    echo "DEBUG-END: temporary configuration file"
	
    printf "\nSigning the CSR with the intermediate CA key\n"
    openssl x509 \
     -req \
     -in $certPath/$csrFile \
     -sha256 \
     -CA $certPath/catest-interimCaCert.pem \
     -passin "pass:$securityPwd" \
     -CAkey $certPath/catest-interimCaKey.pem \
     -CAserial $serialFile \
     -extfile $tempPath/$cnfFile \
     -extensions special_ext \
     -days $validityDays \
     -out $certPath/$crtFile
    if [ $? -ne 0 ]; then
      echo "SOMETHING WENT WRONG WITHIN OPENSSL!";
      exit 1
    fi

    # delete temporary parameter file
    rm -rf $tempPath/$cnfFile

    # adding to CAfile for trust chain
    cat $certPath/$crtFile >> $certPath/catest-pkiTrustChain.pem

    # create deployable P12 container file
    cat $certPath/catest-RootCaCert.pem > $certPath/ca-certs.pem
    cat $certPath/catest-interimCaCert.pem >> $certPath/ca-certs.pem
    openssl pkcs12 \
     -export \
     -out $certPath/$p12File \
     -inkey $certPath/$keyFile \
     -passin "pass:$securityPwd" \
     -in $certPath/$crtFile \
     -certfile $certPath/ca-certs.pem \
     -name ServerCert \
     -passout "pass:$securityPwd"
    # rm -rf $certPath/ca-certs.pem

    printf "\nWould you like to see created certificate (Y/n)?"
    read ynreply
    if [ "$ynreply" != "n" ] && [ "$ynreply" != "N" ]
    then
      openssl x509 -text -noout -in $certPath/$crtFile | more
    fi

  elif [ "$reply" == "n" ] || [ "$reply" == "N" ]; then
    break
  fi
done

# Verify existing certificates against PKI trust chain
printf "\n------------------------------------------------\n"
printf "Fine! Let's verify all non-PKI certificates now.\n"
pause
printf "\n"
for cert in $certPath/crt_*.pem; do
  openssl x509 -in $cert -noout -subject -nameopt RFC2253
  openssl verify -CAfile $certPath/catest-pkiTrustChain.pem -verbose $cert
  printf "\n"
done
