# Libuv FFI bindings for Ruby

[![Build Status](https://travis-ci.org/cotag/libuv.svg?branch=master)](https://travis-ci.org/cotag/libuv)

[Libuv](https://github.com/libuv/libuv) is a cross platform asynchronous IO implementation that powers NodeJS. It supports sockets, both UDP and TCP, filesystem watch, TTY, Pipes and other asynchronous primitives like timer, check, prepare and idle.

The Libuv gem contains Libuv and a Ruby wrapper that implements [pipelined promises](http://en.wikipedia.org/wiki/Futures_and_promises#Promise_pipelining) for asynchronous flow control and [coroutines](http://en.wikipedia.org/wiki/Coroutine) for untangling evented code

## Usage

Libuv supports multiple reactors that can run on different threads.

For convenience the thread local or default reactor can be accessed via the `reactor` method
You can pass a block to be executed on the reactor and the reactor will run until there is nothing left to do.

```ruby
  require 'libuv'

  reactor do |reactor|
    reactor.timer {
      puts "5 seconds passed"
    }.start(5000)
  end

  puts "reactor stopped. No more IO to process"
```

Promises are used to simplify code flow.

```ruby
  require 'libuv'

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
  require 'libuv'

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
  require 'libuv'

  reactor do |reactor|
    # Perform work on the thread pool with promises
    reactor.work {
      10 * 2
    }.then { |result|
      puts "result using a promise #{result}"
    }

    # Use the coroutine helper to obtain the result without a callback
    result = co reactor.work {
      10 * 3
    }
    puts "no callbacks here #{result}"
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

* The installation also requires [python 2.x](http://www.python.org/getit/) to be installed and available on the PATH
* setting the environmental variable `USE_GLOBAL_LIBUV` will prevent compiling the packaged version.
  * if you have a compatible `libuv.(so | dylib | dll)` on the PATH already

Windows users will additionally require:

- A copy of Visual Studio 2010 or later. [Visual Studio Express](http://www.microsoft.com/visualstudio/eng/products/visual-studio-express-products) works fine.
- A copy of [OpenSSL](http://slproweb.com/products/Win32OpenSSL.html) matching the installed ruby (x86 / x64)
- If using jRuby then [GCC](http://win-builds.org/stable/) is also required
  - Setup the paths as described on the gcc page
  - Add required environmental variable `set LIBRARY_PATH=X:\win-builds-64\lib;X:\win-builds-64\x86_64-w64-mingw32\lib`



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
* Coroutines (makes use of Fibers)
