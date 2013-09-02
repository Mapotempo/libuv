require 'forwardable'
require 'ffi'

module Libuv
    require 'libuv/ext/ext'     # The libuv ffi ext
    require 'libuv/q'           # The promise library

    require 'libuv/assertions'  # Common code to check arguments
    require 'libuv/resource'    # Common code to check for errors
    require 'libuv/listener'    # Common callback code
    require 'libuv/error'       # List of errors (matching those in uv.h)

    require 'libuv/handle'      # Base class for most libuv functionality
    require 'libuv/timer'       # High resolution timer
    require 'libuv/async'       # Provide a threadsafe way to signal the event loop (uses promises)
    require 'libuv/simple_async'
    require 'libuv/loop'        # The libuv reactor or event loop

    require 'libuv/check'       # Called before processing events on the loop
    require 'libuv/prepare'     # Called at the end of a loop cycle
    require 'libuv/idle'        # Called when there are no events to process
    require 'libuv/signal'      # Used to handle OS signals
    require 'libuv/work'        # Provide work to be completed on another thread (thread pool)

    # Streams
    require 'libuv/net'         # Common functions for tcp and udp
    require 'libuv/stream'
    require 'libuv/tcp'         # Communicate over TCP
    require 'libuv/pipe'        # Communicate over Pipes
    require 'libuv/tty'         # Terminal output

    require 'libuv/udp'         # Communicate over UDP
    require 'libuv/fs_event'    # Notifies of changes to files and folders as they occur


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
