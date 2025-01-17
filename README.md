<h1 align="center">
  <img src="https://i.postimg.cc/Y9Z030zC/glow-nvim.jpg" />
</h1>

<div align="center">
  <p>
    <strong>Preview markdown code directly in your neovim terminal</strong><br/>
    <small>Powered by charm's <a href="https://github.com/charmbracelet/glow">glow</a></small>
  </p>
  <img src="https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua" />
  <img src="https://img.shields.io/github/actions/workflow/status/dwunger/glow.nvim/default.yml?style=for-the-badge" />
  
</div>

https://user-images.githubusercontent.com/178641/215353259-eb8688fb-5600-4b95-89a2-0f286e3b6441.mp4


## Prerequisites

- Neovim 0.8+

## Installing

[![LuaRocks](https://img.shields.io/luarocks/v/ellisonleao/glow.nvim?logo=lua&color=purple)](https://luarocks.org/modules/ellisonleao/glow.nvim)

- [vim-plug](https://github.com/junegunn/vim-plug)

```
Plug 'dwunger/glow.nvim'
lua << EOF
require('glow').setup()
EOF
```

- [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {"dwunger/glow.nvim", config = function() require("glow").setup() end}
```

- [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{"dwunger/glow.nvim", config = true, cmd = "Glow"}
```

## Setup

The script comes with the following defaults:

```lua
{
  glow_path = "", -- will be filled automatically with your glow bin in $PATH, if any
  install_path = "~/.local/bin", -- default path for installing glow binary
  border = "shadow", -- floating window border config
  style = "auto|dark|light|notty|pink|ascii|dracula", -- choose a default theme
  pager = false,
  width = 80,
  height = 100,
  width_ratio = 0.7, -- maximum width of the Glow window compared to the nvim window size (overrides `width`)
  height_ratio = 0.7,
  word_wrap = 80, -- Set word wrap length independent of window size
}
```

To override the custom configuration, call:

```lua
require('glow').setup({
  -- your override config
})
```

Example:

```lua
require('glow').setup({
  style = "dark",
  width = 120,
})
```

## Usage

### Preview file

```
:Glow [path-to-md-file]
```

### Fetch and preview a man page 
```
:Glow printf
```

### Preview current buffer

```
:Glow
```

### Close window

```
:Glow!
```

You can also close the floating window using `q` or `<Esc>` keys
