require 'forwardable'
require 'ffi'

module Libuv
    require 'libuv/ext/ext'     # The libuv ffi ext
    require 'libuv/q'           # The promise library

    autoload :Assertions, 'libuv/assertions'    # Common code to check arguments
    autoload :Resource, 'libuv/resource'        # Common code to check for errors
    autoload :Listener, 'libuv/listener'        # Common callback code

    autoload :Error, 'libuv/error'              # List of errors (matching those in uv.h)
    autoload :Net, 'libuv/net'                  # Common functions for tcp and udp

    autoload :Handle, 'libuv/handle'            # Libuv handle base class
    
    autoload :Loop, 'libuv/loop'                # The libuv reactor or event loop
    autoload :Timer, 'libuv/timer'              # High resolution timer
    autoload :Check, 'libuv/check'              # Called before processing events on the loop
    autoload :Prepare, 'libuv/prepare'          # Called at the end of a loop cycle
    autoload :Idle, 'libuv/idle'                # Called when there are no events to process
    autoload :Async, 'libuv/async'              # Provide a threadsafe way to signal the event loop (uses promises)
    autoload :SimpleAsync, 'libuv/simple_async' # Same as above using a simple callback
    autoload :Work, 'libuv/work'                # Provide work to be completed on another thread (thread pool)

    # Streams
    autoload :Stream, 'libuv/stream'
    autoload :TCP, 'libuv/tcp'                  # Communicate over TCP
    autoload :Pipe, 'libuv/pipe'                # Communicate over Pipes
    autoload :TTY, 'libuv/tty'                  # Terminal output

    autoload :UDP, 'libuv/udp'                  # Communicate over UDP
    autoload :FSEvent, 'libuv/fs_event'         # Notifies of changes to files and folders as they occur
end
