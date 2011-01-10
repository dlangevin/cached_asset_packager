require 'rubygems'
gem 'rspec'
require 'spec'
require 'ruby-debug'


require File.join(File.dirname(__FILE__),"..","lib","cached_asset_packager")

TEST_BASE_DIR = File.join(File.expand_path(File.dirname(__FILE__)),"fixtures","javascripts")

describe CachedAssetPackager::Base do
  before(:each) do
    CachedAssetPackager::Base.load(File.join(File.dirname(__FILE__),"fixtures","assets.yml"))
    CachedAssetPackager::Base.javascript.base_dir = TEST_BASE_DIR
    CachedAssetPackager::Config.use_cache = true
  end
  
  before(:all) do
    # should only get the latest revision # once
    class CachedAssetPackager::Base
      def self.latest_revision_number(arg)
        puts "OLD GETTING REV #"
        return 6000
      end
    end
    
    CachedAssetPackager.configure do |c|
      c.javascript_cache_path_config = File.join(File.dirname(__FILE__),"fixtures","javascript_cache_paths.yml")
    end
    
  end

  it "should be able to read a default set of javascript paths" do
    CachedAssetPackager::Base.javascript_paths_for(:default).should eql([
      "#{TEST_BASE_DIR}/test.js",
      "#{TEST_BASE_DIR}/test/test_2.js",
    ])
  end
  it "should be able to read a default set of javascript include paths" do
     CachedAssetPackager::Base.javascript_paths_for(:default).should eql([
      "#{TEST_BASE_DIR}/test.js",
      "#{TEST_BASE_DIR}/test/test_2.js",
    ])
  end
  it "should be configurable per controller" do
    CachedAssetPackager::Base.javascript_paths_for(:search).should eql([
      "#{TEST_BASE_DIR}/test.js",
      "#{TEST_BASE_DIR}/test/test_2.js",
      "#{TEST_BASE_DIR}/search.js",
      "#{TEST_BASE_DIR}/search2.js"
    ])
  end
  it "should be configurable per action" do
    CachedAssetPackager::Base.javascript_paths_for(:search,:results).should eql([
      "#{TEST_BASE_DIR}/test.js",
      "#{TEST_BASE_DIR}/test/test_2.js",
      "#{TEST_BASE_DIR}/search.js",
      "#{TEST_BASE_DIR}/search2.js",
      "#{TEST_BASE_DIR}/abc.js",
      "#{TEST_BASE_DIR}/def.js"
    ])
  end
  it "should be able to create a cache file for a controller/action" do
    remove_cache_files
    # calling this should create a new cache file
    file_name = CachedAssetPackager::Base.javascript.create_cache_file(:search,:results)
    File.exists?(file_name).should eql(true)
  end
  
  it "should use the latest revision number in creating the cache files" do
    remove_cache_files
    # calling this should create a new cache file
    file_name = CachedAssetPackager::Base.javascript.create_cache_file(:search,:results)
    (Regexp.new(CachedAssetPackager::Base.latest_revision_number(TEST_BASE_DIR).to_s + ".js$") =~ file_name).should_not be_nil
  end
  
  it "should be able to automatically create cache files for all controller/action combos" do
    remove_cache_files
    CachedAssetPackager::Base.create_cache_files
  end
  
  it "should be able to generate the correct include name for its cache file" do
    file_list = CachedAssetPackager::Base.javascript_paths_for(:search,:results)
    file_name = "cache_" + Digest::SHA1.hexdigest(file_list.uniq.join(",")) + "_6000.js"
    CachedAssetPackager::Base.javascript_includes_for(:search,:results).should eql(file_name)
  end
  
  it "should be able to generate the correct list of include files when use_cache is false" do
    CachedAssetPackager::Config.use_cache = false
    CachedAssetPackager::Base.javascript_includes_for(:search,:results).should eql([
      "test",
      "test/test_2",
      "search",
      "search2",
      "abc",
      "def"
    ])
  end
  
  it "should use a minifier if available" do
    CachedAssetPackager::Base.javascript.minifier = CachedAssetPackager::YUIJsMinifier.new
    remove_cache_files
    CachedAssetPackager::Base.create_cache_files
  end
  
  it "should use default settings when first initialized" do
    CachedAssetPackager::Base.load(File.join(File.dirname(__FILE__),"fixtures","assets.yml"))
    CachedAssetPackager::Base.javascript.base_dir.should eql(File.join(RAILS_ROOT,"public","javascripts"))
    CachedAssetPackager::Base.javascript.minifier.should eql(nil)
  end
  
  it "should allow for configuration to be modified" do
    CachedAssetPackager.configure do |config|
      config.javascript_extension = ".cjs"
    end
    
    CachedAssetPackager::Base.load(File.join(File.dirname(__FILE__),"fixtures","assets.yml"))
    CachedAssetPackager::Base.javascript.extension.should eql(".cjs")
    
  end
  
  it "should not recreate cache files if their contents have not changed" do
    remove_cache_files
    file_name = CachedAssetPackager::Base.javascript.create_cache_file(:search,:results)
    old_mod_time = File.mtime(file_name)
    #sleep for 2 seconds
    sleep(2)
    CachedAssetPackager::Base.javascript.create_cache_file(:search,:results)
    File.mtime(file_name).should eql(old_mod_time)
  end
  
  it "should re-create cache files if their contents have changed (based on latest revision #)" do
    remove_cache_files
    old_file_name = CachedAssetPackager::Base.javascript.create_cache_file(:search,:results)
    old_mod_time = File.mtime(old_file_name)
    
    # stub latest rev # to 6001
    class CachedAssetPackager::Base
      def self.latest_revision_number(arg)
        puts "GETTING REV #"
        return 6001
      end
    end 
    new_file_name = CachedAssetPackager::Base.javascript.create_cache_file(:search,:results)
    
    old_file_name.should_not eql(new_file_name)
    File.mtime(new_file_name).should_not eql(old_mod_time)
    
  end
  
end

def remove_cache_files
  `rm -rf #{TEST_BASE_DIR}/cache*`
end
