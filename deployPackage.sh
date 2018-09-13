#!/bin/bash
# deployPackage.sh 
# parameters:
# $1 = 1 = scratchorg, 2 = sandbox, 3 = partner org setup, 4 = production
# $2 = Orgname or scratchorg name
# $3 = scratchorg = validity days, sandbox = output directory, partner = org username 
# $4 = sandbox = package, partner = package: options: main,base,ctp,ip,drs,legalportal,
# $5 = Community domain URL

######################### Examples ################################
# Scratch Org: ./scripts/deployPackageTest.sh 1 scratchorgname 30
# Sandbox: ./scripts/deployPackageTest.sh 2 orgname mdapioutput/sirasandbox/ base https://sira.force.com
# partner Org setup: ./scripts/deployPackageTest.sh 3 siradrstest mdapioutput/sirasandbox/ base https://sira.force.com bernard.wong@sira.nsw.gov.au.siradrstest
# Production: ./scripts/deployPackageTest.sh 2 orgname mdapioutput/siraprod/ base
######################### Examples ################################


#setParameters: Assign parameters to variables
function setParameters() {
    if [ "$1" != "" ]; then
        deployoption=$1
    else 
        echo "Please provide the deployment type: 1 = scratchorg,2 = sandbox, 3 = partner, 4 = Production, 5 = new partner org setup"
        exit $?
    fi
 
    if [ "$2" != "" ]; then
        orgname=$2
    else 
        echo "Scratch Org Name not provided"
        exit $?
    fi

    if [ "$deployoption" == "1" ] && [ "$3" != "" ] ; then
        if [ "$3" -le "30" ]  && [ "$3" -gt "0" ] ; then
            days=$3
        else 
            days=30
        fi
    elif ([ "$deployoption" == "2" ] || [ "$deployoption" == "3" ] || [ "$deployoption" == "4" ] || [ "$deployoption" == "5" ]) && [ "$3" != "" ] ; then
        outputdirectory=$3
    fi

    if [ "$4" != "" ]; then
        packagename="-r force-app/$4"
    fi

    if [ "$5" != "" ]; then
        siteurl="$5"
    else
        siteurl="https://sira.force.com"
    fi
    
    if [ "$6" != "" ]; then
        username="$6"
    elif ([ "$deployoption" == "3" ] || [ "$deployoption" == "5" ]) && [ "$6" == "" ] ; then
        echo "Username not provided"
        exit $?
    fi
}

#createScratch
function createScratch() {
    echo 'STARTED CREATING SCRATCHORG'
    echo "Scratch Org Name: $orgname" 
    sfdx force:org:create -s -f config/project-scratch-def.json -a $orgname -d $days
    sfdx force:org:open -u $orgname
    sfdx force:data:record:update -s User -w "Name='User User'" -v "UserPermissionsKnowledgeUser=true UserPermissionsInteractionUser=true UserPermissionsLiveAgentUser=true UserPermissionsSiteforceContributorUser=true"
    sfdx force:data:tree:import -f data/OrgWideEmailAddress.json -u $orgname
    sfdx force:mdapi:deploy -d data/sharingdeployment -u $orgname -w -1
    echo 'ENDED CREATING SCRATCHORG'    
}

#New Org setup
function newOrgSetup {
    sfdx force:org:open -u $orgname
    sfdx force:data:record:update -s User -w "Username='%username%'" -v "UserPermissionsKnowledgeUser=true UserPermissionsInteractionUser=true UserPermissionsLiveAgentUser=true UserPermissionsSiteforceContributorUser=true" -u $orgname
    sfdx force:data:tree:import -f data/OrgWideEmailAddress.json -u $orgname
    @echo. && echo Enable external sharing
    # sfdx force:mdapi:deploy -d data/sharingStandardObjects -u $orgname -w -1
    sfdx force:mdapi:deploy -d data/sharingdeployment -u $orgname -w -1

}

#Sandbox deployment
function deploySandbox {
    if [ -d "$outputdirectory" ]; then
        # Control will enter here if $DIRECTORY exists.
        rm -r $outputdirectory
    fi
    echo "STARTED BUILDING SANDBOX PACKAGE"
    sfdx force:source:convert -d $outputdirectory $packagename 
    #grep -rl 'SWITCH_SCRATCH' ./outputdirectory
    grep -rl -P '<!--SWITCH_SCRATCH-->(<!--)?' ./$outputdirectory | xargs -d '\n' sed -i -r -e 's/<!--SWITCH_SCRATCH-->(<!--)?/<!--SWITCH_SCRATCH--><!--/g;s/(-->)?<!--SWITCH_SANDBOX-->(<!--)?/--><!--SWITCH_SANDBOX-->/g;s/(-->)?<!--END-->/<!--END-->/g' ;
    # grep -rl -P '(-->)?<!--SWITCH_SANDBOX-->(<!--)?' ./$outputdirectory | xargs sed -i -r -e 's/(-->)?<!--SWITCH_SANDBOX-->(<!--)?/--><!--SWITCH_SANDBOX-->/g' ;
    # grep -rl -P '(-->)?<!--END-->' ./$outputdirectory | xargs sed -i -r -e 's/(-->)?<!--END-->/<!--END-->/g' ;
    # find ./$outputdirectory -type f -exec sed -r -i -e 's/<!--SWITCH_SCRATCH-->(<!--)?/<!--SWITCH_SCRATCH--><!--/g;s/(-->)?<!--SWITCH_SANDBOX-->(<!--)?/--><!--SWITCH_SANDBOX-->/g;s/(-->)?<!--END-->/<!--END-->/g' {} \;
    # find ./$outputdirectory -type f -exec sed -r -i -e 's/<!--SWITCH_SCRATCH-->(<!--)?/<!--SWITCH_SCRATCH--><!--/g' {} \;
    # find ./$outputdirectory -type f -exec sed -r -i -e 's/(-->)?<!--SWITCH_SANDBOX-->(<!--)?/--><!--SWITCH_SANDBOX-->/g' {} \;
    # find ./$outputdirectory -type f -exec sed -r -i -e 's/(-->)?<!--END-->/<!--END-->/g' {} \;
    grep -rl -P 'https://sira.force.com' ./$outputdirectory | xargs -d '\n' sed -i -r -e 's#https://sira.force.com#$siteurl#g' ;
    
    echo "DEPLOYING SANDBOX PACKAGE"
    sfdx force:mdapi:deploy -d $outputdirectory -u $orgname -w -1
}

#Partner Sandbox deployment
function deployPartnerSandbox {
    if [ -d "$outputdirectory" ]; then
        # Control will enter here if $DIRECTORY exists.
        rm -r $outputdirectory
    fi
    echo "STARTED BUILDING PARTNER PACKAGE"
    sfdx force:source:convert -d $outputdirectory $packagename 
    grep -rl -P '<!--SWITCH_SCRATCH-->(<!--)?' ./$outputdirectory | xargs -d '\n' sed -i -r -e 's/<!--SWITCH_SCRATCH-->(<!--)?/<!--SWITCH_SCRATCH--><!--/g;s/(-->)?<!--SWITCH_SANDBOX-->(<!--)?/--><!--SWITCH_SANDBOX-->/g;s/(-->)?<!--END-->/<!--END-->/g' ;
    grep -rl -P 'https://sira.force.com' ./$outputdirectory | xargs -d '\n' sed -i -r -e 's#https://sira.force.com#$siteurl#g' ;
    grep -rl -P '<defaultCaseUser>[A-Za-z@.]*</defaultCaseUser>' ./$outputdirectory | xargs -d '\n' sed -i -r -e "s#<defaultCaseUser>[A-Za-z@.]*</defaultCaseUser>#<defaultCaseUser>$username</defaultCaseUser>#g";
    
    ##########################################################################
    # Build Specific to partner orgs
    # 1. delete standard non-required metadatas that prevents deployment
    # 2. Platform cache not available, so need to set to 0
    # 3. Change sort order of Standard Lead duplicate rule
    find ./$outputdirectory -name standard__Insights.app | xargs rm     
    grep -rl -P '<allocatedCapacity>5</allocatedCapacity>' ./$outputdirectory | xargs -d '\n' sed -i -r -e "s#<allocatedCapacity>5</allocatedCapacity>#<allocatedCapacity>0</allocatedCapacity>#g";
    find ./mdapioutput/sirasandbox/ -name Lead.Standard_Lead_Duplicate_Rule.duplicateRule | xargs -d '\n' sed -i -r -e "s#<sortOrder>1</sortOrder>#<sortOrder>2</sortOrder>g"
    ##########################################################################

    echo "DEPLOYING PARTNER PACKAGE"
    # sfdx force:mdapi:deploy -d $outputdirectory -u $orgname -w -1

}

#Production deployment
function deployProduction {
    if [ -d "$outputdirectory" ]; then
        # Control will enter here if $DIRECTORY exists.
        rm -r $outputdirectory
    fi
    echo "STARTED BUILDING PRODUCTION PACKAGE"
    sfdx force:source:convert -d $outputdirectory $packagename 
    grep -rl -P '<!--SWITCH_SCRATCH-->(<!--)?' ./$outputdirectory | xargs -d '\n' sed -i -r -e 's/<!--SWITCH_SCRATCH-->(<!--)?/<!--SWITCH_SCRATCH--><!--/g;s/(-->)?<!--SWITCH_SANDBOX-->(<!--)?/--><!--SWITCH_SANDBOX-->/g;s/(-->)?<!--END-->/<!--END-->/g' ;
    grep -rl -P '<!--SWITCH_TEST-->(<!--)?' ./$outputdirectory | xargs -d '\n' sed -i -r -e 's/<!--SWITCH_TEST-->(<!--)?/<!--SWITCH_TEST--><!--/g;s/(-->)?<!--SWITCH_PRODUCTION-->(<!--)?/--><!--SWITCH_PRODUCTION-->/g;s/(-->)?<!--PRODEND-->/<!--PRODEND-->/g' ;
    
    echo "DEPLOYING PRODUCTION PACKAGE"
    sfdx force:mdapi:deploy -d $outputdirectory -u $orgname -w -1 -c 
}

#installManagedPackages
function installManagedPackages(){
    echo 'STARTED INSTALLING APPS'
    echo "Scratch Org Alias Name: $orgname" 
    sfdx force:package:install -r -u $orgname --package 04t80000000cijSAAQ
    sfdx force:package:install -r -u $orgname --package 04t50000000EcdrAAC
    sfdx force:package:install -r -u $orgname --package 04t3A000000WuusQAC
    sfdx force:package:install -r -u $orgname --package 04t30000000bqOuAAI
    echo 'Install sf_chttr_apps'
    sfdx force:package:install -r -u $orgname --package 04t0Y000002NUHGQA4
    echo 'ENDED INSTALLING APPS'
}

#prompt whether Pre-Deployment Steps Completed
function promptPreDeploymentCompleted {
    echo "Please check if sharing rules have finished calculating"
    while [ 1 ]; do 
        echo "Have you completed the pre-steps? (y)es, (n)o or (c)ancel:" 
        read answer 
        if [ $answer == "c" ]; then 
            echo 'Aborting: preDeployment script not run' &&
            exit 1
        fi
        if [ $answer == "y" ]; then 
            #preDeployment
            break
        fi
    done 
}

function preDeployment {
    echo "STARTED PRE-DEPLOYMENT STEPS"
    sfdx force:data:tree:import -f data/ServiceChannel.json -u $orgname
    sfdx force:data:tree:import -f data/QueueRoutingConfig.json -u $orgname
    sfdx force:data:tree:import -f data/PresenceUserConfig.json -u $orgname
    sfdx force:data:tree:import -f data/ServicePresenceStatus.json -u $orgname 
    sfdx force:mdapi:deploy -d data/predeployment -u $orgname -w -1
    installManagedPackages
    echo "ENDED PRE-DEPLOYMENT STEPS"    
}

setParameters $1 $2 $3 $4 $5 $6
echo "Deployment Option: $deployoption" 
echo "Org Name: $orgname" 
echo "Scratch Org validity: $days days" 
echo "Username: $username"
echo "Output directory: $outputdirectory"
echo "Package Name: $packagename" 
echo "Community Site URL: $siteurl"

if [ "$deployoption" == 1 ] ; then
    echo "Create and deploy into Scratch Org"
    createScratch
    promptPreDeploymentCompleted
elif [ "$deployoption" == 2 ] ; then
    echo "deploy into Sandbox"
    deploySandbox
elif ([ "$deployoption" == 3 ] || [ "$deployoption" == 5 ]) ; then
    echo "deploy into Partner Org"
    if [ "$deployoption" == 5 ] ; then
        newOrgSetup
    fi
    deployPartnerSandbox
elif [ "$deployoption" == 4 ] ; then
    echo "deploy into Production Org"
    deployProduction
fi

