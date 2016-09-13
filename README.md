# zzlib-pico8

This is a PICO-8–compatible Lua implementation of a depacker for the zlib
DEFLATE(RFC1951)/GZIP(RFC1952) file format.

## Usage

zzlib basically allows to depack compressed data stored inside a PICO-8
cartridge file. Just embed your gzipped file(s) into one data section
of the cartridge, along with the zzlib source code, and you can depack
your data onto the video memory or general purpose memory.

Depacking a file is as easy as calling a function, giving the destination
and source addresses as arguments:

    -- zzlib source code included above
    ...
    -- unpack data from the beginning of the gfx section to video memory
    zzlib.gunzip(0x6000,0x0)

The code above is used in the example in the `example` directory.

## Tools

For the moment, a unique tool is provided in the `tools` directory.

* `makecart.lua` generates a cart file with the specified
section contents. See the example usage of that tool in the
build script in the `examples` directory.



## External links and references

* [Original zzlib in standard Lua](https://github.com/zerkman/zzlib)
