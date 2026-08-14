//! Typed views over the engine's generic row binding.

use spring_native::{
    prelude::Error, RmlDataEventArgs, RmlDataModel, RmlDataRows, RmlFieldType, RmlValue,
    RmlValueRef,
};

/// A record type that can be rendered by a `data-for` view.
///
/// `FIELDS` names the RML-visible members; `values` must push exactly one value
/// per field, in the same order.
pub(crate) trait Row {
    const FIELDS: &'static [(&'static str, RmlFieldType)];

    fn values<'a>(&'a self, out: &mut Vec<RmlValueRef<'a>>);
}

/// A bound collection of [`Row`] values.
pub(crate) struct Rows<T: Row> {
    rows: std::rc::Rc<RmlDataRows<'static>>,
    _row: std::marker::PhantomData<T>,
}

impl<T: Row> Clone for Rows<T> {
    fn clone(&self) -> Self {
        Rows {
            rows: self.rows.clone(),
            _row: std::marker::PhantomData,
        }
    }
}

impl<T: Row> Rows<T> {
    pub(crate) fn bind(model: &RmlDataModel<'static>, name: &str) -> Result<Self, Error> {
        Ok(Rows {
            rows: std::rc::Rc::new(model.bind_rows(name, T::FIELDS)?),
            _row: std::marker::PhantomData,
        })
    }

    /// Bind a `data-event-*` handler declared as `name(it_index)`, delivering
    /// the row index and the element that raised the event.
    pub(crate) fn on_row<F>(
        model: &RmlDataModel<'static>,
        name: &str,
        mut handler: F,
    ) -> Result<(), Error>
    where
        F: FnMut(usize, u64) + 'static,
    {
        model.bind_event(
            name,
            &[RmlFieldType::Int],
            move |args: RmlDataEventArgs<'_>| {
                if let Some(Some(RmlValue::Int(index))) = args.get(0) {
                    if let Ok(index) = usize::try_from(index) {
                        handler(index, args.target_element_handle);
                    }
                }
            },
        )?;
        Ok(())
    }

    pub(crate) fn set(&self, rows: &[T]) -> Result<(), Error> {
        let mut values: Vec<RmlValueRef<'_>> = Vec::with_capacity(rows.len() * T::FIELDS.len());
        for row in rows {
            row.values(&mut values);
        }
        self.rows.set(&values)
    }
}
