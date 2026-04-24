extends RefCounted

static func clamp_ratio(value: float) -> float:
	return clampf(value, 0.0, 1.0)
