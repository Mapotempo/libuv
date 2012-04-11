require 'uv'

def on_read(client, nread, buf)
  if nread == -1
    ptr = UV.last_error(@loop)
    p [UV.err_name(ptr), UV.strerror(ptr)]
  else
    puts UV.buf_base(buf).read_string(nread)
  end
  UV.free(UV.buf_base(buf))
  UV.close(client, proc {|client| exit})
end

def on_alloc(handle, suggested_size)
  UV.buf_init(UV.malloc(suggested_size), suggested_size)
end

def on_connect(server, status)
  client = FFI::AutoPointer.new(UV.malloc(UV.handle_size(:uv_tcp)), UV.method(:free))
  UV.tcp_init(@loop, client)

  UV.accept(server, client)
  UV.read_start(client, method(:on_alloc), method(:on_read))
end

def main
  @loop = UV.default_loop

  server = FFI::AutoPointer.new(UV.malloc(UV.handle_size(:uv_tcp)), UV.method(:free))
  UV.tcp_init(@loop, server)

  UV.tcp_bind(server, UV.ip4_addr('0.0.0.0', 10000))
  UV.listen(server, 128, method(:on_connect))

  UV.run(@loop)
  UV.loop_delete(@loop)
end

main