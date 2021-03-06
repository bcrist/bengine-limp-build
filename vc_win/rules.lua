
make_rule 'superninja' {
   command = '"$bin_dir\\wedo.exe" ninja -f $file $targets $extra',
   description = 'sudo ninja $targets',
   generator = 'true'
}
make_rule 'ninja' {
   command = 'ninja -f $file $targets $extra',
   description = 'ninja $targets',
   generator = 'true'
}

make_rule 'superninjatool' {
   command = '"$bin_dir\\wedo.exe" ninja -f $file -t $tool $extra',
   description = 'sudo ninja -t $tool'
}
make_rule 'ninjatool'{
   command = 'ninja -f $file -t $tool $extra',
   description = 'ninja -t $tool'
}

make_rule 'limp' {
   command = 'limp --depfile "$build_dir\\$out.d" -f $out',
   description = 'limp $out',
   depfile = '$build_dir\\$out.d',
   deps = 'gcc',
   generator = 'true',
   restat = 'true'
}

make_rule 'limpin' {
   command = 'limp -f $in',
   description = 'limp $in',
   generator = 'true'
}

make_rule 'superrun' {
   command = '"$bin_dir\\wedo.exe" $cmd $extra',
   description = 'sudo $cmd'
}
make_rule 'run' {
   command = '$cmd $extra',
   description = '$cmd'
}

make_rule 'supershell' {
   command = '"$bin_dir\\wedo.exe" cmd /s /c "$cmd $extra"',
   description = 'sudo $cmd'
}
make_rule 'shell' {
   command = 'cmd /s /c "$cmd $extra"',
   description = '$cmd'
}

make_rule 'mkdir' {
   command = 'cmd /s /c "if not exist "$out" md "$out""',
   description = 'mkdir $out',
   generator = 'true'
}

make_rule 'putfile' {
   command = 'cmd /s /c "(echo:$contents)>"$out""',
   description = 'putfile $out'
}

make_rule 'cp' {
   command = 'cmd /s /c "copy /Y /B "$in" "$out" /B >nul"',
   description = 'cp $out'
}
make_rule 'mv' {
   command = 'cmd /s /c "move /Y "$in" "$out" >nul"',
   description = 'mv $out'
}

make_rule 'rmdir' {
   command = 'cmd /s /c "if exist "$path" rd /Q /S "$path""',
   description = 'rm $path'
}
make_rule 'rmfile' {
   command = 'cmd /s /c "if exist "$path" del /F /Q "$path""',
   description = 'rm $path'
}
make_rule 'rmfiles' {
   command = 'cmd /s /c "del /F /Q $paths >nul 2>&1 || echo. >nul"',
   description = 'rm $paths'
}

make_rule 'lndir' {
   command = 'cmd /s /c "if not exist "$out" mklink /J "$out" "$in" >nul"',
   description = 'ln $out',
   generator = 'true',
   restat = 'true'
}
make_rule 'lnfile' {
   command = 'cmd /s /c "if not exist "$out" mklink /H "$out" "$in" >nul"',
   description = 'ln $out',
   generator = 'true',
   restat = 'true'
}

function putfile_escape (contents)
   local escaped = contents:gsub('[%%&\\<>^|"]', '^%0')
   return escaped:gsub('\r?\n', '&echo:$%0')
end
