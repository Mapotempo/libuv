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

    user_lib = "#{ENV['HOME']}/lib"
    FileUtils.mkdir(user_lib) unless File.directory?(user_lib)

    # Useful for building other libraries that wish to use Libuv
    FileUtils.cp("ext/libuv/.libs/libuv.1.#{FFI::Platform::LIBSUFFIX}", "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}")

    # Primrary load location - falls back to above if not available
    FileUtils.cp("ext/libuv/.libs/libuv.1.#{FFI::Platform::LIBSUFFIX}", "#{user_lib}/libuv.#{FFI::Platform::LIBSUFFIX}")
end

CLOBBER.include("ext/libuv/.libs/libuv.1.#{FFI::Platform::LIBSUFFIX}")
