local fs = require('be.fs')

function build_scripts.env.icon (path)
   if type(path) ~= 'string' then
      fatal 'Icon path must be a string!'
   end
   return function (configured)
      if configured.icon then
         fatal('Icon already specified', configured)
      end
      configured.icon = path
   end
end

function build_scripts.env.include (spec)
   return function (configured)
      configured.include = append_sequence({ spec }, configured.include)
   end
end

function build_scripts.env.pch (filename)
   if type(filename) ~= 'string' then
      fatal 'PCH filename must be a string!'
   end
   return function (paths, named_properties)
      named_properties.pch = filename
      return paths
   end
end

function build_scripts.env.pch_src (path)
   if type(path) ~= 'string' then
      fatal 'PCH source path must be a string!'
   end
   return function (paths, named_properties, search_path, configured_project, globtype)
      named_properties.pch_src = expand_path(path, search_path)
      local new_paths = { }
      local n = 0
      for i = 1, #paths do
         local path = paths[i]
         if not fs.equivalent(path, named_properties.pch_src) then
            n = n + 1
            new_paths[n] = path
         end
      end
      return new_paths
   end
end

function build_scripts.env.src (pathspec)
   return function (configured)
      configured.src = append_sequence({ pathspec }, configured.src)
   end
end

function build_scripts.env.limp_src(pathspec)
   return function (configured)
      configured.limp_src = append_sequence({ pathspec }, configured.limp_src)
   end
end

function build_scripts.env.link (spec)
   return function (configured)
      configured.link = append_sequence(spec, configured.link, true)
   end
end

function build_scripts.env.link_project (spec)
   return function (configured)
      configured.link_project = append_sequence(spec, configured.link_project, true)
   end
end

function build_scripts.env.define (spec)
   return function (configured)
      if type(spec) == 'string' then
         configured.define[spec] = false
      else
         for k, v in pairs(spec) do
            if type(k) == 'number' then
               configured.define[v] = false
            else
               configured.define[k] = v
            end
         end
      end
   end
end

function build_scripts.env.export_define (spec)
   return function (configured)
      if type(spec) == 'string' then
         configured.export_define[spec] = false
      else
         for k, v in pairs(spec) do
            if type(k) == 'number' then
               configured.export_define[v] = false
            else
               configured.export_define[k] = v
            end
         end
      end
   end
end

function build_scripts.env.test_type (test_type)
   if type(path) ~= 'string' then
      fatal 'Icon path must be a string!'
   end
   return function (configured)
      if configured.test_type then
         fatal('Test type already specified', configured)
      end
      configured.test_type = test_type
   end
end

function build_scripts.env.gui (configured)
   configured.gui = true
end

function build_scripts.env.console (configured)
   configured.console = true
end

function build_scripts.env.rtti (configured)
   configured.rtti = true
end

function build_scripts.env.force_c (configured)
   configured.force_c = true
end

function build_scripts.env.force_cxx (configured)
   configured.force_cxx = true
end

function build_scripts.env.require_admin (configured)
   configured.require_admin = true
end

function build_scripts.env.disabled (configured)
   configured.disabled = true
end

function build_scripts.env.enabled (configured)
   configured.disabled = false
end

function build_scripts.env.path (path)
   return function (configured)
      if configured.configured_group then
         configured.path = expand_path(path, { configured.configured_group.path, root_dir })
      else
         configured.path = path
      end
   end
end
