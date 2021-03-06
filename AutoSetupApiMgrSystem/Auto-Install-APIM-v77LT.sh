# ===============================================================================
# AXWAY API-Management
# All-on-one Demo System Component Installation on a virtual server (non docker)
# -> adopted to v7.7.LT as installer behaviours was slightly changed
# ===============================================================================
# Author:  R. Kiessling, Axway GmbH
# Changed: 10.08.2020

# CLI Parameters

# Version of the Axway API-Gateway Installer Package
# I will only install server components for Linux here. I assume the client tools run on a remote computer (Windows or Linux)
# main line versions right now are: 7.5.3 / 7.6.2 / 7.7.0 / 7.7.20200130
for i in "$@"
do
case $i in
    -i=*|--installer-version=*)
    apimVersion="${i#*=}"
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
if [[ -z "$apimVersion" ]]; then
  printf "ERROR: Needed parameter not provided\n"
  printf "$0\n"
  printf "  -i=<version string> | --installer-version=<version string>\n"
  printf "  -d | --debug\n"
  exit 1
fi

# ----------------------------------------------------------------------------
# Parameters for stand-alone environment (can be adopted for needed topology)
# ----------------------------------------------------------------------------

# Cassandra can use the API-Gateway provided JRE or an external one
# I go for the external JRE here.
externalJRE=/usr/lib/jvm/jre-1.8.0-openjdk

# Installer run file must be on the target system already, along with the license file
# installation will be within /opt/axwway/<version>
# for easy handling as symbolic link "current" should be created to the currently used product version
installSourceDir=/opt/axway/installer/${apimVersion}
licenseSourceDir=/opt/axway/licenses
installTargetDir=/opt/axway/axway-${apimVersion}

# ADMIN-NODE-MANAGER
anmHost=apimtest.spdns.de
anmPort=8090
anmDomain="${anmHost//"."/-}"
anmDomainPassphrase="tosave4me"
anmName="ANM-${anmDomain^^}"
anmAdminUser="admin"
anmAdminOotbPassword="changeme"
anmAdminPassword="tosave4me"

# API-GATEWAY for API-MANAGER
apigwMgrGroup="API-MGR-APIMTEST"
apigwMgrName="API-MGR-APIMTEST-1"
apigwMgrServicesPort=8080
apigwMgrManagementPort=8085

# API-MANAGER
apimDefaultOrg="Community"
apimAdminUserName="apiadmin"
apimAdminUserPass="tosave4me"
apimDefaultEmail="admin@apimtest.dns.de"
apimPortalPort=8075
apimTrafficPort=8065
apimSmtpServer=localhost
apimSmtpPort=25 \
apimSmtpUsername="admin@apimtest.dns.de"
apimSmtpPassword="smtppassword"
apimSmtpConnectionSecurity="none"
apimEmailFrom="no-reply@apimtest.dns.de"

# API-GATEWAY for Mock-Services
apigwGwGroup="API-GW-APIMTEST"
apigwGwName="API-MGR-APIMTEST-2"
apigwGwServicesPort=8081
apigwGwManagementPort=8086


# -----------------------
# Preparing installation
# -----------------------

# prepare directory structure
if [ ! -d ${installTargetDir} ]; then
  mkdir ${installTargetDir}
fi

# find Axway installer executable
if [ -d ${installSourceDir} ]; then
  printf "DEBUG: "
  pwd
  find . -name APIGateway_${apimVersion}*_Install_linux*.run
  axwayInstaller=$( find . -name APIGateway_${apimVersion}*_Install_linux*.run )
  printf "INFO: Axway Installer=${axwayInstaller}\n"

  if [ "X${axwayInstaller}" = "X" ] || [ ! -f "${axwayInstaller}" ]; then
    printf "ERROR: No Axway API-Gateway installer for version ${apimVersion} found at ${installSourceDir}"
    exit 1
  else
    chmod u+x ${axwayInstaller}
  fi
fi

# check for Axway product license file
if [ -d ${licenseSourceDir} ]; then
  licenseFile=$( find ${licenseSourceDir} -name "API*${apimVersion:0:3}*.lic" -print0 | xargs -0 grep -l "nondocker" )
  printf "DEBUG: looking for Axway API-Management Platform license ${licenseFile}\n"
  if [ ! -f "$licenseFile" ]; then
    printf "ERROR: Axway API-Management Platform license file for ${apimVersion} found at ${licenseSourceDir} (expecting $licenseFile)\n"
    exit 1
  fi
else
  printf "ERROR: no Axway licenses available (no directory to copy from)"
  exit 1
fi

# Stop all running API-Management processes
if pgrep -x "vshell|cassandra|java" >/dev/null; then
  printf '%s\n' "ERROR: Please stop all vshell and cassandra processes before restarting the topology init script!\n"
  exit 1
fi

# cleanup an older installation of same version
printf "INFO: Installation directory is ${installTargetDir}\n"
rm -rf ${installTargetDir}/*

# Install Cassandra 2.2.x binaries from Axway installer; use external OpenJDK v8
# (installed within API-Gateway version directory to have a complete integrated test environment)
printf "STEP 1: Installing Apache Cassandra server executables\n"
if [ ! -d ${externalJRE} ]; then
  printf "ERROR: no external JAVA runtime found for Cassandra.\n"
  exit 1
fi

# since 7.7.0 the apitester is not included anymore!
${axwayInstaller} \
--mode unattended \
--setup_type advanced \
--prefix ${installTargetDir} \
--cassandraInstalldir ${installTargetDir} \
--enable-components cassandra \
--cassandraJDK ${externalJRE} \
--disable-components apigateway,nodemanager,apimgmt,qstart,analytics,policystudio,configurationstudio,packagedeploytools

# Install Axway API-Managment components binaries
# - Admin Node Manager
printf "STEP 2: Installing Admin-Node-Manager executables\n"
${axwayInstaller} \
--mode unattended \
--setup_type advanced \
--prefix ${installTargetDir} \
--enable-components nodemanager \
--disable-components cassandra,apigateway,apimgmt,qstart,analytics,policystudio,configurationstudio,packagedeploytools \
--licenseFilePath "${licenseFile}"

# Install Axway API-Managment components binaries
# - API-Gateway
# - API-Manager (on API-Gateway)
# (analytics binaries are no longer evailable!)

# since 7.7.0 the apitester is not included anymore!
# cassandra,nodemanager,apimgmt,qstart,analytics,policystudio,apitester,configurationstudio,analytics
printf "STEP 3: Installing API-Gateway/Manager and tools executables\n"
${axwayInstaller} \
--mode unattended \
--setup_type advanced \
--prefix ${installTargetDir} \
--enable-components apigateway,packagedeploytools \
--disable-components cassandra,nodemanager,apimgmt,qstart,analytics,policystudio,configurationstudio,analytics \
--licenseFilePath "${licenseFile}"

# ======================================
# Configuration of Axway API-Management
# ======================================

# Verify binary installation
printf "INFO: Installed version info from managedomain command\n"
${installTargetDir}/apigateway/posix/bin/managedomain -v
# should produce something like that:
# Version:    7.6.2
# Build Date: 2018-07-26 11:25:54 UTC
# Commit Id:  714bf171d7fa7f958048d566d13ba86f058c0c91
# Patch:      None

# --------------------------------------
# ADMIN NODE MANGER (single node system)
# --------------------------------------
printf "STEP 4: Initialization of Domain and first Admin-Node-Manager\n"

cd ${installTargetDir}/apigateway/posix/bin
# create new Domain and initialize Node-Manager as ANM
./managedomain \
--initialize \
--nm_name=${anmName} \
--host=${anmHost} \
--port=${anmPort} \
--sign_with_generated \
--domain_name=${anmDomain} \
--domain_passphrase=${anmDomainPassphrase} \
--subj_alt_name="DNS.1=${anmHost}" \
--sign_alg=sha256

printf "STEP 5a: Starting new Admin-Node-Manager\n"
# start ANM (detached as service)
./nodemanager -d

# check admin account and change default password
printf "STEP 5b: Changing standard admin account password\n"
printf "* check if we can connect\n"

httpStatusCode=$( curl \
-k -s -o /dev/null -w "%{http_code}" \
--user "${anmAdminUser}:${anmAdminOotbPassword}" \
--url https://${anmHost}:${anmPort}/api/adminusers/users \
--request GET )

if [ "$httpStatusCode" -ne "200" ]; then
  printf '%s\n' "ERROR: Can not connect to Admin-Node-Manager."
  exit 1
fi

curl -k -s \
--user "${anmAdminUser}:${anmAdminOotbPassword}" \
--url https://${anmHost}:${anmPort}/api/adminusers/users | python2 -m json.tool

printf "* changing admin user password now\n"
# here is the request according to API Gateway REST API v1.0 documentation
# (working request spoofed from API-Gateway Manager UI)
httpStatusCode=$( curl \
-k -s -o /dev/null -w "%{http_code}" \
--user "${anmAdminUser}:${anmAdminOotbPassword}" \
--url https://${anmHost}:${anmPort}/api/adminusers/users/password \
--header "Content-Type: application/x-www-form-urlencoded" \
--request POST \
--data "oldPassword=${anmAdminOotbPassword}&newPassword=${anmAdminPassword}" )

if [ "$httpStatusCode" -ne "204" ]; then
  printf '%s\n' "ERROR: Changing password for user ${anmAdminUser} failed."
  exit 1
fi

# change advisory banner to point out we are in a DEV/TEST system!
printf "STEP 5c: Changing advisory banner to advice on TEST system status\n"
bannerText="{\"bannerEnabled\": true, \"bannerText\": \"API-Management v${apimVersion} TEST system - do NOT use any secret or sensible information here.\"}"
httpStatusCode=$( printf "${bannerText}" | curl \
-k -s -o /dev/null -w "%{http_code}" \
--user "${anmAdminUser}:${anmAdminPassword}" \
--request PUT \
--header "Content-Type: application/json" \
--data @- \
--url https://${anmHost}:${anmPort}/api/adminusers/advisorybanner )

if [ "$httpStatusCode" -ne "200" ]; then
  printf '%s\n' "WARNING: API-Gateway Manager UI advisory banner could not be changed. (HTTP status: ${httpStatusCode})"
fi
# DEBUG
printf '%s\n' "${bannerText}"
printf "${bannerText}" | curl \
-k -s -o /dev/null -w "%{http_code}" \
--user "${anmAdminUser}:${anmAdminPassword}" \
--request PUT \
--header "Content-Type: application/json" \
--data @- \
--url https://${anmHost}:${anmPort}/api/adminusers/advisorybanner

# Opening desired firewall ports (CentOS v7)
printf "STEP 5d: opening firewall ports\n"
printf '%s\n' "----------------------------------------------------------------------------"
printf '%s\n' "  please issue as admin:  sudo firewall-cmd --permanent --add-port=${anmPort}/tcp"
printf '%s\n' "  followed by:            sudo firewall-cmd --reload\n"
printf '%s\n' "----------------------------------------------------------------------------"


# --------------------------------------
# API-Gateway for API-Manager
# --------------------------------------
printf "STEP 6: Registration of API-Gateway group and first instance to host an API-Manager\n"

# register API-Gateway for API-Manager
./managedomain \
--anm_host=${anmHost} \
--anm_port=${anmPort} \
--username=${anmAdminUser} \
--password=${anmAdminPassword} \
--domain_passphrase=${anmDomainPassphrase} \
--create_instance \
--group=${apigwMgrGroup} \
--name=${apigwMgrName} \
--instance_services_port=${apigwMgrServicesPort} \
--instance_management_port=${apigwMgrManagementPort}

if [ $? -ne 0 ]; then
  printf '%s\n' "ERROR: Failed to register new API-Gateway instance ${apigwMgrName} within group ${apigwMgrGroup}."
  exit 1
fi
printf "    b): starting instance ${apigwMgrName}\n"
./startinstance -n "${apigwMgrName}" -g "${apigwMgrGroup}" -d

# --------------------------------------
# API-Gateway for API-Gateway Mockups
# --------------------------------------
printf "STEP 7: Registration of API-Gateway group and first instance to host Mockup Services\n"
printf "    a): registering instance ${apigwGwName}\n"

# register API-Gateway for Mock-Services
# (API-GW is never diectly accessible from outside; calls must go to an API on API-Manager first to be directed to API-GW Mockup service)
./managedomain \
--anm_host=${anmHost} \
--anm_port=${anmPort} \
--username=${anmAdminUser} \
--password=${anmAdminPassword} \
--domain_passphrase=${anmDomainPassphrase} \
--create_instance \
--group=${apigwGwGroup} \
--name=${apigwGwName} \
--instance_services_port=${apigwGwServicesPort} \
--instance_management_port=${apigwGwManagementPort}

if [ $? -ne 0 ]; then
  printf '%s\n' "ERROR: Failed to register new API-Gateway instance ${apigwGwName} within group ${apigwGwGroup}."
  exit 1
fi
printf "    b): starting instance ${apigwGwName}\n"
./startinstance -n "${apigwGwName}" -g "${apigwGwGroup}" -d


# --------------------------------------
# Verifiy Topology
# --------------------------------------
printf "STEP 8: Verify topolgy\n"

./managedomain \
--anm_host=${anmHost} \
--anm_port=${anmPort} \
--username=${anmAdminUser} \
--password=${anmAdminPassword} \
-p

# --------------------------------------
# Setup API-Manager
# --------------------------------------
# Opening desired firewall ports (CentOS v7)
printf "STEP 9: opening additional desired firewall ports\n"
printf '%s\n' "----------------------------------------------------------------------------"
printf '%s\n' "  please issue as admin:  sudo firewall-cmd --permanent --add-port=8065/tcp"
printf '%s\n' "  please issue as admin:  sudo firewall-cmd --permanent --add-port=8075/tcp"
printf '%s\n' "  followed by:            sudo firewall-cmd --reload"
printf '%s\n' "----------------------------------------------------------------------------"

printf "\n"
printf "Now API-Manager must be installed!\n"
printf "Pre-requisite: Cassandra Configuration via Policy Studio!\n"
printf "\n"

# =====================================================================================
# Setup of API-Manager on local Group API-APIMTEST
# =====================================================================================
printf "STEP 10: adding Apache Cassandra Cluster seed nodes to API-Manager Gateway envSettings.props\n"
cd ${installTargetDir}/apigateway/posix/bin
cat >> ../../groups/topologylinks/${apigwMgrGroup}-${apigwMgrName}/conf/envSettings.props << EOF

# Apache Cassandra Cluster - Seed Nodes
env.CASSANDRA.SERVER.PORT=9042
env.CASSANDRA.SERVER1=localhost
env.CASSANDRA.SERVER2=localhost
env.CASSANDRA.SERVER3=localhost

EOF

printf "STEP 11: start local Apache Cassandra Node now\n"
cd ${installTargetDir}/cassandra/bin
./cassandra -p ${installTargetDir}/cassandra.pid >> /dev/null
# now check if process with pid exists (to be sure our cassandra node is running)
# We need to check if the "local" cassandra server was started. Otherwise another (unwanted) instance might be running.
sleep 2
if [ ! -f ${installTargetDir}/cassandra.pid ]; then
  printf '%s\n' "ERROR: No cassandra PID file found. Seems the node was not started!"
  exit 1
fi

ps -p $(cat ${installTargetDir}/cassandra.pid) 2>&1 >> /dev/null
if [ $? -ne 0 ]; then
  printf '%s\n' "ERROR: Desired Apache Cassandra Node is not running! Perhaps another Cassandra node is running instead?"
  rm -f ${installTargetDir}/cassandra.pid
  exit 1
fi

cd ${installTargetDir}/apigateway/posix/bin
# ------------------------------------------------------------------
# Cancel Installation here - next steps are manual for now!
# ------------------------------------------------------------------
printf "Cancel Installation here - next steps are manual for now!\n"
printf '%s\n' "----------------------------------------------------------------------------"
printf '%s\n' "  Next Steps are:\n"
printf '%s\n' "  - add Apache Cassandra configuration using Policy Studio"
printf '%s\n' "  - run setup_apimanager script"
printf '%s\n' "----------------------------------------------------------------------------"

printf "STEP 13: adding Apache Cassandra Cluster configuration to API-Gateway config (FED)\n"
printf "         This is not yet implemented! Please manually add it for now!\n"

# EXIT AUTO INSTALLION HERE
exit 0

printf "STEP 12: Setup API-Manager on API gateway group ${apigwMgrGroup}\n"
./setup-apimanager \
--username=${anmAdminUser} \
--password=${anmAdminPassword} \
--communityName=${apimDefaultOrg} \
--adminName=${apimAdminUserName} \
--adminPass=${apimAdminUserPass} \
--adminEmail=${apimDefaultEmail} \
--group=${apigwMgrGroup} \
--name=${apigwMgrName} \
--portalport=${apimPortalPort} \
--trafficport=${apimTrafficPort} \
--smtpServer=${apimSmtpServer} \
--smtpPort=${apimSmtpPort} \
--smtpUsername=${apimSmtpUsername} \
--smtpPassword=${apimSmtpPassword} \
--smtpConnectionSecurity=${apimSmtpConnectionSecurity} \
--emailFrom=${apimEmailFrom}


printf "DEBUG: STOPPING HERE!"
exit 0
# --------------------------------------------------------------------------------------
# Enable Metrics DB on local MariaDB Server
# --------------------------------------------------------------------------------------
# Doc Links:
# - https://docs.axway.com/bundle/APIGateway_762_InstallationGuide_allOS_en_HTML5/page/Content/CommonTopics/metrics_db_install.htm
# - https://www.digitalocean.com/community/tutorials/how-to-create-a-new-user-and-grant-permissions-in-mysql

# STEP 1) Copy binary JDBC driver files into Node-Manager or API-Gateway installation directory
printf "STEP 13: Copy binary JDBC driver files into Node-Manager or API-Gateway installation directory\n"
cp /opt/axway/installer/mysql-addon/mysql-connector-java-*-bin.jar /opt/axway/axway-7.6.2/apigateway/ext/lib
#cp ${installSourceDir}/../mysql-addon/mysql-connector-java-*-bin.jar "${installTargetDir}/apigateway/ext/lib"

# STEP 2) Prepare Maria DB Server for API Metrics data collection
mysql -u root -p

mysql> status
mysql> show databases;
mysql> drop database reports;
mysql> CREATE DATABASE reports;
mysql> CREATE USER 'apimetrics'@'localhost' IDENTIFIED BY 'apimetrics';
mysql> GRANT ALL PRIVILEGES ON reports . * TO 'apimetrics'@'localhost';
mysql> FLUSH PRIVILEGES;
mysql> select user, password, host from mysql.user;

# STEP 3) Configure database for API metrics data
printf "STEP 14: Create database for API metrics data\n"
cd /opt/axway/current/apigateway/posix/bin

./dbsetup \
--dburl="jdbc:mysql://127.0.0.1:3306/reports" \
--dbuser="apimetrics" \
--dbpass="apimetrics" \
--reinstall

# STEP 4) Init Node-Manager for report data publication
printf "STEP 15: Init Node-Manager for report data publication\n"
cd ${installTargetDir}/apigateway/posix/bin
./managedomain \
--anm_host=${anmHost} \
--anm_port=${anmPort} \
--username=${anmAdminUser} \
--password=${anmAdminPassword} \
--edit_host \
--host=${anmHost} \
--metrics_enabled=true \
--metrics_dburl="jdbc:mysql://127.0.0.1:3306/reports" \
--metrics_dbuser="apimetrics" \
--metrics_dbpass="apimetrics"

# restart Admin-Node-Manager after changes to enable metrics settings
printf "STEP 16: restart Admin-Node-Manager after changes to enable metrics settings\n"
./nodemanager -k
./nodemanager -d

# test for successful database creation
# mysql -u apimetrics -p --database reports
#mysql> show databases;
#mysql> use reports;
#select count(*) from audit_log_points;
#select count(*) from audit_log_sign;
#select count(*) from audit_message_payload;
#select count(*) from metric_group_types;
#select count(*) from metric_group_types_map;
#select count(*) from metric_groups;
#select count(*) from metric_types;
#select count(*) from metrics_alerts;
#select count(*) from metrics_data;
#select count(*) from process_groups;
#select count(*) from processes;
#select count(*) from time_window_types;
#select count(*) from transaction_data;
#select count(*) from versions;
#' ------------------------------
#' Show API-MANAGER records only
#' ------------------------------
#select 
#  md.MetricTimestamp,
#  mg.Name,
#  mg.DisplayName,
#  mt.Name,
#  mt.AggregationFunction,
#  twt.Name,
#  md.Value
# from
#  metrics_data md,
#  metric_types mt,
#  metric_groups mg,
#  time_window_types twt
# where
#  md.MetricTypeID = mt.ID and
#  md.MetricGroupID = mg.ID and
#  mg.DisplayName IS NOT NULL and
#  md.TimeWindowTypeID = twt.ID
# order by
#  md.MetricTimestamp,
#  mt.Name,
#  twt.Name;
#mysql> exit

printf "STEP 17: Enable Monitoring within API-Manager GUI via Policy Studio (Server Settings -> API-Manager -> Monitoring)\n"

printf "ALL STEPS COMPLETE\n\n"
