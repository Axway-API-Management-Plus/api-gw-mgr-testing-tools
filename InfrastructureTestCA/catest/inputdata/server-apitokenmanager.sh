# PKI definitions (in order to not beeing asked each time)
# The "openssl req" magic of CSR generation without being prompted for values which go in the certificate's subject field,
# is in the -subj option. (details here: http://www.shellhacks.com/en/HowTo-Create-CSR-using-OpenSSL-Without-Prompt-Non-Interactive)
# Type: ROOTCA, INTERIMCA, SERVER, CLIENT

pkiType="SERVER"
pkiCountry="DE"
pkiState="Hessen"
pkiLocation="Frankfurt"
pkiOrganization="Axway Cloud Test PREPROD"
pkiOrgUnit="API-Management-Testing PREPROD"
pkiCommonName="API Green Token Provider PREPROD"
pkiSubAltName="apimgr-testing.dns.de"
