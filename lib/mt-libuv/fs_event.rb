# frozen_string_literal: true

module MTLibuv
    class FSEvent < Handle


        define_callback function: :on_fs_event, params: [:pointer, :string, :int, :int]


        EVENTS = {1 => :rename, 2 => :change}.freeze


        def initialize(reactor, path)
            @reactor = reactor

            fs_event_ptr = ::MTLibuv::Ext.allocate_handle_fs_event
            error = check_result ::MTLibuv::Ext.fs_event_init(reactor.handle, fs_event_ptr, path, callback(:on_fs_event, fs_event_ptr.address), 0)

            super(fs_event_ptr, error)
        end


        private


        def on_fs_event(handle, filename, events, status)
            e = check_result(status)

            if e
                reject(e)
            else
                # notify of a change
                @reactor.exec { defer.notify(filename, EVENTS[events]) }
            end
        end
    end
end
