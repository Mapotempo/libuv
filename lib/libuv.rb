require 'forwardable'
require 'ffi'

module Libuv
    require 'libuv/ext/ext'     # The libuv ffi ext
    require 'libuv/error'       # List of errors (matching those in uv.h)
    require 'libuv/q'           # The promise library

    require 'libuv/mixins/assertions'  # Common code to check arguments
    require 'libuv/mixins/fs_checks'   # Common code to check file system results
    require 'libuv/mixins/resource'    # Common code to check for errors
    require 'libuv/mixins/listener'    # Common callback code
    require 'libuv/mixins/stream'      # For all libuv streams (tcp, pipes, tty)
    require 'libuv/mixins/net'         # Common functions for tcp and udp

    # -- The classes required for a loop instance --
    require 'libuv/handle'      # Base class for most libuv functionality
    require 'libuv/async'       # Provide a threadsafe way to signal the event loop
    require 'libuv/timer'       # High resolution timer
    require 'libuv/loop'        # The libuv reactor or event loop
    # --

    require 'libuv/filesystem'  # Async directory manipulation
    require 'libuv/fs_event'    # Notifies of changes to files and folders as they occur
    require 'libuv/prepare'     # Called at the end of a loop cycle
    require 'libuv/signal'      # Used to handle OS signals
    require 'libuv/check'       # Called before processing events on the loop
    require 'libuv/file'        # Async file reading and writing
    require 'libuv/idle'        # Called when there are no events to process
    require 'libuv/work'        # Provide work to be completed on another thread (thread pool)
    require 'libuv/udp'         # Communicate over UDP

    # Streams
    require 'libuv/pipe'        # Communicate over Pipes
    require 'libuv/tcp'         # Communicate over TCP
    require 'libuv/tty'         # Terminal output


    # Returns the number of CPU cores on the host platform
    # 
    # @return [Fixnum, nil] representing the number of CPU cores or nil if failed
    def self.cpu_count
        cpu_info = FFI::MemoryPointer.new(:pointer)
        cpu_count = FFI::MemoryPointer.new(:int)
        if ::Libuv::Ext.cpu_info(cpu_info, cpu_count) >= 0
            count = cpu_count.read_int
            ::Libuv::Ext.free_cpu_info(cpu_info.read_pointer, count)
            return count
        else
            return nil
        end
    end
end
