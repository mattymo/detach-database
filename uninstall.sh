#!/bin/bash

DIR=`dirname ${BASH_SOURCE[0]}`
declare -a roles=(`ls $DIR/deployment_scripts/roles/`)

FUEL='/usr/bin/fuel'
REL=`$FUEL rel | grep -i ubuntu | awk '{print $1}'`
FUEL_REL=`$FUEL rel | grep -i ubuntu | awk '{print $NF}'`

function delete_database_vip {
  fuel rel --rel $REL --network download
  sed -i '/^    - database/d' "release_${REL}/networks.yaml"
  fuel rel --rel $REL --network --upload
}

function delete_roles {
  for role in ${roles[@]}; do
    $FUEL role --rel $REL | awk '{print $1}' | grep -qx ${role%.*}
	if [[ $? -eq 0 ]]; then
      $FUEL role --rel $REL --delete --role  ${role%.*}
 	fi
  done
}

delete_roles
delete_database_vip
rm -rf /etc/puppet/$FUEL_REL/modules/osnailyfacter/modular/detach-db
$FUEL rel --sync-deployment-tasks --dir /etc/puppet/$FUEL_REL

