# Install hook code here

# Source and destination for the config files
assets_src = File.expand_path(File.join(File.dirname(__FILE__),'config','cached_asset_packager.yml'))
assets_dest = File.expand_path(File.join(RAILS_ROOT,'config','cached_asset_packager.yml'))

# Source and destination for the initializer files
config_src = File.expand_path(File.join(File.dirname(__FILE__),'config','cached_asset_packager.rb'))
config_dest = File.expand_path(File.join(RAILS_ROOT,'config','initializers','cached_asset_packager.rb'))

# Create a copy of the default assets.yml file in RAILS_ROOT/config
File.copy(assets_src,assets_dest)

# create a copy of the default cached_asset_packager.rb in RAILS_ROOT/config/initializers
File.copy(config_src,config_dest)


puts %Q{
  Cached Asset Packager is now installed!
  
  Manage your list of assets by editing #{assets_dest}
  
  Manage your configuration by editing #{config_dest}

}