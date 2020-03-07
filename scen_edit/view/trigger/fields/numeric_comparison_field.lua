SB.Include(Path.Join(SB.DIRS.SRC, 'view/fields/choice_field.lua'))

NumericComparisonField = ChoiceField:extends{}

function NumericComparisonField:init(opts)
    opts.captions = SB.metaModel.numericComparisonTypes
    opts.items = {}
    for i = 1, #opts.captions do
        table.insert(opts.items, i)
    end

    ChoiceField.init(self, opts)
end
