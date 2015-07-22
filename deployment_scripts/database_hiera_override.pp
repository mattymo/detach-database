notice("MODULAR: deploy_hiera_override.pp")

$detach_database_plugin = hiera('detach-database', undef)
$hiera_dir = '/etc/hiera/override'
$plugin_name = 'detach-database'
$plugin_yaml = "${plugin_name}.yaml"

if $detach_database_plugin {
$network_metadata = hiera_hash('network_metadata')
$settings_hash = parseyaml($detach_database_plugin["yaml_additional_config"])
$nodes_hash = hiera('nodes')
$management_vip = hiera('management_vip')
$database_vip = pick($settings_hash['remote_database'],hiera('management_database_vip'))

###################
if hiera('role', 'none') == 'primary-database' {
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
$database_nodes = get_nodes_hash_by_roles($network_metadata, ['primary-database', 'database'])
$database_address_map = get_node_to_ipaddr_map_by_network_role($database_nodes, 'mgmt/database')
$database_nodes_ips = values($database_address_map)
$database_nodes_names = keys($database_address_map)

#TODO(mattymo): debug needing corosync_roles
case hiera('role', 'none') {
  /database/: {
    $corosync_roles = ['primary-database','database']
    $deploy_vrouter = 'false'
    $mysql_enabled = 'true'
    $corosync_nodes = $database_nodes
  }
  /controller/: {
    $mysql_enabled = 'false'
  }
  default: {
  }
}
#<%
#@database_nodes.each do |databasenode|
#%>  - <%= databasenode %>

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
@database_nodes_ips.each do |databasenode|
%>  - <%= databasenode %>
<% end -%>
<% end -%>
<% if @database_nodes_names -%>
mysqld_names:
<%
@database_nodes_names.each do |databasenode|
%>  - <%= databasenode %>
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
  content => "${detach_database_plugin['yaml_additional_config']}\n${calculated_content}\n",
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
