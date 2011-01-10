=begin rdoc
	Configure CachedAssetPackager to your liking.  This allows you to set the following options for 
	any asset type
	- extension
	- base_dir
	- minifier

	You may also set the global use_cache option
=end

CachedAssetPackager.configure do |config|
	# uncomment to use a minifier
	#
	# Minifiers supplied are:
	#	- YUIJsMinifier
	# - YUICssMinifier
	# - JsPackerMinifier
	#
	config.javascript_minifier = CachedAssetPackager::YUIJsMinifier
	config.stylesheet_minifier = CachedAssetPackager::YUICssMinifier
	
	# uncomment set use_cache to whatever ActionController::Base is doing
	# 
	config.use_cache = ActionController::Base.perform_caching
  
    
end
		