# Raptor

Lighter, faster, smarter than REX. Raptor is the next evolutionary step in Metasploit's basic network IO functionality.




## FAQ

1. **What is Raptor?**  Raptor is the next generation of the core networking libraries used by Metasploit.  This includes the core Socket and Switchboard implementations as well as clients and servers for lots of protocols, both open source and proprietary.  It is intended as a general-purpose library for doing network exploitation, research, and reverse engineering, but you can also use it to power the server hosting your collection of cat GIFs.
2. **Should I use it?**   Sure!  Just remember that it's not 1.0 yet and won't be for awhile.  We are open-sourcing it now because the critical early stages have been completed and we want the Ruby community to be able to have a look and help us expand it.
3. **What are the next goals?** We want to continue building out client/server pairs for each of multiple protocols, starting with the SMB family (DCE/RPC, etc).  Goals on the horizon include a less client-centric replacement for Net::SSH as well.
4. **I know network programming and Ruby - how can I help?**  Pull requests are welcome! Implementations of client/server pairs must be fully spec'd (ideally from the protocol's RFC) and follow the One True Rule of Raptor: "*an implementation must follow the spec by default, but allow tinkering/abuse of the protocol at every level.*"  Abstractions should be for convenience, but not lock users out of dealing with lower-level constructs.
5. **When will Raptor be live as the networking layer in Metasploit Framework?** We hesitate to put a firm date on it, but we are working toward that goal as fast as possible.  There's lots of work to be done, and we hope you can help!

## Installation

### From source

    gem install bundler
    git clone git@github.com:rapid7/raptor.git
    bundle install
    
### From RubyGems
*submission to RubyGems anticipated mid-January 2014*    

## Immediate Goals
* ~~Implement improved Switchboard (in-memory router)~~
* ~~Implement improved Socket (built on Ruby's TCPSocket)~~
* ~~Create basic Comm classes (for multi-channel communication abstraction)~~
* * ~~local~~
* * ~~SOCKS~~
* ~~HTTP client and server functionality~~
* SMB client and server functionality
* (Implement all protocol libraries supported by REX) 


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
