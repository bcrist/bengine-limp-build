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

local project_guids = { }
local guid_configurations = { }

make_rule 'configure' {
   command = '"$bin_dir\\limp.exe" -f ' .. fs.ancestor_relative(file_path, root_dir),
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

   if configured.vcxproj_guid and not project_guids[configured.vcxproj_guid] then
      project_guids[configured.vcxproj_guid] = true
      guid_configurations[#guid_configurations + 1] = configured
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

   if #guid_configurations > 0 then
      fs.put_file_contents(fs.compose_path(root_dir, 'msvc.sln'), template('msvc_sln', { configurations = guid_configurations }))
   end
end

return hooks
