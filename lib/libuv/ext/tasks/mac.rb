file 'ext/libuv/uv.xcodeproj' => 'ext/libuv/build/gyp' do
    target_arch = 'ia32'if FFI::Platform.ia32?
    target_arch = 'x64' if FFI::Platform.x64?

    abort "Don't know how to build on #{FFI::Platform::ARCH} (yet)" unless target_arch

    Dir.chdir("ext/libuv") do |path|
        system "./gyp_uv.py -f xcode -Dtarget_arch=#{target_arch} -Duv_library=shared_library -Dcomponent=shared_library"
    end
end

file "ext/libuv/build/Release/libuv.#{FFI::Platform::LIBSUFFIX}" => 'ext/libuv/uv.xcodeproj' do
    Dir.chdir("ext/libuv") do |path|
        system 'xcodebuild -project uv.xcodeproj -configuration Release -target libuv'
    end
end

file "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}" => "ext/libuv/build/Release/libuv.#{FFI::Platform::LIBSUFFIX}" do
    FileUtils.mkdir('ext/libuv/lib') unless File.directory?('ext/libuv/lib')

    user_lib = "#{ENV['HOME']}/lib"
    FileUtils.mkdir(user_lib) unless File.directory?(user_lib)

    # Useful for building other libraries that wish to use Libuv
    FileUtils.cp("ext/libuv/build/Release/libuv.#{FFI::Platform::LIBSUFFIX}", "ext/libuv/lib/libuv.#{FFI::Platform::LIBSUFFIX}")

    # Primrary load location - falls back to above if not available
    FileUtils.cp("ext/libuv/build/Release/libuv.#{FFI::Platform::LIBSUFFIX}", "#{user_lib}/libuv.#{FFI::Platform::LIBSUFFIX}")
end

CLEAN.include('ext/libuv/uv.xcodeproj')
CLOBBER.include("ext/libuv/build/Release/libuv.#{FFI::Platform::LIBSUFFIX}")
