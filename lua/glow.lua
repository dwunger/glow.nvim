---@type integer win id
local win

---@type integer buffer id
local buf

---@type string tmp file path
local tmpfile

local job = {}

-- types
---@alias border 'shadow' | 'none' | 'double' | 'rounded' | 'solid' | 'single' | 'rounded'
---@alias style 'dark' | 'light' | 'notty' | 'pink' | 'ascii' | 'dracula'

---@class Glow
local glow = {}

---@class Config
---@field glow_path string glow executable path
---@field install_path string glow binary installation path
---@field border border floating window border style
---@field style style floating window style
---@field pager boolean display output in pager style
---@field width integer floating window width
---@field height integer floating window height
---@field background string? floating window background color
---@field word_wrap integer

-- default configurations
local config = {
  glow_path = vim.fn.exepath("glow"),
  install_path = vim.env.HOME .. "/.local/bin",
  border = "shadow",
  style = vim.o.background,
  pager = false,
  width = 100,
  height = 100,
  background = nil,
  word_wrap = nil,
}

-- default configs
glow.config = config

local function cleanup()
  if tmpfile ~= nil then
    vim.fn.delete(tmpfile)
  end
end

local function err(msg)
  vim.notify(msg, vim.log.levels.ERROR, { title = "glow" })
end

local function safe_close(h)
  if not h:is_closing() then
    h:close()
  end
end

local function stop_job()
  if job == nil then
    return
  end
  if not job.stdout == nil then
    job.stdout:read_stop()
    safe_close(job.stdout)
  end
  if not job.stderr == nil then
    job.stderr:read_stop()
    safe_close(job.stderr)
  end
  if not job.handle == nil then
    safe_close(job.handle)
  end
  job = nil
end

local function close_window()
  stop_job()
  cleanup()
  vim.api.nvim_win_close(win, true)
end

---@return string
local function tmp_file()
  local output = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
  if vim.tbl_isempty(output) then
    err("buffer is empty")
    return ""
  end
  local tmp = vim.fn.tempname() .. ".md"
  vim.fn.writefile(output, tmp)
  return tmp
end
-- @description Opens a floating window in Neovim to display content using the glow markdown renderer.
-- @param cmd_args table Command arguments for the glow command.
local function open_window(cmd_args)
  -- Calculate window dimensions based on the editor's current size and configured ratios.
  local width = vim.o.columns
  local height = vim.o.lines
  local height_ratio = glow.config.height_ratio or 0.7
  local width_ratio = glow.config.width_ratio or 0.7
  local win_height = math.ceil(height * height_ratio)
  local win_width = math.ceil(width * width_ratio)
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  -- Override window dimensions if specific sizes are configured.
  if glow.config.width and glow.config.width < win_width then
    win_width = glow.config.width
  end
  if glow.config.height and glow.config.height < win_height then
    win_height = glow.config.height
  end

  -- Configure word wrapping based on glow settings.
  if glow.config.word_wrap then
    table.insert(cmd_args, "-w")
    table.insert(cmd_args, tostring(glow.config.word_wrap))
  else
    -- Use the calculated window width for word wrapping if not explicitly configured.
    table.insert(cmd_args, "-w")
    table.insert(cmd_args, win_width)
  end

  -- Window options setup.
  local win_opts = {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    border = glow.config.border,
  }

  -- Create a buffer and a window for the preview.
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Highlight namespace and window options.
  local nsid = vim.api.nvim_create_namespace("glow")
  vim.api.nvim_win_set_hl_ns(win, nsid)
  vim.wo[win].winblend = 0 -- Make the window non-transparent.
  vim.bo[buf].bufhidden = "wipe" -- Buffer is wiped when window is closed.
  vim.bo[buf].filetype = "glowpreview" -- Set filetype for the buffer.

  -- Background color configuration.
  if glow.config.background then
    vim.api.nvim_set_hl(nsid, "NormalFloat", {bg = glow.config.background})
  end

  -- Key mappings for closing the window.
  local close_window = function()
    -- The close_window function body needs to be defined or referenced here.
  end
  local keymaps_opts = {silent = true, buffer = buf}
  vim.keymap.set("n", "q", close_window, keymaps_opts)
  vim.keymap.set("n", "<Esc>", close_window, keymaps_opts)

  -- Terminal setup for output.
  local chan = vim.api.nvim_open_term(buf, {})

  -- Function to handle process output.
  local function on_output(err, data)
    if err then
      -- Handle error.
    end
    if data then
      local lines = vim.split(data, "\n", true)
      for _, line in ipairs(lines) do
        vim.api.nvim_chan_send(chan, line .. "\r\n")
      end
    end
  end

  -- Process management for glow command.
  local cmd = table.remove(cmd_args, 1)
  local job = {
    stdout = vim.loop.new_pipe(false),
    stderr = vim.loop.new_pipe(false)
  }

  local function on_exit()
    stop_job()
    cleanup()
  end

  job.handle = vim.loop.spawn(cmd, {
    args = cmd_args,
    stdio = {nil, job.stdout, job.stderr},
  }, vim.schedule_wrap(on_exit))

  vim.loop.read_start(job.stdout, vim.schedule_wrap(on_output))
  vim.loop.read_start(job.stderr, vim.schedule_wrap(on_output))

  -- Enter insert mode automatically if configured.
  if glow.config.pager then
    vim.cmd("startinsert")
  end
end

---@return string
local function release_file_url()
  local os, arch
  local version = "1.5.1"

  -- check pre-existence of required programs
  if vim.fn.executable("curl") == 0 or vim.fn.executable("tar") == 0 then
    err("curl and/or tar are required")
    return ""
  end

  -- local raw_os = jit.os
  local raw_os = vim.loop.os_uname().sysname
  local raw_arch = jit.arch
  local os_patterns = {
    ["Windows"] = "Windows",
    ["Windows_NT"] = "Windows",
    ["Linux"] = "linux",
    ["Darwin"] = "Darwin",
    ["BSD"] = "freebsd",
  }

  local arch_patterns = {
    ["x86"] = "i386",
    ["x64"] = "x86_64",
    ["arm"] = "arm7",
    ["arm64"] = "arm64",
  }

  os = os_patterns[raw_os]
  arch = arch_patterns[raw_arch]

  if os == nil or arch == nil then
    err("os not supported or could not be parsed")
    return ""
  end

  -- create the url, filename based on os, arch, version
  local filename = "glow_" .. version .. "_" .. os .. "_" .. arch .. (os == "Windows" and ".zip" or ".tar.gz")
  return "https://github.com/charmbracelet/glow/releases/download/v" .. version .. "/" .. filename
end

---@return boolean
local function is_md_ft()
  local allowed_fts = { "markdown", "markdown.pandoc", "markdown.gfm", "wiki", "vimwiki", "telekasten" }
  if not vim.tbl_contains(allowed_fts, vim.bo.filetype) then
    return false
  end
  return true
end

---@return boolean
local function is_md_ext(ext)
  local allowed_exts = { "md", "markdown", "mkd", "mkdn", "mdwn", "mdown", "mdtxt", "mdtext", "rmd", "wiki" }
  if not vim.tbl_contains(allowed_exts, string.lower(ext)) then
    return false
  end
  return true
end

local function run(opts)
  local file
  local baseUrl = "https://raw.githubusercontent.com/dwunger/man-pages-md/main/"
  -- check if glow binary is valid even if filled in config
  if vim.fn.executable(glow.config.glow_path) == 0 then
    err(
      string.format(
        "could not execute glow binary in path=%s . make sure you have the right config",
        glow.config.glow_path
      )
    )
    return
  end

  local filename = opts.fargs[1]

  if filename ~= nil and filename ~= "" then
    -- check file
    file = opts.fargs[1]
    if not vim.fn.filereadable(file) then
      err("filereadable: error on reading file")
      return
    end

    local ext = vim.fn.fnamemodify(file, ":e")
    if not is_md_ext(ext) then

      -- err("is_md_ext: preview only works on markdown files")
      -- return
      file = baseUrl .. tostring(opts.fargs[1]) .. ".md"
    end
  else
    if not is_md_ft() then
      err("is_md_ft: preview only works on markdown files")
      return
    end

    file = tmp_file()
    if file == nil then
      err("tmp_file = nil: error on preview for current buffer")
      return
    end
    tmpfile = file
  end

  stop_job()

  local cmd_args = { glow.config.glow_path, "-s", glow.config.style }

  if glow.config.pager then
    table.insert(cmd_args, "-p")
  end

  table.insert(cmd_args, file)
  open_window(cmd_args)
end


local function install_glow(opts)
  local release_url = release_file_url()
  if release_url == "" then
    return
  end

  local install_path = glow.config.install_path
  local download_command = { "curl", "-sL", "-o", "glow.tar.gz", release_url }
  local extract_command = { "tar", "-zxf", "glow.tar.gz", "-C", install_path }
  local output_filename = "glow.tar.gz"
  ---@diagnostic disable-next-line: missing-parameter
  local binary_path = vim.fn.expand(table.concat({ install_path, "glow" }, "/"))

  -- check for existing files / folders
  if vim.fn.isdirectory(install_path) == 0 then
    vim.loop.fs_mkdir(glow.config.install_path, tonumber("777", 8))
  end

  ---@diagnostic disable-next-line: missing-parameter
  if vim.fn.filereadable(binary_path) == 1 then
    local success = vim.loop.fs_unlink(binary_path)
    if not success then
      err("glow binary could not be removed!")
      return
    end
  end

  -- download and install the glow binary
  local callbacks = {
    on_sterr = vim.schedule_wrap(function(_, data, _)
      local out = table.concat(data, "\n")
      err(out)
    end),
    on_exit = vim.schedule_wrap(function()
      vim.fn.system(extract_command)
      -- remove the archive after completion
      if vim.fn.filereadable(output_filename) == 1 then
        local success = vim.loop.fs_unlink(output_filename)
        if not success then
          err("existing archive could not be removed")
          return
        end
      end
      glow.config.glow_path = binary_path
      run(opts)
    end),
  }
  vim.fn.jobstart(download_command, callbacks)
end

---@return string
local function get_executable()
  if glow.config.glow_path ~= "" then
    return glow.config.glow_path
  end

  return vim.fn.exepath("glow")
end

local function create_autocmds()
  vim.api.nvim_create_user_command("Glow", function(opts)
    glow.execute(opts)
  end, { complete = "file", nargs = "?", bang = true })
end

---@param params Config? custom config
glow.setup = function(params)
  glow.config = vim.tbl_extend("force", {}, glow.config, params or {})
  create_autocmds()
end

glow.execute = function(opts)
  if vim.version().minor < 8 then
    vim.notify_once("glow.nvim: you must use neovim 0.8 or higher", vim.log.levels.ERROR)
    return
  end

  local current_win = vim.fn.win_getid()
  if current_win == win then
    if opts.bang then
      close_window()
    end
    -- do nothing
    return
  end

  if get_executable() == "" then
    install_glow(opts)
    return
  end

  run(opts)
end

return glow