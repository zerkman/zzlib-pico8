
-- zzlib - zlib decompression in Lua - PICO-8 edition

-- Copyright (c) 2016 Francois Galea <fgalea at free.fr>
-- This program is free software. It comes without any warranty, to
-- the extent permitted by applicable law. You can redistribute it
-- and/or modify it under the terms of the Do What The Fuck You Want
-- To Public License, Version 2, as published by Sam Hocevar. See
-- the COPYING file or http://www.wtfpl.net/ for more details.


local zzlib = {}

local reverse = {}

local function bitstream_init(addr)
  local bs = {
    pos = addr,   -- char buffer pointer
    b = 0,        -- bit buffer
    n = 0,        -- number of bits in buffer
  }
  -- get rid of n first bits
  function bs:flushb(n)
    self.n = self.n - n
    self.b = shr(self.b,n)
  end
  -- get a number of n bits from stream
  function bs:getb(n)
    while self.n < n do
      self.b += shr(peek(self.pos),16-self.n)
      self.pos += 1
      self.n += 8
    end
    local ret = shl(band(self.b,shl(0x.0001,n)-0x.0001),16)
    self.n = self.n - n
    self.b = shr(self.b,n)
    return ret
  end
  -- get next variable-size of maximum size=n element from stream, according to Huffman table
  function bs:getv(hufftable,n)
    while self.n < n do
      self.b += shr(peek(self.pos),16-self.n)
      self.pos += 1
      self.n += 8
    end
    local h = reverse[shl(band(self.b,0x.00ff),16)]
    local l = reverse[shl(band(self.b,0x.ff),8)]
    local v = band(shr(shl(h,8)+l,16-n),2^n-1)
    local e = hufftable[v]
    local len = band(e,15)
    local ret = flr(shr(e,4))
    self.n = self.n - len
    self.b = shr(self.b,len)
    return ret
  end
  return bs
end

local bl_count = {}
local next_code = {}

local function hufftable_create(table,depths,nvalues)
  local nbits = 1
  for i=0,16 do
    bl_count[i] = 0
  end
  for i=1,nvalues do
    local d = depths[i]
    if d > nbits then
      nbits = d
    end
    bl_count[d] = bl_count[d] + 1
  end
  local code = 0
  bl_count[0] = 0
  for i=1,nbits do
    code = (code + bl_count[i-1]) * 2
    next_code[i] = code
  end
  for i=1,nvalues do
    local len = depths[i] or 0
    if len > 0 then
      local e = (i-1)*16 + len
      local code = next_code[len]
      next_code[len] = next_code[len] + 1
      local code0 = code * 2^(nbits-len)
      local code1 = (code+1) * 2^(nbits-len)
      if code1 > 2^nbits then
        error("code error")
      end
      for j=code0,code1-1 do
        table[j] = e
      end
    end
  end
  return nbits
end

local littable = {}
local disttable = {}

local function inflate_block_loop(out,bs,nlit,ndist)
  local lit
  repeat
    lit = bs:getv(littable,nlit)
    if lit < 256 then
      poke(out,lit)
      out += 1
    elseif lit > 256 then
      local nbits = 0
      local size = 3
      local dist = 1
      if lit < 265 then
        size = size + lit - 257
      elseif lit < 285 then
        nbits = flr(shr(lit-261,2))
        size = size + shl(band(lit-261,3)+4,nbits)
      else
        size = 258
      end
      if nbits > 0 then
        size = size + bs:getb(nbits)
      end
      local v = bs:getv(disttable,ndist)
      if v < 4 then
        dist = dist + v
      else
        nbits = flr(shr(v-2,1))
        dist = dist + shl(band(v,1)+2,nbits)
        dist = dist + bs:getb(nbits)
      end
      while size > 0 do
        local v = peek(out-dist)
        poke(out,v)
        out += 1
        size = size - 1
      end
    end
  until lit == 256
  return out
end

local order = { 17, 18, 19, 1, 9, 8, 10, 7, 11, 6, 12, 5, 13, 4, 14, 3, 15, 2, 16 }
local depths = {}
local lengthtable = {}
local litdepths = {}
local distdepths = {}

local function inflate_block_dynamic(out,bs)
  local hlit = 257 + bs:getb(5)
  local hdist = 1 + bs:getb(5)
  local hclen = 4 + bs:getb(4)
  for i=1,hclen do
    local v = bs:getb(3)
    depths[order[i]] = v
  end
  for i=hclen+1,19 do
    depths[order[i]] = 0
  end
  local nlen = hufftable_create(lengthtable,depths,19)
  local i=1
  while i<=hlit+hdist do
    local v = bs:getv(lengthtable,nlen)
    if v < 16 then
      depths[i] = v
      i = i + 1
    elseif v < 19 then
      local nbt = {2,3,7}
      local nb = nbt[v-15]
      local c = 0
      local n = 3 + bs:getb(nb)
      if v == 16 then
        c = depths[i-1]
      elseif v == 18 then
        n = n + 8
      end
      for j=1,n do
        depths[i] = c
        i = i + 1
      end
    else
      error("wrong entry in depth table for literal/length alphabet: "..v);
    end
  end
  for i=1,hlit do litdepths[i] = depths[i] end
  local nlit = hufftable_create(littable,litdepths,hlit)
  for i=1,hdist do distdepths[i] = depths[i+hlit] end
  local ndist = hufftable_create(disttable,distdepths,hdist)
  return inflate_block_loop(out,bs,nlit,ndist,littable,disttable)
end

local stcnt = { 144, 112, 24, 8 }
local stdpt = { 8, 9, 7, 8 }

local function inflate_block_static(out,bs)
  local k = 1
  for i=1,4 do
    local d = stdpt[i]
    for j=1,stcnt[i] do
      depths[k] = d
    end
  end
  local nlit = hufftable_create(littable,depths,288)
  for i=1,32 do
    depths[i] = 5
  end
  local ndist = hufftable_create(disttable,depths,32)
  return inflate_block_loop(out,bs,nlit,ndist,littable,disttable)
end

local function inflate_block_uncompressed(out,bs)
  bs:flushb(band(bs.n,7))
  local len = bs:getb(16)
  if bs.n > 0 then
    error("Unexpected.. should be zero remaining bits in buffer.")
  end
  local nlen = bs:getb(16)
  if bxor(len,nlen) ~= 65535 then
    error("LEN and NLEN don't match")
  end
  memcpy(out,bs.pos,len)
  out += len
  bs.pos += len
  return out
end

local function inflate_main(out,bs)
  local last,type
  bs.pos+=10
  if band(peek(bs.pos-7),8) ~= 0 then
    --print("ok")
    while peek(bs.pos) ~= 0 do
      bs.pos += 1
    end
    bs.pos += 1
  end
  repeat
    local block
    last = bs:getb(1)
    type = bs:getb(2)
    if type == 0 then
      out = inflate_block_uncompressed(out,bs)
    elseif type == 1 then
      out = inflate_block_static(out,bs)
    elseif type == 2 then
      out = inflate_block_dynamic(out,bs)
    else
      error("unsupported block type")
    end
  until last == 1
  bs:flushb(band(bs.n,7))
end

function zzlib.gunzip(outaddr,inaddr)
  inflate_main(outaddr,bitstream_init(inaddr))
end

-- init reverse array
for i=0,255 do
  local k=0
  for j=0,7 do
    if band(i,shl(1,j)) ~= 0 then
      k = k + shl(1,7-j)
    end
  end
  reverse[i] = k
end
