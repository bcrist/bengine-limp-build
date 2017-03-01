local fs = require('be.fs')

local limp_files = { }
local limp_targets = { }

local function limp_target (limp_file, input_paths)
   if limp_files[limp_file] then
      return
   end
   limp_files[limp_file] = true

   return {
      outputs = { limp_file },
      implicit_inputs = input_paths
   }
end

local function configure_limp_target (t, configured, search_paths)
   if type(t) == 'table' then
      if not t.file then
         fatal('LIMP file not specified!', nil, { t = be.util.sprint_r(t) })
      end
      
      local path = expand_path(t.file, search_paths)
      local inputs = expand_pathspec(t.inputs or { }, search_paths, configured)

      if not path then
         fatal('LIMP file not found!', nil, { t = be.util.sprint_r(t) })
      end

      return limp_target(path, inputs)
   else
      local path = expand_path(t, search_paths)
      return limp_target(path)
   end
end

function build_scripts.env.limp (t)
   return function (configured)
      configured.limp = append_sequence({ t }, configured.limp)
   end
end

local function make_limp_target (t)
   if t then
      t.rule = rule 'limp'
      make_target(t)

      local limp_file = t.outputs[1]
      local u = {
         rule = rule 'limpin',
         inputs = { limp_file },
         outputs = { limp_file .. '!'}
      }
      make_target(u)

      append_sequence(u.outputs, limp_targets)
   end
end

function make_limp_targets (configured)
   if configured.limp then
      for i = 1, #configured.limp do
         make_limp_target(configure_limp_target(configured.limp[i], configured, { configured.path, root_dir }))
      end
   end
end

local searched_include_paths = { include = true } -- just symlinks to actual include dirs here

function find_limp_targets (configured)
   for i = 1, #configured.include do
      local include_path = configured.include[i]
      if not searched_include_paths[include_path] then
         searched_include_paths[include_path] = true
         local file_paths = expand_pathspec({'*.hpp', '*.inl' }, include_path, configured, 'rf')
         for j = 1, #file_paths do
            local file_path = file_paths[j]
            local path = fs.compose_path(root_dir, file_path)
            if fs.exists(path) then
               if fs.get_file_contents(path):match('/%*!!') then
                  make_limp_target(limp_target(file_path))
               end
            end
         end
      end
   end

   for i = 1, #configured.src do
      local src_set = configured.src[i]
      for j = 1, #src_set do
         local src_path = src_set[j]
         local path = fs.compose_path(root_dir, src_path)
         if fs.exists(path) then
            if fs.get_file_contents(path):match('/%*!!') then
               make_limp_target(limp_target(src_path))
            end
         end
      end
   end
end

function make_meta_limp_target (t)
   t = t or {}
   t.inputs = limp_targets
   make_phony_target('limp!')(t)
end
