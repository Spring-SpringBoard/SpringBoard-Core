MapGrid = LCS.class{}

function MapGrid:init(rows, columns)
    self.rows = rows
    self.columns = columns
    self.separatorSize = 5
end

function MapGrid:initShader()
    local shaderFragStr = [[
        uniform float x, z;
        void main()
        {
            vec2 delta = gl_FragCoord.xy - vec2(x, z);
            float distance = delta.x * delta.x + delta.y * delta.y;
            float alpha = 1 - 2 * distance / 400000;

            alpha = clamp(alpha, 0, 1);

            gl_FragColor = gl_Color;
            gl_FragColor.a *= alpha;
        }
    ]]
 
    local shaderTemplate = {
        fragment = shaderFragStr,
        vertex = shaderVertStr,
    }

    local shader = gl.CreateShader(shaderTemplate)
    local errors = gl.GetShaderLog(shader)
    if errors ~= "" then
        Spring.Log("Scened", "error", "Error creating shader: " .. tostring(errors))
    else
        self.shaderObj = {
            shader = shader,
            uniforms = {
                xID = gl.GetUniformLocation(shader, "x"),
                zID = gl.GetUniformLocation(shader, "z"),
                --falloffFactorID = gl.GetUniformLocation(shader, "falloffFactor"),
            },
        }
    end
end

function MapGrid:Draw(x, z)
    gl.PushMatrix()
        if not self.shaderObj then
            self:initShader()
        end
        gl.UseShader(self.shaderObj.shader)
        local screenX, screenZ = Spring.WorldToScreenCoords(x, Spring.GetGroundHeight(x, z), z)
        gl.Uniform(self.shaderObj.uniforms.xID, screenX)
        gl.Uniform(self.shaderObj.uniforms.zID, screenZ)
        --gl.Uniform(self.shaderObj.uniforms.falloffFactorID, 0.5)
        gl.Color(0, 0.2, 0.6, 0.3)
        --gl.DepthTest(true)
        gl.Utilities.DrawGroundRectangle(0, 0, Game.mapSizeX, Game.mapSizeZ)
        local rowPart = Game.mapSizeX / self.rows
        local columnPart = Game.mapSizeZ / self.columns
        gl.Color(1, 1, 1, 0.5)
        for i = 1, self.rows-1 do
            gl.Utilities.DrawGroundRectangle(rowPart * i - self.separatorSize/2, 0, rowPart * i + self.separatorSize/2, Game.mapSizeZ)
        end
        for j = 1, self.columns-1 do
            gl.Utilities.DrawGroundRectangle(0, columnPart * j - self.separatorSize/2, Game.mapSizeX, columnPart * j + self.separatorSize/2)
        end
        gl.UseShader(0)
    gl.PopMatrix()
end

function MapGrid:GetGridPosition(x, y)
    local rowPart = Game.mapSizeX / self.rows
    local columnPart = Game.mapSizeZ / self.columns
    return rowPart * math.floor(x / rowPart) + rowPart/2, 
           columnPart * math.floor(y / columnPart) + columnPart/2
end