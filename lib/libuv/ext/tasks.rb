# frozen_string_literal: true

module FFI::Platform
    def self.ia32?
        ARCH == "i386"
    end

    def self.x64?
        ARCH == "x86_64"
    end
end

file 'ext/libuv/build' do
    system "git", "submodule", "update", "--init"
end

file 'ext/libuv/build/gyp' => 'ext/libuv/build' do
    result = true
    if not File.directory?('ext/libuv/build/gyp')
        result = system "git", "clone", "https://chromium.googlesource.com/external/gyp", "ext/libuv/build/gyp"
    end
    raise 'unable to download gyp' unless result
end

CLEAN.include('ext/libuv/build/gyp')

if FFI::Platform.windows?
    require File.join File.expand_path("../", __FILE__), 'tasks/win'
elsif FFI::Platform.mac?
    require File.join File.expand_path("../", __FILE__), 'tasks/mac'
else # UNIX
    require File.join File.expand_path("../", __FILE__), 'tasks/unix'
end
