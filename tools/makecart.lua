local parts={
  {name="lua",text=true},
  {name="gfx",text=false,width=64,size=8192},
  {name="gff",text=false,width=128,size=256},
  {name="map",text=false,width=128,size=4096},
  {name="sfx",text=false,width=84,size=5376},
  {name="music",text=true,width=64}
}

local function cart_new()
  local cart = {parts={}}
  cart.header="pico-8 cartridge // http://www.pico-8.com\nversion 8\n"
  for i,desc in ipairs(parts) do
    local part = desc.name
    cart.parts[i] = part
    if desc.text then
      cart[part] = ""
    else
      local block = {width=desc.width}
      for i=1,desc.size do
        block[i] = 0
      end
      cart[part] = block
    end
    local block = cart[part]
    if part == "sfx" then
      for i=1,64 do
        block[(i-1)*84+2] = i==1 and 1 or 16
      end
    elseif part == "music" then
      for i=1,64 do
        block = block.."00 41424344\n"
      end
      cart[part] = block
    end
  end
  return cart
end

local function cart_set_part(cart,part,filename)
  local desc = parts[part]
  if desc.text then
    local file,err = io.open(filename,"r")
    if not file then error(err) end
    cart[part] = file:read("*a")
    file:close()
  else
    local file,err = io.open(filename,"rb")
    if not file then error(err) end
    local block = cart[part]
    local i=1
    for c in file:lines(1) do
      block[i] = string.byte(c)
      i=i+1
    end
    file:close()
  end
end

local function cart_set_bin(cart,part,filename)
end

local function cart_write(cart,filename)
  local file,err
  if filename then
    file,err = io.open(filename,"w")
    if not file then error(err) end
  else
    file = io.output()
  end
  file:write(cart.header)
  for _,part in ipairs(cart.parts) do
    file:write("__"..part.."__\n")
    local block = cart[part]
    if type(block) == "string" then
      file:write(block)
    else
      local width = block.width
      for i=1,#block/width do
        for j=1,width do
          local s = string.format("%02x",block[(i-1)*width+j])
          file:write(s:sub(2,2)..s:sub(1,1))
        end
        file:write("\n")
      end
    end
  end
  if filename then
    file:close()
  end
end


for i,desc in ipairs(parts) do
  parts[desc.name] = desc
end


local function usage()
  print("usage: "..arg[0].." [-<sub> filename]... dest.p8")
  os.exit(false)
end

local a = 1
local filename = nil

local cart = cart_new()

while arg[a] do
  local v = arg[a]
  if v:sub(1,1) == "-" then
    local part = v:sub(2)
    local desc = parts[part]
    if not desc then error("invalid part name: `"..part.."'") end
    cart_set_part(cart,part,arg[a+1])
    a = a + 1
  else
    if not filename then
      filename = v
    else
      usage()
    end
  end
  a = a + 1
end

cart_write(cart,filename)
