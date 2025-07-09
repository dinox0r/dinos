### Context

This is the first entry for this blog, so "hello world" I guess?

This is just a dumpster to throw some random ideas and keep 
my sanity during the development of this side project. 

I doubt I will ever post this anywhere but who care anyway, at least I 
get to practice some typing.

Some backstory, because drama:

I bought the "Making games for the Atari 2600" book by Steven Hugg on 
December as a self Christmas present and decided to give it a go. The problem
is, I became a father on October last year so energy and free time is 
really scarse.

// TODO: add more drama

I made a few mistakes with this project so far. I had a clear idea in my mind 
of what I want but not enough time and haven't been able to properly 
focus. 

I've been reading a lot, LIKE a lot during the last couple of months. 
My goal is to make the Dino Chrome game because reasons.

// TODO: Explain why the dino chrome game is so important/cool to me

That's it. TODOs for everything in this first entry. Now onto the technical
bits.

## Technical bits

Ok, I managed to organize my thoughts and come up with a plan. I have 
a blank kernel now. With the proper initialization/timers for v-blank/overscan, etc. Pretty cool setup that I learned from different blog posts, websites, etc.

I figured, that to compensate for the massive lack of experience when it comes
to making Atari 2600 games, I will read a lot about it, trying to get all tricks
available instead of spending unsufferable amounts of time 
learning them the hard way (spending hours that I don't have debugging). 
I know I will have to spend time debugging anyway, that's unavoidable,
but I wanted to minimize that as much as possible,
because it's frustrating spending a whole day trying to figure out 
the mystery behind why HMOVE is not working when it turns out that you 
should strobe it 24 cycles after setting the fine offset.

Still, even a simple looking game like the Chrome dino presents a lot 
of problems, specially because I don't have the freedom of changing that
much without loosing fidelity. Man, making a port it's cool and challenging!

Ok, ok, enough ranting. Back to my technical part. The thing is, after a lot of
head scratching, I think I have a plan. I will split the screen to several
kernels (nothing new here, everyone does that), in the following manner:

```
------------------------------------------- score kernel setup
-------------------------------------------
                             01234  01234   score kernel
-------------------------------------------
------------------------------------------- clouds kernel setup
    ^^              ^^                      
  <___>           <___>                     clouds kernel
------------------------------------------- 
------------------------------------------- sky kernel setup

                                            sky kernel

------------------------------------------- cactus kernel setup
------------------------------------------- 
   DD           |
\=B           |_|_|                         cactus kernel
  LL            |
=========================================== floor kernel
```

Some details I still don't know how I'm going to implement are:
* How to draw the 2 5 digits scores. AFAIK is possible to draw the 6
digits score using the trick with vertical delay registers, but I still
don't know if is possible to use it twice in the same scanline.
* I'm planning to use playfield graphics for the clouds, scrolling horizontally
in a slow pace. I have no clue if it's possible to draw the dino on top when
jumping so for the time being I'm going to make that space sprite free.
* Should I use the 192 scanlines sprite trick for the dino? The one where
your sprite is stored as a table with 192 entries, where most of them are 
empty but with this you don't have to check if the current scanline Y
coordinate is within the position of the sprite on the screen (saving 
a lot of instructions per scanline).

And that's all the time I had, in this train ride at least. Man, time does 
fly, specially if you're just writing all these and not actually coding, but
I guess I needed to put my ideas in order to not waste any more time.

Next step is to start with the code to jump to the different sub-kernels. 
The idea is to use a table with 192 entries, each entry is a label to  
jump to at the beginning of the scanline.  Challenges ahead:

* Figuring out how to make DASM fill up the entries with the same label. So far 
I think I can do:
```asm
  org <ADDRESS>, label_score-kernel-setup
  org <ADDRESS> + num-lines for score-kernel-setup, label_score_kernel
  ...
```
I still don't know if you can just pass the label like this to DASM, if not 
I'll have to investigate the documentation of the assembler to find if 
such thing is possible.

I'm going to start by laying out the kernel subsections as labels in the code,
in each subsection I will just change the background colour (to differentiate 
them when testing) and assign names to them. If later on I need 
less/more sub-sections, it shouldn't be difficult to apply the change with 
the current structure I described.

Ha, I just realised my first oversight/mistake! Each sub-kernel needs 
to finish with a jump to another place where the housekeeping for the 
current scanline is done (decrement the y register, strobe WSYNC, 
strobe HMOVE, jump back to the beginning of the kernel, etc). The sub-kernels
will have to jump to this location or duplicate the scanline housekeeping
code. Probably I can make use of a MACRO and save each sub-kernel from doing
an extra jump. I already feel that I won't have many cycles to spare.
