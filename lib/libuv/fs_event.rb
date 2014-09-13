module Libuv
    class FSEvent < Handle


        EVENTS = {1 => :rename, 2 => :change}.freeze


        def initialize(loop, path)
            @loop = loop

            fs_event_ptr = ::Libuv::Ext.allocate_handle_fs_event
            error = check_result ::Libuv::Ext.fs_event_init(loop.handle, fs_event_ptr, path, callback(:on_fs_event), 0)

            super(fs_event_ptr, error)
        end


        private


        def on_fs_event(handle, filename, events, status)
            e = check_result(status)

            if e
                reject(e)
            else
                defer.notify(filename, EVENTS[events])   # notify of a change
            end
        end
    end
end
