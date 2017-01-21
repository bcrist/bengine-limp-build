local fs = require('be.fs')

function serialize_define (symbol, value)
   if not value or value == '' then
      return '/D' .. symbol
   elseif string.find(value, '%s') then
      return '/D"' .. symbol .. '=' .. value .. '"'
   else
      return '/D' .. symbol .. '=' .. value
   end
end

function serialize_defines (defines)
   local out, n = { }, 0
   for k, v in pairs(defines) do
      n = n + 1
      out[n] = serialize_define(k, v)
   end
   table.sort(out)
   return table.concat(out, ' ')
end

function serialize_include (include)
   return '/I"' .. include .. '"'
end

function serialize_includes (includes)
   local out = { }
   for i = 1, #includes do
      out[i] = serialize_include(includes[i])
   end
   return table.concat(out, ' ')
end

include 'build/vc_win/cl_config'

local cl_flags = { }
local function ignore () end

function get_cl_flags_var (configured)
   local add_name_suffix, name = make_append_fn('_', nil, { 'cl_flags' })
   configure_cl_flags(configured, ignore, ignore, ignore, add_name_suffix)

   name = table.concat(name)
   if not cl_flags[name] then
      local add_option, options = make_append_fn()
      local disable_warning, disabled_warnings = make_append_fn(function (n) return '/wd' .. n end)
      local defines = { }
      local function add_define (define, value)
         if value == nil then
            defines[define] = false
         else
            defines[define] = tostring(value)
         end
      end

      configure_cl_flags(configured, add_define, disable_warning, add_option, ignore)
      table.sort(disabled_warnings)
      add_option(table.concat(disabled_warnings, ' '))
      add_option(serialize_defines(defines))
      cl_flags[name] = true
      set_global(name, table.concat(options, ' '), cl_flags_global_group)
   end

   return '$' .. name
end

function make_cl_target (obj_path, src_path, flags)
   if not obj_path then fatal 'cl .obj file not specified!' end
   if not src_path then fatal 'cl source file not specified!' end
   if not flags then fatal 'cl flags not specified!' end
   return function (t)
      t.rule = rule 'cl'
      t.inputs = { src_path }
      t.order_only_inputs = { 'init!' }
      t.outputs = { obj_path }
      t.vars = {{ name = 'flags', value = flags }}

      if t.pdb then
         t.vars[#t.vars + 1] = { name = 'pdb', value = t.pdb }
      end

      if t.extra then
         t.vars[#t.vars + 1] = { name = 'extra', value = t.extra }
      end

      return make_target(t)
   end
end

function get_obj_path (configured, src_path)
   local relative_path = fs.ancestor_relative(fs.compose_path(root_dir, src_path), configured.path)
   build_dir();
   return fs.compose_path('$build_dir', configured.configuration, configured.name, fs.replace_extension(relative_path, '.obj'))
end

function make_cl_targets (configured)
   local add_obj, obj_paths = make_append_fn()

   local pch_paths = { }
   local n_pch_paths = 0

   for i = 1, #configured.src do
      local src_set = configured.src[i]
      local cl_extra = configured.cl_extra

      local implicit_pch
      if src_set.pch_src then
         local pch_path = pch_paths[src_set.pch_src]
         local add_pch_src_cl_targets = false

         if not pch_path then
            local pch_filename = configured.output_base
            if n_pch_paths > 0 then
               pch_filename = pch_filename .. n_pch_paths
            end

            pch_path = fs.compose_path(build_dir(), pch_filename .. '.pch')
            pch_paths[src_set.pch_src] = pch_path
            add_pch_src_cl_targets = true
            n_pch_paths = n_pch_paths + 1
         end
         
         cl_extra = cl_extra .. ' /Fp"' .. pch_path .. '"'

         if add_pch_src_cl_targets then
            local obj_path = get_obj_path(configured, src_set.pch_src)
            make_cl_target(obj_path, src_set.pch_src, configured.cl_flags) {
               pdb = configured.build_pdb_path,
               extra = cl_extra .. ' /Yc"' .. src_set.pch .. '"'
            }
            add_obj(obj_path)
            make_phony_target(pch_path) {
               inputs = { obj_path } -- pch was actually created at the same time as obj
            }
         end

         cl_extra = cl_extra .. ' /Yu"' .. src_set.pch .. '"'
         implicit_pch = { pch_path }
      end

      for j = 1, #src_set do
         local src_path = src_set[j]
         local obj_path = get_obj_path(configured, src_path)

         make_cl_target(obj_path, src_path, configured.cl_flags) {
            pdb = configured.build_pdb_path,
            extra = cl_extra,
            implicit_inputs = implicit_pch
         }
         add_obj(obj_path)
      end
   end

   return obj_paths
end
