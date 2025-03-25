-- modified https://github.com/rossy/mpv-open-file-dialog
-- To the extent possible under law, the author(s) have dedicated all copyright
-- and related and neighboring rights to this software to the public domain
-- worldwide. This software is distributed without any warranty. See
-- <https://creativecommons.org/publicdomain/zero/1.0/> for a copy of the CC0
-- Public Domain Dedication, which applies to this software.

utils = require 'mp.utils'

function Set (list)
  local set = {}
  for _, l in ipairs(list) do set[l] = true end
  return set
end

-- https://github.com/mpv-player/mpv/blob/b31c3d80ab0040cb02a54ee878cb2d95f6ed74e0/options/options.c#L1068
local subtitle_exts = Set { "ass", "idx", "lrc", "mks", "pgs", "rt", "sbv", "scc", "smi", "srt", "ssa", "sub", "sup", "utf", "utf-8", "utf8", "vtt"}

function open_file_dialog(action)
	local action = action or 'replace'
	local was_ontop = mp.get_property_native("ontop")
	if was_ontop then mp.set_property_native("ontop", false) end
	local res = utils.subprocess({
		args = {'powershell', '-NoProfile', '-Command', [[& {
			Trap {
				Write-Error -ErrorRecord $_
				Exit 1
			}
			Add-Type -AssemblyName PresentationFramework

			$u8 = [System.Text.Encoding]::UTF8
			$out = [Console]::OpenStandardOutput()

			$ofd = New-Object -TypeName Microsoft.Win32.OpenFileDialog
			$ofd.Multiselect = $true

			If ($ofd.ShowDialog() -eq $true) {
				ForEach ($filename in $ofd.FileNames) {
					$u8filename = $u8.GetBytes("$filename`n")
					$out.Write($u8filename, 0, $u8filename.Length)
				}
			}
		}]]},
		cancellable = false,
	})
	if was_ontop then mp.set_property_native("ontop", true) end
	if (res.status ~= 0) then return end

	local first_file = true
	for filename in string.gmatch(res.stdout, '[^\n]+') do
		ext = filename:match("^.+%.(.+)$")
		if subtitle_exts[ext] then
			mp.commandv('sub-add', filename)
		else
			mp.commandv('loadfile', filename, first_file and action or 'append')
		end
		first_file = false
	end
end

mp.register_script_message('open', open_file_dialog)
