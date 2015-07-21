notice("MODULAR: deploy_hiera_override.pp")

$detach_db_plugin = hiera('detach-db', undef)
$hiera_dir = '/etc/hiera/override'
$plugin_yaml = "detach-db.yaml"
$plugin_name = "detach-db"

if $detach_db_plugin {
$network_metadata = hiera_hash('network_metadata')
$settings_hash = parseyaml($detach_db_plugin["yaml_additional_config"])
$nodes_hash = hiera('nodes')
$management_vip = hiera('management_vip')
$database_vip = pick($settings_hash['remote_db'],hiera('management_database_vip'))

###################
if hiera('role', 'none') == 'primary-db' {
  $primary_database = 'true'
} else {
  $primary_database = 'false'
}

if hiera('role', 'none') =~ /^primary/ {
  $primary_controller = 'true'
} else {
  $primary_controller = 'false'
}

#Set database_nodes values
$database_nodes = get_nodes_hash_by_roles($network_metadata, ['primary-db', 'db'])
echo($database_nodes)
$database_address_map = get_node_to_ipaddr_map_by_network_role($database_nodes, 'mgmt/database')
$database_nodes_ips = values($database_address_map)
$database_nodes_names = keys($database_address_map)

#TODO(mattymo): debug needing corosync_roles
case hiera('role', 'none') {
  /db/: {
    $corosync_roles = ['primary-db','db']
    $deploy_vrouter = 'false'
    $mysql_enabled = 'true'
    $corosync_nodes = $database_nodes
  }
  /controller/: {
    $deploy_vrouter = 'true'
    $mysql_enabled = 'false'
  }
  default: {
    $corosync_roles = ['primary-controller', 'controller']
    $corosync_nodes = hiera('controllers')
  }
}
#<%
#@database_nodes.each do |dbnode|
#%>  - <%= dbnode %>

###################
$calculated_content = inline_template('
primary_database: <%= @primary_database %>
database_vip: <%= @database_vip %>
<% if @database_nodes -%>
<% require "yaml" -%>
database_nodes:
<%= YAML.dump(@database_nodes).sub(/--- *$/,"") %> 
<% end -%>
mysqld_ipaddresses:
<% if @database_nodes_ips -%>
<%
@database_nodes_ips.each do |dbnode|
%>  - <%= dbnode %>
<% end -%>
<% end -%>
<% if @database_nodes_names -%>
mysqld_names:
<%
@database_nodes_names.each do |dbnode|
%>  - <%= dbnode %>
<% end -%>
<% end -%>
mysql:
  enabled: <%= @mysql_enabled %>
primary_controller: <%= @primary_controller %>
<% if @corosync_nodes -%>
<% require "yaml" -%>
corosync_nodes:
<%= YAML.dump(@corosync_nodes).sub(/--- *$/,"") %> 
<% end -%>
<% if @corosync_roles -%>
corosync_roles:
<%
@corosync_roles.each do |crole|
%>  - <%= crole %>
<% end -%>
<% end -%>
deploy_vrouter: <%= @deploy_vrouter %>
')

###################
file {'/etc/hiera/override':
  ensure  => directory,
} ->
file { "${hiera_dir}/${plugin_yaml}":
  ensure  => file,
  content => "${detach_db_plugin['yaml_additional_config']}\n${calculated_content}\n",
}

package {"ruby-deep-merge":
  ensure  => 'installed',
}

file_line {"${plugin_name}_hiera_override":
  path  => '/etc/hiera.yaml',
  line  => "  - override/${plugin_name}",
  after => '  - override/module/%{calling_module}',
}

}
