# Libuv FFI bindings for Ruby

[![Build Status](https://travis-ci.org/cotag/libuv.png?branch=master)](https://travis-ci.org/cotag/libuv)

[Libuv](https://github.com/joyent/libuv) is a cross platform asynchronous IO implementation that powers NodeJS. It supports sockets, both UDP and TCP, filesystem operations, TTY, Pipes and other asynchronous primitives like timer, check, prepare and idle.

The Libuv gem contains Libuv and a Ruby wrapper that implements [pipelined promises](http://en.wikipedia.org/wiki/Futures_and_promises#Promise_pipelining) for asynchronous flow control

## Usage

Create a new libuv loop or use a default one

```ruby
  require 'libuv'

  loop = Libuv::Loop.default
  # or
  # loop = Libuv::Loop.new

  loop.run do
    timer = loop.timer
    timer.start(50000, 0) do |error|
      p error if error
      puts "50 seconds passed"
      timer.close
      loop.stop
    end
  end
```

Find more examples in examples directory and check out the [yard documentation](http://rubydoc.info/gems/libuv/Libuv/Loop)


## Installation

```Shell
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
* Windows users will require a copy of Visual Studio 2010 or later. [Visual Studio Express](http://www.microsoft.com/visualstudio/eng/products/visual-studio-express-products) works fine.

or

if you have a compatible `libuv.(so | dylib | dll)` on the PATH already, setting the environmental variable `USE_GLOBAL_LIBUV` will prevent compiling the packaged version.


## What's supported

* TCP
* UDP
* TTY
* Pipe
* Timer
* Prepare
* Check
* Idle
* Async
* Filesystem (partially)
* File (partially)
* FSEvent
* Errors
* Work queue (thread pool)


