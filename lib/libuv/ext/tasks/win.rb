file "ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}" do
    target_arch = 'ia32'
    target_arch = 'x64' if FFI::Platform.x64?

    Dir.chdir("ext/libuv") do |path|
        system 'git', 'clone', 'https://chromium.googlesource.com/external/gyp', 'build/gyp'
        system 'vcbuild.bat', 'shared', 'release', target_arch
    end
end

file "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}" => "ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}" do
    FileUtils.mkdir('ext/libuv/lib') unless File.directory?('ext/libuv/lib')
    FileUtils.cp("ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}", "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}")
end

CLOBBER.include("ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}")
