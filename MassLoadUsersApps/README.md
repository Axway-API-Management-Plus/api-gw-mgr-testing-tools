## Mass User- and Application-Load script

### Usage
Manually create an Organization: LoadTestOrg  
Call the script like this:  
`./create-test-users.sh -f=accounts_test.csv -u=apiadmin -p=changeme -t=localhost:8075`

By default 500 Users and Applications are created. The progress is logged like this:  
`CREATING ACCOUNT: User Tester-495 within Organization LoadTestOrg`
