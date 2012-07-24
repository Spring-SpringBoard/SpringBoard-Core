Message = LCS.class{}

function Message:init(tag, data)
    self.tag = tag
    self.data = data
end

function Message:serialize()
    return {
        tag = self.tag,
        data = self.data,
    }
end
