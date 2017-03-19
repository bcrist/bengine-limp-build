local fs = require('be.fs')

include 'build/vc_win/rules'
include 'build/vc_win/cl'
include 'build/vc_win/rc'
include 'build/vc_win/lib'
include 'build/vc_win/link'
include 'build/vc_win/icon'
include 'build/vc_win/manifest'
include 'build/vc_win/init'

local hooks = { }

local guids = { }
local guid_configurations = { }

make_rule 'configure' {
   command = 'limp -f ' .. fs.ancestor_relative(file_path, root_dir),
   description = 'configure',
   generator = 'true'
}

function hooks.init ()
   make_target {
      rule = rule 'configure',
      outputs = { 'configure!' }
   }
end

function hooks.preprocess_begin ()
   configure_init_begin()
end

function hooks.preprocess_group (configured)
   configure_init_group(configured)
end

function hooks.preprocess_project (configured)
   configure_init_project(configured)

   local ext = ''
   if configured.is_app then
      ext = '.exe'
   elseif configured.is_lib then
      ext = '.lib'
   elseif configured.is_dyn_lib then
      ext = '.dll'
   elseif configured.is_ext_lib then
      ext = '.lib'
   end

   local rel_dir = configured.output_dir
   local abs_dir = configured.output_dir_abs
   local rel_build_dir, abs_build_dir = build_dir()
   local rel_stage_dir, abs_stage_dir = stage_dir()
   local base = configured.output_base

   configured.output_filename = base .. ext
   configured.pdb_filename = base .. '.pdb'

   configured.output_path = fs.compose_path(rel_dir, configured.output_filename)
   configured.output_path_abs = fs.compose_path(abs_dir, configured.output_filename)

   if configured.is_app then
      configured.stage_path = fs.compose_path(rel_stage_dir, configured.output_filename)
      configured.stage_path_abs = fs.compose_path(abs_stage_dir, configured.output_filename)
   end

   configured.pdb_path = fs.compose_path(rel_dir, configured.pdb_filename)
   configured.pdb_path_abs = fs.compose_path(abs_dir, configured.pdb_filename)

   configured.build_pdb_path = fs.compose_path(rel_build_dir, configured.pdb_filename)
   configured.build_pdb_path_abs = fs.compose_path(abs_build_dir, configured.pdb_filename)

   configured.cl_flags = get_cl_flags_var(configured)

   local defines = serialize_defines(configured.define)
   local includes = serialize_includes(configured.include)
   if defines and #defines > 0 and includes and #includes > 0 then
      configured.cl_extra = defines .. ' ' .. includes
   else
      if defines and #defines > 0 then
         configured.cl_extra = defines
      elseif includes and #includes > 0 then
         configured.cl_extra = includes
      end
   end

   local search_paths = { configured.path, root_dir }
   configured.vcxproj_path = expand_path(configured.name .. '.vcxproj', search_paths)
   if configured.vcxproj_path then
      local vcxproj = fs.get_file_contents(fs.compose_path(root_dir, configured.vcxproj_path))
      configured.vcxproj_guid = vcxproj:match '<ProjectGuid>{([%x%-]+)}</ProjectGuid>'
      configured.vcxproj_has_debug = (vcxproj:match '<ProjectConfiguration Include="debug%|x64">') ~= nil
   end
end

function hooks.preprocess_end ()
   configure_init_end()
   configure_clean()
end

function hooks.process (configured)
   if configured.disabled then
      return
   end

   if configured.vcxproj_guid then
      if not guid_configurations[configured.vcxproj_guid] then
         guids[#guids + 1] = configured.vcxproj_guid
         guid_configurations[configured.vcxproj_guid] = { }
      end
      append_sequence({ configured }, guid_configurations[configured.vcxproj_guid])
   end

   if not configured.is_ext then
      make_limp_targets(configured)
      find_limp_targets(configured)
   end
   make_custom_targets(configured)
   local obj_paths = make_cl_targets(configured)

   if configured.is_lib or configured.is_ext_lib then
      make_lib_target(configured, obj_paths) { }
      return configured.output_path
   end

   if configured.is_app then
      make_link_target(configured, obj_paths) { }
      make_cp_target(configured.stage_path, configured.output_path) { }
      return configured.stage_path
   end

   be.log.warning('Skipping unsupported project type for ' .. configured.name)
end

function hooks.postprocess_begin ()
   make_meta_pdb_target()

   if #guids > 0 then
      local projects = { }
      for i = 1, #guids do
         local linked_guids = { }
         local project = {
            guid = guids[i],
            linked_guids = { }
         }
         
         local configurations = guid_configurations[project.guid]
         for i = 1, #configurations do
            local configuration = configurations[i]
            project.name = project.name or configuration.name
            project.vcxproj_path = project.vcxproj_path or configuration.vcxproj_path
            project.has_debug = project.has_debug or configuration.vcxproj_has_debug
            project.group_type = project.group_type or configuration.group.type
            project.suffix = project.suffix or configuration.suffix

            if not configuration.is_lib and #configuration.linked_configurations > 0 then
               for i = 1, #configuration.linked_configurations do
                  local linked_config = configuration.linked_configurations[i]
                  if linked_config.vcxproj_guid then
                     if not linked_guids[linked_config.vcxproj_guid] then
                        linked_guids[linked_config.vcxproj_guid] = true
                        project.linked_guids[#project.linked_guids + 1] = linked_config.vcxproj_guid
                     end
                  end
               end
            end
         end

         projects[#projects + 1] = project
      end

      local sln_path = fs.compose_path(root_dir, 'msvc.sln')
      local sln_contents = fs.exists(sln_path) and fs.get_file_contents(sln_path)
      local new_sln_contents = template('msvc_sln', { projects = projects })

      if sln_contents ~= new_sln_contents then
         fs.put_file_contents(sln_path, new_sln_contents)
      end
   end
end

return hooks
