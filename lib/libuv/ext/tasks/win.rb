file "ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}" do
    target_arch = 'ia32'
    target_arch = 'x64' if FFI::Platform.x64?

    Dir.chdir("ext/libuv") do |path|
        system 'vcbuild.bat', 'shared', 'release', target_arch
    end
end

file "ext/libuv.#{FFI::Platform::LIBSUFFIX}" => "ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}" do
    FileUtils.mv("ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}", "ext/libuv.#{FFI::Platform::LIBSUFFIX}")
end

CLOBBER.include("ext/libuv/Release/libuv.#{FFI::Platform::LIBSUFFIX}")
