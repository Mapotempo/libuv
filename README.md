# Libuv FFI bindings for Ruby

[![Build Status](https://travis-ci.org/cotag/libuv.svg?branch=master)](https://travis-ci.org/cotag/libuv)

[Libuv](https://github.com/libuv/libuv) is a cross platform asynchronous IO implementation that powers NodeJS. It supports sockets, both UDP and TCP, filesystem watch, TTY, Pipes and other asynchronous primitives like timer, check, prepare and idle.

The Libuv gem contains Libuv and a Ruby wrapper that implements [pipelined promises](http://en.wikipedia.org/wiki/Futures_and_promises#Promise_pipelining) for asynchronous flow control and [coroutines](http://en.wikipedia.org/wiki/Coroutine) / [futures](https://en.wikipedia.org/wiki/Futures_and_promises) for untangling evented code

## Usage

Libuv supports multiple reactors that can run on different threads.

For convenience the thread local or default reactor can be accessed via the `reactor` method
You can pass a block to be executed on the reactor and the reactor will run until there is nothing left to do.

```ruby
  require 'mt-libuv'

  reactor do |reactor|
    reactor.timer {
      puts "5 seconds passed"
    }.start(5000)
  end

  puts "reactor stopped. No more IO to process"
```

Promises are used to simplify code flow.

```ruby
  require 'mt-libuv'

  reactor do |reactor|
    reactor.tcp { |data, socket|
      puts "received: #{data}"
      socket.close
    }
    .connect('127.0.0.1', 3000) { |socket|
      socket.start_read
            .write("GET / HTTP/1.1\r\n\r\n")
    }
    .catch { |error|
      puts "error: #{error}"
    }
    .finally {
      puts "socket closed"
    }
  end
```

Continuations are used if callbacks are not defined

```ruby
  require 'mt-libuv'

  reactor do |reactor|
    begin
      reactor.tcp { |data, socket|
        puts "received: #{data}"
        socket.close
      }
      .connect('127.0.0.1', 3000)
      .start_read
      .write("GET / HTTP/1.1\r\n\r\n")
    rescue => error
      puts "error: #{error}"
    end
  end
```

Any promise can be converted into a continuation

```ruby
  require 'mt-libuv'

  reactor do |reactor|
    # Perform work on the thread pool with promises
    reactor.work {
      10 * 2
    }.then { |result|
      puts "result using a promise #{result}"
    }

    # Use the coroutine helper to obtain the result without a callback
    result = reactor.work {
      10 * 3
    }.value
    puts "no additional callbacks here #{result}"
  end
```


Check out the [yard documentation](http://rubydoc.info/gems/libuv/Libuv/Reactor)


## Installation

```shell
  gem install libuv
```

or

```shell
  git clone https://github.com/cotag/libuv.git
  cd libuv
  bundle install
  rake compile
```

### Prerequisites

* The installation on BSD/Linux requires [python 2.x](http://www.python.org/getit/) to be installed and available on the PATH
* setting the environmental variable `USE_GLOBAL_LIBUV` will prevent compiling the packaged version.
  * if you have a compatible `libuv.(so | dylib | dll)` on the PATH already

On Windows the GEM ships with a pre-compiled binary. If you would like to build yourself:

- A copy of Visual Studio 2017. [Visual Studio Build Tools](https://www.visualstudio.com/downloads/#build-tools-for-visual-studio-2017) works fine.
  - Windows 10 SDK
  - C++/CLI Support
  - C++ tools for CMake
- A copy of [OpenSSL](http://slproweb.com/products/Win32OpenSSL.html) x64 - ~30MB installs
  - ruby 2.4+ x64 with MSYS2 is preferred
- Add the env var `set GYP_MSVS_VERSION=2017`
- If using jRuby then [GCC](http://win-builds.org/stable/) is also required
  - Setup the paths as described on the gcc page
  - Add required environmental variable `set LIBRARY_PATH=X:\win-builds-64\lib;X:\win-builds-64\x86_64-w64-mingw32\lib`
- `rake compile`



## Features

* TCP (with TLS support)
* UDP
* TTY
* Pipes
* Timer
* Prepare
* Check
* Idle
* Signals
* Async callbacks
* Async DNS Resolution
* Filesystem Events
* Filesystem manipulation
* File manipulation
* Errors (with a catch-all fallback for anything unhandled on the event reactor)
* Work queue (thread pool)
* Coroutines / futures (makes use of Fibers)

### Server Name Indication

You can host a TLS enabled server with multiple hostnames using SNI.

```ruby
server = reactor.tcp
server.bind('0.0.0.0', 3000, **{
    hosts: [{
        private_key: '/blah.key',
        cert_chain: '/blah.crt',
        host_name: 'somehost.com',
    },
    {
        private_key: '/blah2.key',
        cert_chain: '/blah2.crt',
        host_name: 'somehost2.com'
    },
    {
        private_key: '/blah3.key',
        cert_chain: '/blah3.crt',
        host_name: 'somehost3.com'
    }]
}) do |client|
    client.start_tls
    client.start_read
end

# at some point later
server.add_host(private_key: '/blah4.key', cert_chain: '/blah4.crt', host_name: 'somehost4.com')
server.remove_host('somehost2.com')
```

You don't have to specify any hosts at binding time.


## Protocols and 3rd party plugins

* [HTTP](https://github.com/cotag/uv-rays - with SNI [server name indication] support)
  * [Faraday plugin](https://github.com/cotag/uv-rays/blob/master/lib/faraday/adapter/libuv.rb)
  * [HTTPI plugin](https://github.com/cotag/uv-rays/blob/master/lib/httpi/adapter/libuv.rb)
  * [HTTP2](https://github.com/igrigorik/http-2)
  * [SOAP](https://github.com/savonrb/savon) (using HTTPI plugin)
* [SNMP](https://github.com/acaprojects/ruby-engine/blob/master/lib/protocols/snmp.rb)
