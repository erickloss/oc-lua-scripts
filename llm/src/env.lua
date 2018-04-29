local function getOrInitDefault(key, default)
    if os.getenv(key) == nil then
        os.setenv(key, default)
    end
    return os.getenv(key)
end

return {
    LIB_JSON_FILE_NAME = "lib.json",
    DEVELOPMENT_MODE = getOrInitDefault("LLM.DEVELOPMENT_MODE", true),
    LIB_ROOT_DIR = getOrInitDefault("LLM.LIB_ROOT_DIR", "/home/.llm/lib"), -- TODO change to /tmp/.llm/lib
}