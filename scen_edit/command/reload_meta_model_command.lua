ReloadMetaModelCommand = AbstractCommand:extends{}

function ReloadMetaModelCommand:init()
    self.className = "ReloadMetaModelCommand"
end

function ReloadMetaModelCommand:execute()
	Spring.Echo("Reloading meta model...")
    local metaModelLoader = MetaModelLoader()
    metaModelLoader:Load()
	Spring.Echo("Loading completed successfully")
end
