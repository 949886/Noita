class_name WeightedPicker
extends RefCounted

static func pick(items: Array, rng: RandomNumberGenerator) -> Variant:
	if items.is_empty():
		return null
	var total: float = 0.0
	for item in items:
		total += max(0.0, item.weight)
	if total <= 0.0:
		return items[rng.randi_range(0, items.size() - 1)]
	var roll: float = rng.randf() * total
	var cursor: float = 0.0
	for item in items:
		cursor += max(0.0, item.weight)
		if roll <= cursor:
			return item
	return items.back()
