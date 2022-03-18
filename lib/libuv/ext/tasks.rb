# frozen_string_literal: true

module FFI::Platform
    def self.ia32?
        ARCH == "i386"
    end

    def self.x64?
        ARCH == "x86_64"
    end

    def self.arm64?
        ARCH == "aarch64"
    end
end

file 'ext/libuv/build' do
    system "git", "submodule", "update", "--init"
end

if FFI::Platform.windows?
    require File.join File.expand_path("../", __FILE__), 'tasks/win'
elsif FFI::Platform.mac?
    require File.join File.expand_path("../", __FILE__), 'tasks/mac'
else # UNIX
    require File.join File.expand_path("../", __FILE__), 'tasks/unix'
end
