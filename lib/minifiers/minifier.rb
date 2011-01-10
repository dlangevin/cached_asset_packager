module CachedAssetPackager
  class Minifier
    def minify!(file_name)
      raise NotImplementedError.new("#{self.class} must implement minify!")
    end
  end
  class JsPackerMinifier < Minifier
    def minify!(file_name)
      IO.popen("cd #{File.expand_path(File.dirname(__FILE__))} && ./js_packer.pl -e62 -i #{file_name} -o #{file_name}") do |p|
        puts p.read
      end
    end
  end
  class YUIJsMinifier < Minifier
    def minify!(file_name)
      IO.popen(%Q{ cd #{File.join(File.expand_path(File.dirname(__FILE__)),'yuicompressor-2.4.1','build')} &&  java -jar yuicompressor-2.4.1.jar #{file_name} --type js -o #{file_name}}) do |p|
        puts p.read
      end
    end
  end
  class YUICssMinifier < Minifier
    def minify!(file_name)
      IO.popen(%Q{ cd #{File.join(File.expand_path(File.dirname(__FILE__)),'yuicompressor-2.4.1','build')} &&  java -jar yuicompressor-2.4.1.jar #{file_name} --type css -o #{file_name}}) do |p|
        puts p.read
      end
    end
  end
end