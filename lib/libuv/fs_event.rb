# frozen_string_literal: true

module Libuv
    class FSEvent < Handle


        define_callback function: :on_fs_event, params: [:pointer, :string, :int, :int]


        EVENTS = {1 => :rename, 2 => :change}.freeze


        def initialize(reactor, path)
            @reactor = reactor

            fs_event_ptr = ::Libuv::Ext.allocate_handle_fs_event
            error = check_result ::Libuv::Ext.fs_event_init(reactor.handle, fs_event_ptr, path, callback(:on_fs_event, fs_event_ptr.address), 0)

            super(fs_event_ptr, error)
        end


        private


        def on_fs_event(handle, filename, events, status)
            e = check_result(status)

            if e
                reject(e)
            else
                # notify of a change
                ::Fiber.new { defer.notify(filename, EVENTS[events]) }.resume
            end
        end
    end
end
