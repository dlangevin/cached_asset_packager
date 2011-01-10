# Include hook code here
require File.join(File.dirname(__FILE__),'lib','cached_asset_packager')

CachedAssetPackager::Base.load(File.join(RAILS_ROOT,'config','cached_asset_packager.yml'))
