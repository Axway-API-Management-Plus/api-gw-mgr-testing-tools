<!-- Markdown Reference: https://markdown.de/ -->

# Certificate Authority for Infrastructre Testing

## Purpose
In my project work I have often come across the situation we have not been able to get suitable X.509 certificates for a local test-environment. But in order to verify a setup for the configuration of a later stage for integration testing and production we depend on those client and server TLS certificates (and keys) or have a need for encryption or signing (e.g. OAuth2 tokens).

The tool provided here is a way to generate suitable certificates that can be used to test for X.509v3 certificate and key configurations like key length (2048/4096 bit), key type (default here: RSA), certificate parameters and the like.

## Usage
Intended environment is a Linux server. The script was tested on Cygwin and CentOS v7 server.
All parameters shall be provided upfront via simple configuration files. The tooling allows for extension of the CA (issuing new keys/certs) but has limitations in managing already provided certificates (Certs can not be revoked; no CRL; no OCSP).

Some configurarions require a decent knowledge of OpenSSL. For details please see: https://www.openssl.org/docs/manpages.html

Most times an Certificat-Authority consists of a highly protected root CA as the initail trust-anchor for the PKI (public key environment)

### Prerequisites
+ Linux OS or Cygwin
+ current version of OpenSSL installed on OS (or use tools provided with Axway API-Gateway installation)

### Preparation
Idea of the tools is a three level CA structure:
1) First level is the Root-CA certificate. A self-signed, not publicly trusted Root Certificate.
2) Second level is an Interim-CA. That is pretty comparable to what enterprises normaly use for their infrastructures. Often a number of Interim-CA's (or sub-CA's) exist to provide certificates for different purposes or environments.
3) Third level are the individual client- or server-certificates for your test systems.

In order of this three layer hirarchie you have to provide at least one parameter file per hirarchie level (within sub-directory `./inputdata`):
+ Root CA
+ Interim CA (only one possible currently)
+ Client or Server parameter files

*General remarks on parameter file content:*

Provide PKI parameters in order to avoid beeing asked each time `openssl req` magic of CSR generation. Otherwise OpenSSL will prompt for values which go into the certificate subject field. (details here: http://www.shellhacks.com/en/HowTo-Create-CSR-using-OpenSSL-Without-Prompt-Non-Interactive)
Possible PKI-Types: ROOTCA, INTERIMCA, SERVER, CLIENT

*Sample of a Root-CA file:*
<pre><code>
pkiType="ROOTCA"
pkiCountry="DE"
pkiState="Hessen"
pkiLocation="Frankfurt"
pkiOrganization="Axway Cloud Test PREPROD"
pkiOrgUnit="API-Management-Testing PREPROD"
pkiCommonName="Playground ROOT CA PREPROD"
pkiSubAltName=""
</pre></code>

*Sample of a Interim-CA file:*
<pre><code>
pkiType="INTERIMCA"
pkiCountry="DE"
pkiState="Hessen"
pkiLocation="Frankfurt"
pkiOrganization="Axway Cloud Test PREPROD"
pkiOrgUnit="API-Management-Testing PREPROD"
pkiCommonName="Playground Interim CA PREPROD"
pkiSubAltName=""
</pre></code>

*Sample of a Server-Cert file:*
<pre><code>
pkiType="SERVER"
pkiCountry="DE"
pkiState="Hessen"
pkiLocation="Frankfurt"
pkiOrganization="DEV Cloud Test PREPROD"
pkiOrgUnit="API-Management-Testing PREPROD"
pkiCommonName="API Manager UI PREPROD"
pkiSubAltName="apimgr-testing.dns.de"
</pre></code>
  
### Running the tool
To run the tool just start the bash script: `./createDemoCa.sh`

The script is interactively asking for the intended actions. All default options are show in uppercase in option to help allow for quickly step to through the options.

In case you want to create a complete new CA you can chose "new" during startup. This will delete all of the CA before and create a whole new CA!

Design idea for  this quick tool was to read prepared details for individual files for each key/certificat pair.

Sample Session:

<pre><code>
Shall we create a new PKI or use the existing one? (K)eep/(n)ew: K
OK, we keep the existing PKI.
Do you need another (server) certificate within the PKI? (Y/n):
Creating new KEY and CSR now...
Do you want to import data from prepared data file? (Y/n)
client-testsystem.sh
intermediateca.sh
rootca.sh
server-adminnodemanager.sh
server-apimanager.sh
server-apiportal.sh
server-apitokenmanager.sh
server-cassandranode.sh
Please enter filename to use: server-apimanager.sh
...
</pre></code>

## Known Limitations
This CA is not suitable to tests that are intended to verify valid access because of clients trust a server using as server-certifiate issued by this CA. Clients like Web-browsers will only trust servers (e.g. API-Manager or one of the management interfaces) if the Root-CA and Interim-CA certificates are (manually) added to the trust-store of the given test-client.

If you need your clients to have TLS trust initially you need consider proviers like the let's encrypt project (https://letsencrypt.org/de/getting-started/) or an public CA who's certifiate chaines are already provided along with the given tool. That ensures you are dealing with certs from a trustworty source on the Internet.

API connectors or API-Management services on the Internet sometimes are not confiurable to trust an inofficail CA like the one created by this tool. You need to contact the provider/vendor of the platform to get insight how to configure TLS trust for their cloud service to be able to connect to your test-system using an inofficial CA. 
