local engineTextures = {
	-- atlases
	"$units",
	"$units1",
	"$units2",

	-- cubemaps
	"$specular",
	"$reflection",
	"$map_reflection",
	"$sky_reflection",

	-- specials
	"$shadow",
	"$heightmap",

	-- SMF-maps
	"$grass",
	"$detail",
	"$minimap",
	"$shading",
	"$normals",
	-- SSMF-maps
	"$ssmf_normals",
	"$ssmf_specular",
	"$ssmf_splat_distr",
	"$ssmf_splat_detail",
	"$ssmf_splat_normals:0",
	"$ssmf_splat_normals:1",
    "$ssmf_splat_normals:2",
    "$ssmf_splat_normals:3",
	"$ssmf_sky_refl",
	"$ssmf_emission",
	"$ssmf_parallax",


	"$info",
	"$info_losmap",
	"$info_mtlmap",
	"$info_hgtmap",
	"$info_blkmap",

	"$extra",
	"$extra_losmap",
	"$extra_mtlmap",
	"$extra_hgtmap",
	"$extra_blkmap",

	"$map_gb_nt",
	"$map_gb_dt",
	"$map_gb_st",
	"$map_gb_et",
	"$map_gb_mt",
	"$map_gb_zt",

	"$map_gbuffer_normtex",
	"$map_gbuffer_difftex",
	"$map_gbuffer_spectex",
	"$map_gbuffer_emittex",
	"$map_gbuffer_misctex",
	"$map_gbuffer_zvaltex",

	"$mdl_gb_nt",
	"$mdl_gb_dt",
	"$mdl_gb_st",
	"$mdl_gb_et",
	"$mdl_gb_mt",
	"$mdl_gb_zt",

	"$model_gbuffer_normtex",
	"$model_gbuffer_difftex",
	"$model_gbuffer_spectex",
	"$model_gbuffer_emittex",
	"$model_gbuffer_misctex",
	"$model_gbuffer_zvaltex",

	"$font"     ,
	"$smallfont",
	"$fontsmall",
}

local GL_LUMINANCE32F_ARB = 0x8818

commands = {
	{
		command = "texture",
		description = i18n("texture_desc", {default="Displays various OpenGL textures"}),
		cheat = false,
		suggestions = function(cmd, cmdParts)
			local suggestions = {}
			local param = cmdParts[2]

			for _, engineTexture in pairs(engineTextures) do
				if param == nil or param == "" or engineTexture:starts(param) then
					table.insert(suggestions, {
						command = "/texture " .. engineTexture,
						text = engineTexture,
						description = value
					})
				end
			end
			return suggestions
		end,
		exec = function(command, cmdParts)
			if #cmdParts < 3 then
				return
			end
			delayGL = function()
				local succ, err = pcall(function()
					Spring.Echo(command)
					local texture = cmdParts[2]
					local outputFile = cmdParts[3]

					local texInfo = gl.TextureInfo(texture)
					if texInfo == nil or texInfo.xsize == -1 then
						return
					end

					local format
					local useGrayscale16bit = false
					if texture == "$heightmap" then
						format = GL_LUMINANCE32F_ARB
						if Platform.osFamily ~= "Windows" or cmdParts[4] == '16bit' then
							useGrayscale16bit = true
						end
					end
					local fboTex = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
						format = format,
						border = false,
						min_filter = GL.LINEAR,
						mag_filter = GL.LINEAR,
						wrap_s = GL.CLAMP_TO_EDGE,
						wrap_t = GL.CLAMP_TO_EDGE,
						fbo = true,
					})

					gl.Texture(texture)
					gl.RenderToTexture(fboTex,
					function()
						gl.TexRect(-1,-1, 1, 1)
					end)
					gl.Texture(false)

					gl.RenderToTexture(fboTex, gl.SaveImage, 0, 0, texInfo.xsize, texInfo.ysize, outputFile, {grayscale16bit = useGrayscale16bit})
					gl.DeleteTexture(fboTex)
					Spring.Log("Chonsole", LOG.NOTICE, 'Exported texture: ' ..
							   tostring(cmdParts[2]).. ' to file: ' .. tostring(cmdParts[3]))
				end)
				if not succ then
					Spring.Log("Chonsole", LOG.ERROR, 'Failed to export texture: ' ..
							   tostring(cmdParts[2]).. ' to file: ' .. tostring(cmdParts[3]))
					Spring.Log("Chonsole", LOG.ERROR, err)
				end
			end
		end,
	},
}
