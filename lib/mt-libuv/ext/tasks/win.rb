# frozen_string_literal: true

file 'ext/libuv/build/gyp' => 'ext/libuv/build' do
    FileUtils.mkdir('ext/libuv/build') unless File.directory?('ext/libuv/build')
    result = true
    if not File.directory?('ext/libuv/build/gyp')
        result = system "ln", "-rs", "ext/gyp", "ext/libuv/build/gyp"
    end
    raise 'unable to download gyp' unless result
end

CLEAN.include('ext/libuv/build/gyp')

file "ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}" do
    target_arch = 'ia32'
    target_arch = 'x64' if FFI::Platform.x64?

    Dir.chdir("ext/libuv") do |path|
        system 'git', 'clone', 'https://chromium.googlesource.com/external/gyp', 'build/gyp'
        system 'vcbuild.bat', 'vs2017', 'shared', 'release', target_arch
    end
end

file "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}" => "ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}" do
    FileUtils.mkdir('ext/libuv/lib') unless File.directory?('ext/libuv/lib')
    FileUtils.cp("ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}", "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}")
end

CLOBBER.include("ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}")
