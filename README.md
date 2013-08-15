# uv.rb - libuv FFI bindings for Ruby

[Libuv](https://github.com/cotag/libuv) is a cross platform asynchronous IO implementation that powers NodeJS. It supports sockets, both UDP and TCP, filesystem operations, TTY, Pipes and other asynchronous primitives like timer, check, prepare and idle.

Libuv.rb is FFI Ruby bindings for libuv.

## Usage

Create a uv loop or use a default one

```ruby
  require 'uv'

  loop = UV::Loop.default
  # or
  # loop = UV::Loop.new

  timer = loop.timer
  timer.start(50000, 0) do |error|
    p error if error
    puts "50 seconds passed"
    timer.close
  end

  loop.run
```

Find more examples in examples directory

## Installation

```Shell
  gem install uvrb
```

or

```shell
  git clone ...
  cd ...
  bundle install
```

### Prerequisites

* The installation requires subversion to be installed on your system and available on the PATH
* Windows users will require a copy of Visual Studio 2010 or later installed. {Express}[http://www.microsoft.com/visualstudio/eng/products/visual-studio-express-products] works fine.

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
