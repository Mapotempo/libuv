# frozen_string_literal: true

require File.expand_path("../lib/mt-libuv/version", __FILE__)

Gem::Specification.new do |gem|
    gem.name          = "mt-libuv"
    gem.version       = MTLibuv::VERSION
    gem.license       = 'MIT'
    gem.authors       = ["Giallombardo Nathan"]
    gem.email         = ["nathan.giallombardo@mapotempo.com"]
    gem.homepage      = "https://github.com/Mapotempo/mt-libuv"
    gem.summary       = "mt-libuv bindings for Ruby"
    gem.description   = "An opinionated wrapper around mt-libuv for Ruby"

    gem.extensions << "ext/Rakefile"

    gem.required_ruby_version = '>= 2.0.0'
    gem.require_paths = ["lib"]

    gem.add_runtime_dependency     'ffi', '~> 1.9'
    gem.add_runtime_dependency     'concurrent-ruby', '~> 1.0'
    gem.add_runtime_dependency     'mt-ruby-tls', '~> 2.1'

    gem.add_development_dependency 'rspec', '~> 3.5'
    gem.add_development_dependency 'rake', '~> 11.2'
    gem.add_development_dependency 'yard', '~> 0.9'

    gem.files         = `git ls-files`.split("\n")
    gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

    if File.exist? 'ext/libuv.dll'
        gem.files << 'ext/libuv.dll'
    end 

    # Add the submodule to the gem
    relative_path = File.expand_path("../", __FILE__) + '/'
    `git submodule --quiet foreach pwd`.split($\).each do |submodule_path|

        if (ENV['OS'] == 'Windows_NT') && submodule_path[0] == '/'
            # Detect if cygwin path is being used by git
            submodule_path = submodule_path[1..-1]
            submodule_path.insert(1, ':')
        end

        # for each submodule, change working directory to that submodule
        Dir.chdir(submodule_path) do
            # Make the submodule path relative
            submodule_path = submodule_path.gsub(/#{relative_path}/i, '')
    
            # issue git ls-files in submodule's directory
            submodule_files = `git ls-files`.split(/\n+|\r+/)
    
            # prepend the submodule path to create relative file paths
            submodule_files_paths = submodule_files.map do |filename|
                File.join(submodule_path, filename)
            end
    
            # add relative paths to gem.files
            gem.files += submodule_files_paths
        end
    end
end
