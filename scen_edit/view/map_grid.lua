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
            float alpha = 1.0 - 2.0 * distance / 400000.0;

            alpha = clamp(alpha, 0.0, 1.0);

            gl_FragColor = gl_Color;
            gl_FragColor.a *= alpha;
        }
    ]]

    local shaderTemplate = {
        fragment = shaderFragStr,
        -- vertex = shaderVertStr,
    }

    local shader = Shaders.Compile(shaderTemplate, "MapGrid")
    if shader then
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

function MapGrid:Draw(x, z, blocking)
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

        -- footprint 1
        gl.Color(1, 1, 1, 0.3)
        local totalRows = Game.mapSizeX / 8
        local totalColumns = Game.mapSizeZ / 8
        local totalRowsPart = Game.mapSizeX / totalRows
        local totalColumnsPart = Game.mapSizeZ / totalColumns
        for i = 1, totalRows -1 do
            gl.Utilities.DrawGroundRectangle(totalRowsPart * i - self.separatorSize/4, 0, totalRowsPart * i + self.separatorSize/4, Game.mapSizeZ)
        end
        for j = 1, totalColumns -1 do
            gl.Utilities.DrawGroundRectangle(0, totalColumnsPart * j - self.separatorSize/4, Game.mapSizeX, totalColumnsPart * j + self.separatorSize/4)
        end
        local gridX, gridZ = self:GetGridPosition(x, z)
        if blocking == 2 then
            gl.Color(0, 0.2, 0.6, 0.5)
        elseif blocking == 1 then
            gl.Color(0.6, 0.6, 0, 0.5)
        else
            gl.Color(0.6, 0, 0, 0.5)
        end
        gl.Utilities.DrawGroundRectangle(gridX - rowPart / 2, gridZ - columnPart / 2, gridX + rowPart / 2, gridZ + columnPart / 2)
        gl.UseShader(0)
    gl.PopMatrix()
end

function MapGrid:GetGridPosition(x, y)
    local totalRows = Game.mapSizeX / 8
    local totalColumns = Game.mapSizeZ / 8
    local totalRowsPart = Game.mapSizeX / totalRows
    local totalColumnsPart = Game.mapSizeZ / totalColumns

    -- local rowPart = Game.mapSizeX / self.rows
    -- local columnPart = Game.mapSizeZ / self.columns
    return totalRowsPart * math.floor(x / totalRowsPart) + totalRowsPart/2,
           totalColumnsPart * math.floor(y / totalColumnsPart) + totalColumnsPart/2
end
