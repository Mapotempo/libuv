# frozen_string_literal: true

file "ext/libuv/.libs/libuv.1.#{FFI::Platform::LIBSUFFIX}" => 'ext/libuv/build' do
    Dir.chdir("ext/libuv") do |path|
        system "sh", "autogen.sh"
        system "./configure"
        system "make"
    end
end

file "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}" => "ext/libuv/.libs/libuv.1.#{FFI::Platform::LIBSUFFIX}" do
    FileUtils.mkdir('ext/libuv/lib') unless File.directory?('ext/libuv/lib')
    FileUtils.cp("ext/libuv/.libs/libuv.1.#{FFI::Platform::LIBSUFFIX}", "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}")

    Dir.chdir("ext/libuv") do |path|
        system "make", "install"
    end
end

CLOBBER.include("ext/libuv/.libs/libuv.1.#{FFI::Platform::LIBSUFFIX}")
