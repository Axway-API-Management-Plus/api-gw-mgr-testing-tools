## Automatic Setup of API-Manager Test Domain

### Purpose
During setup and development of an API-Manager middleware we had several times a need to create a complete new Axway API-Gateway Domain for the API-Manager with differing settings. This was to test for certain system configuration options or a clean load-test environment.

The attached script is a simple attempt to install a clean single-node test-system. After the setup procedure has run, you should have a new, clean but configured environment to test your API-Manager configurations.

In our sample we assume we need an API-Manager for hosting and exposing API's, comanied by another API-Gateway instance that can host simulations of backend-services (mock-API's) that are ment to provide means to test the API-Management platform for stabilitie and load capacity.

For a sample of an API-Management plattform test please see the subproject "Platform Verification API" (PVA).

### Usage
Intended environment is a Linux server. The script was tested with a CentOS v7.3.x server installation. We only rely on head-less installers. We try to minimize the needed manual intervention during the setup process. Instead, all parameters should be provided upfront via a parameters.

### Prerequisites
+ server has a suitable DNS name that shall be used for the API-Management infrastructure - a more speaking name than a simple host-name advisable
+ Axway Installer file has been copied onto the Linux server
+ a suitable Axway license file is available on the Linux box already
+ for some verification steps Python is needed on the system
+ create/provide new TLS server and clients certificates for your DNS names (if that's not provided you might look into the subproject "")

### Preparation

+ change setup parameters for API-Management system (environment / topology)
+ adopt parameters for API-Managemer configuration
  
 
