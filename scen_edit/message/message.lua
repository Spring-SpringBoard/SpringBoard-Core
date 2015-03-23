Message = LCS.class{}

function Message:init(tag, data)
    self.tag = tag
    self.data = data
end

function Message:serialize()
    return self:deepcopyLCS({
        tag = self.tag,
        data = self.data,
    })
end

function Message:deepcopyLCS(t)
    if type(t) ~= 'table' then return t end
    local res = {}
    for k, v in pairs(t) do
        if type(v) ~= "function" and k ~= "__index" then
            if type(v) == 'table' then
                v = self:deepcopyLCS(v)
            end
            res[k] = v
        end
    end
    return res
end