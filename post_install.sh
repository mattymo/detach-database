#!/bin/bash
PLUGIN_DIR=/var/www/nailgun/plugins/%{name}
declare -a roles=(`ls ${PLUGIN_DIR}/deployment_scripts/roles/`)

FUEL='/usr/bin/fuel'
REL=`$FUEL rel | grep -i ubuntu | awk '{print $1}' | head`
FUEL_REL=`$FUEL rel | grep -i ubuntu | awk '{print $NF}'`

#FIXME(mattymo): remove when vip from plugin is merged
function create_database_vip {
  fuel rel --rel $REL --network download
  if ! grep -q -- "    - database" "release_${REL}/networks.yaml"; then
    sed -i 's/    - vrouter/    - vrouter\n    - database/' "release_${REL}/networks.yaml"
    fuel rel --rel $REL --network --upload
  else
    echo "Database VIP already exists. Skipping..."
  fi
}

#FIXME(mattymo): remove when role-as-a-plugin is merged
function create_roles {
  for role in ${roles[@]}; do
    $FUEL role --rel $REL | awk '{print $1}' | grep -qx ${role%.*}
      if [[ $? -eq 0 ]]; then
        $FUEL role --rel $REL --update --file ${PLUGIN_DIR}/deployment_scripts/roles/${role}
      else
        $FUEL role --rel $REL --create --file ${PLUGIN_DIR}/deployment_scripts/roles/${role}
      fi
  done
}

create_roles
create_database_vip
cp -a ${PLUGIN_DIR}/deployment_scripts/detach-db /etc/puppet/$FUEL_REL/modules/osnailyfacter/modular/
$FUEL rel --sync-deployment-tasks --dir /etc/puppet/$FUEL_REL

