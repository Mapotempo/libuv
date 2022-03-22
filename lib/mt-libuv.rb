# frozen_string_literal: true

require 'forwardable'
require 'thread'
require 'ffi'

module MTLibuv
    DefaultThread = Thread.current

    require 'mt-libuv/ext/ext'     # The libuv ffi ext
    require 'mt-libuv/error'       # List of errors (matching those in uv.h)
    require 'mt-libuv/q'           # The promise library

    # -- The classes required for a reactor instance --
    require 'mt-libuv/mixins/assertions'  # Common code to check arguments
    require 'mt-libuv/mixins/accessors'   # Helper methods for accessing reactor functions
    require 'mt-libuv/mixins/resource'    # Common code to check for errors
    require 'mt-libuv/mixins/listener'    # Common callback code

    require 'mt-libuv/handle'      # Base class for most libuv functionality
    require 'mt-libuv/prepare'     # Called at the end of a reactor cycle
    require 'mt-libuv/async'       # Provide a threadsafe way to signal the event reactor
    require 'mt-libuv/timer'       # High resolution timer
    require 'mt-libuv/reactor'     # The libuv reactor or event reactor
    require 'mt-libuv/coroutines'  # Pause program execution until a result is returned
    require 'mt-libuv/fiber_pool'  # Fibers on jRuby and Rubinius are threads and expensive to re-create
    # --

    autoload :FsChecks, 'mt-libuv/mixins/fs_checks'   # Common code to check file system results
    autoload :Stream,   'mt-libuv/mixins/stream'      # For all libuv streams (tcp, pipes, tty)
    autoload :Net,      'mt-libuv/mixins/net'         # Common functions for tcp and udp

    autoload :Filesystem, 'mt-libuv/filesystem'  # Async directory manipulation
    autoload :FSEvent,    'mt-libuv/fs_event'    # Notifies of changes to files and folders as they occur
    autoload :Signal,     'mt-libuv/signal'      # Used to handle OS signals
    autoload :Spawn,      'mt-libuv/spawn'       # Executes a child process
    autoload :Check,      'mt-libuv/check'       # Called before processing events on the reactor
    autoload :File,       'mt-libuv/file'        # Async file reading and writing
    autoload :Idle,       'mt-libuv/idle'        # Called when there are no events to process
    autoload :Work,       'mt-libuv/work'        # Provide work to be completed on another thread (thread pool)
    autoload :UDP,        'mt-libuv/udp'         # Communicate over UDP
    autoload :Dns,        'mt-libuv/dns'         # Async DNS lookup

    # Streams
    autoload :Pipe, 'mt-libuv/pipe'        # Communicate over Pipes
    autoload :TCP,  'mt-libuv/tcp'         # Communicate over TCP
    autoload :TTY,  'mt-libuv/tty'         # Terminal output


    # Returns the number of CPU cores on the host platform
    # 
    # @return [Integer, nil] representing the number of CPU cores or nil if failed
    def self.cpu_count
        cpu_info = FFI::MemoryPointer.new(:pointer)
        cpu_count = FFI::MemoryPointer.new(:int)
        if ::MTLibuv::Ext.cpu_info(cpu_info, cpu_count) >= 0
            count = cpu_count.read_int
            ::MTLibuv::Ext.free_cpu_info(cpu_info.read_pointer, count)
            return count
        else
            return nil
        end
    end

    # Include all the accessors at this level
    extend Accessors
end


class Object
    private
    
    def reactor
        if block_given?
            MTLibuv.reactor { |thread| yield(thread) }
        else
            MTLibuv.reactor
        end
    end
end
