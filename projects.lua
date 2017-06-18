local fs = require('be.fs')

local projects = {
   all = { }
}

local function project (project_type, name_or_suffix)
   local function parse (t)
      if type(t) ~= 'table' then
         fatal('Expected table!', nil, { t = be.util.sprint_r(t) })
      end

      return function (configured_group)
         local name, suffix
         if type(name_or_suffix) ~= 'string' then
            name = configured_group.group.name
         elseif name_or_suffix:sub(1, 1) == '-' then
            name = configured_group.group.name .. name_or_suffix
            suffix = name_or_suffix:sub(2)
         else
            name = name_or_suffix
         end

         local project = projects.all[name]
         if not project then
            project = {
               name = name,
               suffix = suffix,
               type = project_type,
               group = configured_group.group,
               fns = { },
               configurations = { }
            }
            projects.all[name] = project
            projects[#projects + 1] = project
            configured_group.group.projects[#configured_group.group.projects + 1] = project

            for k, v in pairs(t) do
               if type(k) == 'number' then
                  project.fns[#project.fns + 1] = v
               elseif type(k) == 'string' and not protected_config_properties[k] then
                  project[k] = v
               else
                  fatal('The ' .. k .. ' property cannot be set directly!', project)
               end
            end
         end

         if project.type ~= project_type then
            fatal('"' .. name .. '" is a ' .. project.type .. ', not a ' .. project_type .. '!', project)
         end

         if project.group ~= configured_group.group then
            fatal('A project named "' .. name .. '" already exists in the "' .. project.group.name .. '" ' .. project.group.type, project)
         end
      end
   end

   if type(name_or_suffix) == 'table' then
      return parse(name_or_suffix)
   else
      return parse
   end
end

function build_scripts.env.app (name_or_suffix)
   return project('app', name_or_suffix)
end

function build_scripts.env.lib (name_or_suffix)
   return project('lib', name_or_suffix)
end

function build_scripts.env.dyn_lib (name_or_suffix)
   return project('dyn_lib', name_or_suffix)
end

function build_scripts.env.ext_lib (name_or_suffix)
   return project('ext_lib', name_or_suffix)
end

function configure_project (project, toolchain, configuration, configured_group)
   local configured = deep_copy(configured_group)
   configured.projects = nil
   deep_copy(project, configured)
   project.configurations[configuration] = configured
   configured.project = project
   configured.toolchain = toolchain
   configured.configuration = configuration
   configured.configurations = project.configurations
   configured.group = configured_group.group
   configured.configured_group = configured_group

   for f = 1, #project.fns do
      project.fns[f](configured)
   end

   configured.path = fs.canonical(configured.path)

   if not configured.output_base then
      configured.output_base = configured.name .. configured.configuration_suffix
   end

   configured.is_lib = configured.type == 'lib'
   configured.is_app = configured.type == 'app'
   configured.is_dyn_lib = configured.type == 'dyn_lib'
   configured.is_ext = configured.type == 'ext_lib'
   configured.is_ext_lib = configured.type == 'ext_lib'

   if configured.is_ext_lib then
      configured.output_dir, configured.output_dir_abs = ext_lib_dir()
   else
      configured.output_dir, configured.output_dir_abs = out_dir()
   end

   if configured.is_lib or configured.is_dyn_lib then
      configured_group.has_include_headers = true
   end

   if not configured.is_ext then
      configured.define.BE_TARGET = configured.name
      configured.define.BE_TARGET_BASE = configured_group.name
   end

   if configured.test_type == nil then
      if configured.suffix == 'test' or configured.suffix == 'perf' then
         configured.test_type = configured.suffix
      end
   end

   if configured.console == nil and not configured.gui then
      configured.console = true
   end

   local search_paths = { configured.path, root_dir }

   configured.include = expand_pathspec(configured.include or default_include_paths(configured), search_paths, configured, 'd?')

   be.log.verbose('Expanding src patterns for ' .. configured.output_base, { ['Search Paths'] = be.util.sprint_r(search_paths) })

   if not configured.src then
      local original = default_source_patterns(configured)
      local expanded = expand_pathspec(original, search_paths, configured)
      be.log.verbose('Expanded src pattern', { Pattern = be.util.sprint_r(original), Results = be.util.sprint_r(expanded) })
      configured.src = { expanded }
   else
      for i = 1, #configured.src do
         local original = configured.src[i]
         local expanded = expand_pathspec(original, search_paths, configured)
         be.log.verbose('Expanded src pattern', { Pattern = be.util.sprint_r(original), Results = be.util.sprint_r(expanded) })
         if expanded.pch_src and not expanded.pch then
            expanded.pch = 'pch.hpp'
         end
         configured.src[i] = expanded
      end
   end

   if not configured.limp_src then
      configured.limp_src = { }
   else
      for i = 1, #configured.limp_src do
         local original = configured.limp_src[i]
         local expanded = expand_pathspec(original, search_paths, configured)
         be.log.verbose('Expanded limp_src pattern', { Pattern = be.util.sprint_r(original), Results = be.util.sprint_r(expanded) })
         configured.limp_src[i] = expanded
      end
   end

   configured.link = interpolate_sequence(configured.link or { }, configured)
   configured.link_internal = interpolate_sequence(configured.link_internal or { }, configured)
   configured.link_project = interpolate_sequence(configured.link_project or { }, configured)
   configured.linked_configurations = { }

   if configured.icon then
      configured.icon = expand_path(configured.icon, search_paths)
      if not configured.icon then
         fatal('Could not locate icon for project "' .. configured.name .. '"', configured)
      end
   end

   for k, v in pairs(configured) do
      if not protected_config_properties[k] and type(v) == 'string' then
         configured[k] = interpolate_string(v, configured)
      end
   end

   return configured
end

local function link_project (configured_project, project_name_to_link)
   local configured = configured_project
   local project_to_link = projects.all[project_name_to_link]
   if not project_to_link then
      fatal(configured.name .. ' can\'t link to project "' .. project_name_to_link .. '"; project does not exist!', configured)
   end

   if project_to_link.is_app then
      fatal(configured.name .. ' can\'t link to project "' .. project_name_to_link .. '"; project is not a library!', configured)
   end
   
   local config_to_link = project_to_link.configurations[configured.configuration]
   local link_spec = fs.compose_path(config_to_link.output_dir, config_to_link.name .. config_to_link.configuration_suffix)
   
   append_sequence({ config_to_link }, configured.linked_configurations, true)
   append_sequence(config_to_link.link, configured.link, true)
   append_sequence({ link_spec }, configured.link_internal, true)

   for k, v in pairs(config_to_link.export_define) do
      if configured.define[k] == nil then
         configured.define[k] = v
      end
   end

   for i = 1, #config_to_link.link_project do
      local name = config_to_link.link_project[i]
      link_project(configured_project, name)
   end
end

function finalize_project_configuration (configured_project, groups)
   local configured = configured_project

   local direct_dependencies = append_sequence(configured.link_project)

   for i = 1, #configured.link_project do
      local name = configured.link_project[i]
      link_project(configured_project, name)
   end

   local dependencies = { }
   local defines = { }
   for i = 1, #configured.link_internal do
      local link_spec = configured.link_internal[i]
      dependencies[#dependencies + 1] = fs.path_filename(link_spec)
   end
   for k, v in pairs(configured.define) do
      if k ~= 'BE_TARGET' and k ~= 'BE_TARGET_BASE' then
         if v then
            defines[#defines + 1] = k .. '=' .. v
         else
            defines[#defines + 1] = k
         end
      end
   end

   if #dependencies > 0 then
      dependencies = table.concat(dependencies, '  ')
   else
      dependencies = nil
   end

   if #direct_dependencies > 0 then
      direct_dependencies = table.concat(direct_dependencies, '  ')
   else
      direct_dependencies = nil
   end

   if #defines > 0 then
      defines = table.concat(defines, '  ')
   else
      defines = nil
   end

   if dependencies or defines then
      be.log.verbose('Dependencies for ' .. configured.output_base, { Direct = direct_dependencies, All = dependencies, Defines = defines, })
   end
end

return projects
