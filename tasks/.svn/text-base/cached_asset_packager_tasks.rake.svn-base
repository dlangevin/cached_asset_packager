# desc "Explaining what the task does"
# task :cached_asset_packager do
#   # Task goes here
# end

# load up our configuration file
namespace :cached_asset_packager do
  desc "create cache files for the current revision" 
  task :create_cache_files => :environment do
    CachedAssetPackager::Base.load(File.join(RAILS_ROOT,"config","cached_asset_packager.yml"))
    CachedAssetPackager::Base.create_cache_files
  end
end
