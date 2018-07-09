#!/bin/bash

## AWS CloudFront Distribution Creation
#
# Version - 1.0
# Vishnuvardhan Krishnan
##

dt=$(date +%Y%m%d%H%M)

#CloudFront Configuration Path
CF_PATH="/home/vk632740/cf-setup"
logfile="$CF_PATH/cfsetup-$dt.log"

#Input Site count & details
read -p "Enter Number of Sites to be on-boarded : " no_sites

if [ $no_sites -ge 1 ]; then
        for ((i=1;; i++)); do
                read -p "Enter domain name of Site#$i (example: gskpro.com): " sitedomain[$i]
				sitedomain[$i]=$(echo ${sitedomain[$i]} | sed -e 's/www\.//g')

                if [ $i == $no_sites ]; then break; fi
        done
else
        echo "Enter Valid Site Count" |tee -a $logfile
fi

if [ $no_sites -ge 1 ]; then
        for ((i=1;; i++)); do
        echo "Site#$i is ${sitedomain[$i]}" |tee -a $logfile

                #Validate if domain is valid FQDN
                host ${sitedomain[$i]} 2>&1 > /dev/null
                if [ $? -ne 0 ];then
                        echo "${sitedomain[$i]} is not a valid domain. Try again!" |tee -a $logfile
						exit 1
                fi

                #Find AEM version of the site
                actualsite=$(curl http://${sitedomain[$i]} -s -L -I -o /dev/null -w '%{url_effective}')
                unit=$(curl -sD - -o /dev/null $actualsite | grep x-platform |sed 's/.*: //g' |sed 's/.\{3\}$//')

                #Find if site is already consumes CloudFront
                cloudfront_yn=$(curl -sD - -o /dev/null $actualsite | grep X-Cache |sed 's/.*: //g')
                if [[ $cloudfront_yn = *"cloudfront"* ]];
                then
                        echo "Site ${sitedomain[$i]} is already live on CloudFront!!" |tee -a $logfile
                        exit 1
                fi

                #Assign CloudFront template based on CF version
                if [[ $unit = "cf2" ]];
                then
                        echo "Website ${sitedomain[$i]} hosted on AEM 5.6.1 CF2" |tee -a $logfile
                        CF_CONFIG="$CF_PATH/cf2.json"
                elif [[ $unit = "cf3" ]];
                then
                        echo "Website ${sitedomain[$i]} hosted on AEM 6.0 CF3" |tee -a $logfile
                        CF_CONFIG="$CF_PATH/cf3.json"
                elif [[ $unit = "cf5" ]];
                then
                        echo "Website ${sitedomain[$i]} hosted on AEM 6.2 CF5" |tee -a $logfile
                        CF_CONFIG="$CF_PATH/cf5.json"
                else
                        echo "Site ${sitedomain[$i]} is non-AEM site." |tee -a $logfile
                        exit 1
                fi

                #CloudFront Distribution Comment. Using site name as comment.
                #read -p "Enter Comment for CloudFront Distro (preferably site desc): " comment

                SITE_JSON="$CF_PATH/${sitedomain[$i]}.json"
                SITE_OUTPUT_JSON="$CF_PATH/${sitedomain[$i]}-output.json"

                echo " " > $SITE_JSON
                sed "s|sitename|${sitedomain[$i]}|g;s|timestamp|$(date +%Y%m%d%H%M%S)|g;s|commentation|${sitedomain[$i]}|g;" $CF_CONFIG >> $SITE_JSON

                #Create AWS CloudFront Distribution
                aws cloudfront create-distribution --distribution-config file://$SITE_JSON >> $SITE_OUTPUT_JSON 2>&1

                #Error validations
                error_check1=$(/bin/grep -i "InvalidClientTokenId" $SITE_OUTPUT_JSON | wc -l)
                error_check2=$(/bin/grep -i "CNAMEAlreadyExists" $SITE_OUTPUT_JSON | wc -l)
                error_check3=$(/bin/grep -i "DistributionAlreadyExists" $SITE_OUTPUT_JSON | wc -l)

                if [[ "$error_check1" -gt "0" ]];
                then
                        echo "You don't have required permissions to create CloudFront Distribution" |tee -a $logfile
                        exit 1
                elif [[ "$error_check2" -gt "0" ]];
                then
                        echo "CloudFront Distribution already exists for the website ${sitedomain[$i]}. Check if Route53 record updated" |tee -a $logfile
                        exit 1
                elif [[ "$error_check3" -gt "0" ]];
                then
                        echo "CloudFront Distribution already exists for the website ${sitedomain[$i]}. Check if Route53 record updated" |tee -a $logfile
                        exit 1
                else
                        CF_ID=$(cat $SITE_OUTPUT_JSON | grep "\"Id\"" | grep -v origin |sed 's/.*: //g' | sed 's/,//g')
                        echo "CloudFront Distro Created for the website ${sitedomain[$i]} and ID is $CF_ID" |tee -a $logfile
                fi

        if [ $i == $no_sites ]; then break; fi
        done
fi

#END OF SCRIPT
