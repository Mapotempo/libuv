require 'forwardable'
require 'thread'
require 'ffi'

module Libuv
    DefaultThread = Thread.current

    require 'libuv/ext/ext'     # The libuv ffi ext
    require 'libuv/error'       # List of errors (matching those in uv.h)
    require 'libuv/q'           # The promise library

    # -- The classes required for a reactor instance --
    require 'libuv/mixins/assertions'  # Common code to check arguments
    require 'libuv/mixins/accessors'   # Helper methods for accessing reactor functions
    require 'libuv/mixins/resource'    # Common code to check for errors
    require 'libuv/mixins/listener'    # Common callback code

    require 'libuv/handle'      # Base class for most libuv functionality
    require 'libuv/prepare'     # Called at the end of a reactor cycle
    require 'libuv/async'       # Provide a threadsafe way to signal the event reactor
    require 'libuv/timer'       # High resolution timer
    require 'libuv/reactor'        # The libuv reactor or event reactor
    require 'libuv/coroutines'
    # --

    autoload :FsChecks, 'libuv/mixins/fs_checks'   # Common code to check file system results
    autoload :Stream,   'libuv/mixins/stream'      # For all libuv streams (tcp, pipes, tty)
    autoload :Net,      'libuv/mixins/net'         # Common functions for tcp and udp

    autoload :Filesystem, 'libuv/filesystem'  # Async directory manipulation
    autoload :FSEvent,    'libuv/fs_event'    # Notifies of changes to files and folders as they occur
    autoload :Signal,     'libuv/signal'      # Used to handle OS signals
    autoload :Check,      'libuv/check'       # Called before processing events on the reactor
    autoload :File,       'libuv/file'        # Async file reading and writing
    autoload :Idle,       'libuv/idle'        # Called when there are no events to process
    autoload :Work,       'libuv/work'        # Provide work to be completed on another thread (thread pool)
    autoload :UDP,        'libuv/udp'         # Communicate over UDP
    autoload :Dns,        'libuv/dns'         # Async DNS lookup

    # Streams
    autoload :Pipe, 'libuv/pipe'        # Communicate over Pipes
    autoload :TCP,  'libuv/tcp'         # Communicate over TCP
    autoload :TTY,  'libuv/tty'         # Terminal output


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

    # Include all the accessors at this level
    extend Accessors

    # Run the default reactor
    at_exit do
        reactor = Reactor.default
        reactor.run if reactor.run_count == 0
    end
end


class Object
    private

    def reactor(&blk)
        Libuv.reactor &blk
    end
end
