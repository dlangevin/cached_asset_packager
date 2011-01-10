require 'yaml'
require 'digest/md5'
require File.expand_path(File.dirname(__FILE__)) + '/minifiers/minifier'

# set RAILS_ROOT if for some reason it's not defined
unless defined?(RAILS_ROOT)
  RAILS_ROOT = Rails.root
end

# set up a config_dir constant


module CachedAssetPackager
=begin rdoc
  Apply configuration to CachedAssetPackager
=end
  def self.configure(&block)
    yield(CachedAssetPackager::Config)
  end

=begin rdoc
  
=end
  class Base
    @@assets = nil
    @@latest_revision_number = {}
=begin rdoc
    Setting for whether or not to generate links with cached file names
=end
    def self.use_cache=(use_cache)
      @@use_cache = use_cache
    end
=begin rdoc
    Accessor for use_cache
=end
    def self.use_cache?
      return @@use_cache
    end 
=begin rdoc
  Load a YAML config file
=end
    def self.load(file_name)
      
      raise ArgumentError.new("#{file_name} does not exist!") unless File.exists?(file_name)
      # attempt to load and initialize AssetSets for each type of asset defined
      # in our YAML file
      @@assets = self.symbolize_keys(YAML.load(File.read(file_name)))
      @@assets.each_pair do |key,val|
        # convert javascripts to JavascriptAssetSet
        # and set @@javascript = JavascriptAssetSet.new
        class_variable_set(
          "@@#{key.to_s.gsub(/s$/,'')}".to_sym,
          # taken from Rails Inflector::constantize
          Object.module_eval("::CachedAssetPackager::#{key.to_s.gsub(/s$/,'').capitalize.gsub(/_(\w)/,'$1'.upcase)}AssetSet",__FILE__,__LINE__).new(val))
        class_eval(%Q{
          def self.#{key.to_s.gsub(/s$/,'')}
             class_variable_get("@@#{key.to_s.gsub(/s$/,'')}".to_sym)
          end
        })
      end
    end  
=begin rdoc
    Create all of the cache files for the assets defined in assets.yml
=end
    def self.create_cache_files
      # we reset cache path names here so that we get the latest cache path based on assets.yml
      @@assets.keys.each do |asset_type|
        class_variable_get("@@#{asset_type.to_s.gsub(/s$/,'')}").send(:create_cache_files)
      end
    end
=begin rdoc
    Get the latest revision number
=end   
    def self.latest_revision_number(path)
      @@latest_revision_number[path] ||= self.get_latest_revision_number(path)
    end
  
  private
=begin rdoc
    Get the latest revision number from a file, or attempt to retrieve it from SVN
=end
    def self.get_latest_revision_number(path)
      # get the latest revision number from svn
      IO.popen("svn info #{path}") do |p|
        rev = p.read.scan(/^Last Changed Rev: (.*)$/).flatten.first.to_i
        return rev
      end
      raise "No Revision Number Found" unless rev
    end
     
=begin 
  Dynamically forward ASSET_TYPE_includes_for and
  ASSET_TYPE_paths_for to the appropriate class variables

  E.g.
    CachedAssetPackager::Base.javascript_includes_for(:controller,:action)
      => @@javascript.includes_for(:controller,:action)

=end
    def self.method_missing(method,*args,&block)
      method = method.to_s
      if /includes_for$/ =~ method
        class_variable_get("@@#{method.scan(/(^\w+)_includes_for/).first.first.gsub(/s$/,'')}").send(:includes_for,*args)
      elsif /paths_for$/ =~ method
        class_variable_get("@@#{method.scan(/(^\w+)_paths_for/).first.first.gsub(/s$/,'')}").send(:paths_for,*args)
      else
        raise NoMethodError.new(%Q{#{method} is not defined.  Valid methods are #{@@assets.keys.collect{|k|["#{k}(singular or plural)_includes_for,#{k}(singular or plural)_paths_for"]}.flatten.join(",")}})
      end
    end
=begin rdoc
    Helper method to convert keys in a hash to symbols recursively
=end
    def self.symbolize_keys(hash)
      hash.each_pair do |k,v|
        if v.is_a?(Hash)
          hash[k.to_sym] = self.symbolize_keys(v)
        else
          hash[k.to_sym] = v
        end
        hash.delete(k.to_s)
      end
    end    
  end
  
  class AssetSet
    # make these settings configurable for each AssetSet
    attr_accessor :base_dir, :extension, :minifier, :cache_path_names
    
    def initialize(files)
      @files = files
      @base_dir = CachedAssetPackager::Config.send("#{self.asset_type}_base_dir")
      @extension = CachedAssetPackager::Config.send("#{self.asset_type}_extension")
      # add in the minifier. Set this to false if you don't want to minify
      @minifier = CachedAssetPackager::Config.send("#{self.asset_type}_minifier").new if CachedAssetPackager::Config.send("#{self.asset_type}_minifier").is_a?(Class)
        
      # we can use this to store our cache path names for quick lookup
      # this should read a .yml file from the config directory
      get_cache_path_names
    end
=begin rdoc
    Get the full paths for the included asset files
=end
    def paths_for(controller=:_all,action=:_all)
      return files_for(:paths,controller,action)
    end
=begin rdoc
    Get the relative paths from @base_dir for the included asset files
=end
    def includes_for(controller=:_all,action=:_all)
      unless CachedAssetPackager::Config.use_cache?
        return files_for(:includes,controller,action)
      end
      return cache_path_name(controller,action).gsub(@base_dir + "/",'')
    end 
=begin rdoc
    Create all cache files
=end
    def create_cache_files
      @cache_path_names = {}
      each_file_set(:create_cache_file)
      write_cache_path_file
    end
=begin rdoc

=end
    def write_cache_path_file
      File.open(CachedAssetPackager::Config.send("#{self.asset_type}_cache_path_config"),'w') do |f|
        f.write(YAML::dump(@cache_path_names))
      end
    end
=begin rdoc
    Simply calling cache_path_name for each controller/action
    will cache the resulting path to the file.  
    We do this on start-up so that there is no performance hit the when this
    path needs to be generated
=end
    def get_cache_path_names
      if File.exists?(CachedAssetPackager::Config.send("#{self.asset_type}_cache_path_config"))
        @cache_path_names = YAML::load(File.read(CachedAssetPackager::Config.send("#{self.asset_type}_cache_path_config")))
      else
        @cache_path_names = {}
        each_file_set(:cache_path_name)
        write_cache_path_file
      end
    end
=begin rdoc
    Generate the unique path for a cache file
=end
    def cache_path_name(controller=:_all,action=:_all)
      controller, action = normalize_request_params(controller,action)
      
      # if we have cached the 
      return @cache_path_names["#{controller}_#{action}"] if @cache_path_names["#{controller}_#{action}"]
      
      # let's get the latest revision number of all of the paths provided
      latest_revision_number = paths_for(controller,action).uniq.collect do |p|
        CachedAssetPackager::Base.latest_revision_number(p)
      end.sort.last 
      
      #puts paths_for(controller,action).uniq.join("\n")
      
      file_name = Digest::MD5.hexdigest(paths_for(controller,action).uniq.join(","))
      
      @cache_path_names["#{controller}_#{action}"] = File.join(@base_dir,"cache_#{file_name}_#{latest_revision_number}#{@extension}")
      return @cache_path_names["#{controller}_#{action}"]
    end
=begin rdoc
    Expand the paths for a set of files
    == Options
    - :files (required) a list of files to expand paths for
    - :base_dir (optional, defaults to @base_dir) the root of the path.  E.g. RAILS_ROOT/public for paths
    - :default_subdir (optional defaults to nil) A default subdirectory.  E.g. javascripts for js kept in RAILS_ROOT/public/javascripts.  
    - :extension (optional defaults to @extension)
=end
    def create_cache_file(controller=:_all,action=:_all)
      files = paths_for(controller,action).uniq
      path_name = cache_path_name(controller,action)
      
      # if we already have the file, we can just skip this step
      if File.exists?(path_name)
        puts "Skipped creating/updating #{controller}::#{action} (Nothing changed)" if RAILS_ENV == "development"
        return path_name
      end
      
      cache_content = ""
      # otherwise, we create the file
      files.each do |f|
        if File.exists?(f)
          cache_content +=  File.new(f).read
        else
          # TODO: add some debug info for when an included file doesn't exist
        end
      end
      # write out the content
      File.open(path_name,"w") do |f|
        f.write(cache_content)
      end
      
      # if we have a minifier, use it
      @minifier.minify!(path_name) if @minifier
      
      puts "\nCreated #{path_name} "
      puts "with \n\t #{files.join("\n\t")}\n" if RAILS_ENV == "development"
      path_name
    end
  
    def expand_paths(opts={})
      files = opts.delete(:files) || []
      base_dir = opts.delete(:base_dir) || @base_dir
      extension = opts.delete(:extension) || @extension
      
      return files.collect do |file|
        base_dir.length == 0 ? file + extension : File.join(base_dir,file) + extension
      end
    end
    def files_for(type,controller=:_all,action=:_all)
      controller, action = normalize_request_params(controller,action)
      
      base_dir = type == :includes ? "" : @base_dir
      extension = type == :includes ? "" : @extension
      
      # do we include the base defaults
      if @files[controller]
        include_base_defaults = @files[controller][:include_base_defaults]  
      end
      include_base_defaults = true if include_base_defaults.nil?
      
      ret = []
      
      unless include_base_defaults == false
        ret += expand_paths({
          :base_dir => base_dir,
          :extension => extension,
          :files => @files[:defaults]
        })
      end
      if @files[controller]
        ret += expand_paths({
          :base_dir => base_dir,
          :extension => extension,
          :files => @files[controller][:defaults],
        }) 
      end
      if @files[controller] && @files[controller][action]
        ret += expand_paths({
          :base_dir => base_dir,
          :extension => extension,
          :files => @files[controller][action],
        }) 
      end
      return ret
    end    
    protected
=begin
    Extracts the name of the asset type from the classname
    E.g.

      CachedAssetPackager::JavascriptAssetSet.new(files).asset_type
        => :javascript
=end
    def asset_type
      return self.class.to_s.gsub(/^.*::/,'').gsub(/AssetSet/,'').gsub(/([^^])([A-Z])/,'$1_$2').downcase.to_sym
    end
=begin rdoc
    Apply a method to each file
=end   
    def each_file_set(method)
      # default cache file
      self.send(method)
      @files.keys.each do |controller_name|
        #skip default
        next if controller_name == :defaults
        
         # each controller's default
        self.send(method,controller_name)
        
        @files[controller_name].keys.each do |action_name|
          #skip default
          next if action_name == :defaults
          # create cache file for each action
          self.send(method,controller_name,action_name)
        end
      end
    end
=begin rdoc
    Normalize a controller/action combination so that we do not need
    to store separate info for each controller/action combination, just for ones that
    have a unique file set
=end
    def normalize_request_params(controller_name,action_name)
      return :_all, :_all unless @files[controller_name.to_sym]
      return controller_name.to_sym, :_all unless @files[controller_name.to_sym][action_name.to_sym]
      return controller_name.to_sym, action_name.to_sym
    end
  end
  
  class JavascriptAssetSet < AssetSet
  end
  class StylesheetAssetSet < AssetSet
  end
=begin rdoc
  Configuration object
=end
  class Config
    @@use_cache = true
    @@base_dirs = {
      :javascript => File.join(RAILS_ROOT,"public","javascripts"),
      :stylesheet => File.join(RAILS_ROOT,"public","stylesheets")
    }
    @@extensions = {
      :javascript => ".js",
      :stylesheet => ".css"
    }
    @@minifiers = {
      :javascript => false,
      :stylesheet => false
    }
    @@cache_path_configs = {
      :javascript => File.expand_path(File.join(RAILS_ROOT,'tmp','javascript_cache_paths.yml')),
      :stylesheet => File.expand_path(File.join(RAILS_ROOT,'tmp','stylesheet_cache_paths.yml'))
    }
=begin rdoc
    Determine whether or not to use caching
=end
    def self.use_cache?
      return @@use_cache
    end
=begin rdoc
    Set whether or not to use cache
=end
    def self.use_cache=(boolean)
      @@use_cache = boolean
    end
    private
    # forward all requests to the appropriate handler, accounting for type
    def self.method_missing(method,*args,&block)
      method = method.to_s
      if match_data =  Regexp.new(/(base_dir|extension|minifier|cache_path_config)=?/).match(method)
        # convert javascript_base_dir to :javascript
        type = method.gsub("_#{match_data[0]}","").to_sym
        args.unshift(type)
        self.send(match_data[0],*args)
      else
        raise NotImplementedError.new("#{method} is not a valid config option")
      end
    end
    def self.base_dir(type)
      return @@base_dirs[type]
    end
    def self.extension(type)
      return @@extensions[type]
    end
    def self.minifier(type)
      return @@minifiers[type]
    end
    def self.cache_path_config(type)
      return @@cache_path_configs[type]
    end
    def self.base_dir=(type,dir)
      @@base_dirs[type] = dir
    end
    def self.extension=(type,extension)
      @@extensions[type] = extension
    end
    def self.minifier=(type,minifier_class)
      @@minifiers[type] = minifier_class
    end
    def self.cache_path_config=(type,file_name)
      @@cache_path_configs[type] = file_name
    end
  end
  
end


