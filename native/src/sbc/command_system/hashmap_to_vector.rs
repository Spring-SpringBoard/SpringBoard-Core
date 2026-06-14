use std::collections::HashMap;

pub fn hashmap_to_vector<T: Clone>(map: &HashMap<usize, T>) -> Result<Vec<T>, String> {
    if map.is_empty() {
        return Ok(Vec::new());
    }

    let max_key = *map.keys().max().unwrap();
    if map.len() != max_key + 1 {
        return Err("HashMap keys are not contiguous or do not start from 0".to_string());
    }

    let mut vec = Vec::with_capacity(map.len());
    for i in 0..=max_key {
        match map.get(&i) {
            Some(value) => vec.push(value.clone()),
            None => return Err(format!("Missing key: {}", i)),
        }
    }

    Ok(vec)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_transformation() {
        let mut map = HashMap::new();
        map.insert(0, "a");
        map.insert(1, "b");
        map.insert(2, "c");

        let result = hashmap_to_vector(&map).unwrap();
        assert_eq!(result, vec!["a", "b", "c"]);
    }

    #[test]
    fn test_empty_map() {
        let map: HashMap<usize, &str> = HashMap::new();
        let result = hashmap_to_vector(&map).unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn test_non_contiguous_keys() {
        let mut map = HashMap::new();
        map.insert(0, "a");
        map.insert(1, "b");
        map.insert(3, "d"); // Missing key 2

        let result = hashmap_to_vector(&map);
        assert!(result.is_err());
    }

    #[test]
    fn test_keys_not_starting_from_zero() {
        let mut map = HashMap::new();
        map.insert(1, "a");
        map.insert(2, "b");
        map.insert(3, "c");

        let result = hashmap_to_vector(&map);
        assert!(result.is_err());
    }
}
