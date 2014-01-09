# Libuv FFI bindings for Ruby

[![Build Status](https://travis-ci.org/cotag/libuv.png?branch=master)](https://travis-ci.org/cotag/libuv)

[Libuv](https://github.com/joyent/libuv) is a cross platform asynchronous IO implementation that powers NodeJS. It supports sockets, both UDP and TCP, filesystem watch, TTY, Pipes and other asynchronous primitives like timer, check, prepare and idle.

The Libuv gem contains Libuv and a Ruby wrapper that implements [pipelined promises](http://en.wikipedia.org/wiki/Futures_and_promises#Promise_pipelining) for asynchronous flow control

## Usage

Create a new libuv loop or use a default one

```ruby
  require 'libuv'

  loop = Libuv::Loop.default
  # or
  # loop = Libuv::Loop.new

  loop.run do
    timer = loop.timer do
      puts "5 seconds passed"
      timer.close
      loop.stop
    end
    timer.catch do |error|
      puts "error with timer: #{error}"
    end
    timer.finally do
      puts "timer handle was closed"
    end
    timer.start(5000)
  end
```

Check out the [yard documentation](http://rubydoc.info/gems/libuv/Libuv/Loop)


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

* The installation requires __subversion__ to be installed on your system and available on the PATH
* setting the environmental variable `USE_GLOBAL_LIBUV` will prevent compiling the packaged version.
  * if you have a compatible `libuv.(so | dylib | dll)` on the PATH already

Windows users will additionally require:

- A copy of Visual Studio 2010 or later. [Visual Studio Express](http://www.microsoft.com/visualstudio/eng/products/visual-studio-express-products) works fine.
- A copy of [OpenSSL](http://slproweb.com/products/Win32OpenSSL.html) matching the installed ruby (x86 / x64)
  - with the environmental variable `OPENSSL_CONF` Set `OPENSSL_CONF=X:\path_to\OpenSSL\bin\openssl.cfg`
- If using jRuby then [GCC](http://win-builds.org/stable/) is also required
  - Setup the paths as described on the gcc page
  - Add required environmental variable `set LIBRARY_PATH=X:\win-builds-64\lib;X:\win-builds-64\x86_64-w64-mingw32\lib`



## Libuv features supported

* TCP (with TLS support)
* UDP
* TTY
* Pipe
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
* Errors
* Work queue (thread pool)
