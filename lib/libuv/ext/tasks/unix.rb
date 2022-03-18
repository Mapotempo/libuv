# frozen_string_literal: true

file 'ext/libuv/build/gyp' => 'ext/libuv/build' do
    result = true
    if not File.directory?('ext/libuv/build/gyp')
        result = system "git", "clone", "https://chromium.googlesource.com/external/gyp", "ext/libuv/build/gyp"
    end
    raise 'unable to download gyp' unless result
end

CLEAN.include('ext/libuv/build/gyp')

file 'ext/libuv/out' => 'ext/libuv/build/gyp' do
    target_arch = 'ia32'if FFI::Platform.ia32?
    target_arch = 'x64' if FFI::Platform.x64?
    target_arch = 'arm64' if FFI::Platform.arm64?

    abort "Don't know how to build on #{FFI::Platform::ARCH} (yet)" unless target_arch

    Dir.chdir("ext/libuv") do |path|
        system "./gyp_uv.py -f make -Dtarget_arch=#{target_arch} -Duv_library=shared_library -Dcomponent=shared_library"
    end
end

file "ext/libuv/out/Release/lib.target/libuv.#{FFI::Platform::LIBSUFFIX}" => 'ext/libuv/out' do
    Dir.chdir("ext/libuv") do |path|
        system 'make -C out BUILDTYPE=Release'
    end
end

file "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}" => "ext/libuv/out/Release/lib.target/libuv.#{FFI::Platform::LIBSUFFIX}" do
    FileUtils.mkdir('ext/libuv/lib') unless File.directory?('ext/libuv/lib')
    begin
        FileUtils.cp("ext/libuv/out/Release/lib.target/libuv.#{FFI::Platform::LIBSUFFIX}", "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}")
    rescue => e
        FileUtils.cp("ext/libuv/out/Release/lib.target/libuv.#{FFI::Platform::LIBSUFFIX}.1", "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}")
    end
end

CLEAN.include('ext/libuv/out')
CLOBBER.include("ext/libuv/out/Release/lib.target/libuv.#{FFI::Platform::LIBSUFFIX}")
