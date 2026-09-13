extends RefCounted
## Visual intensities, not measured precipitation rates or visibility distances.
## Components are rain, snow and fog density. Unknown codes produce no precipitation.
static func profile(code: int) -> Vector3:
	match code:
		45: return Vector3(0.0, 0.0, 0.009)
		48: return Vector3(0.0, 0.0, 0.014)
		51, 56: return Vector3(0.12, 0.0, 0.00035)
		53: return Vector3(0.22, 0.0, 0.00045)
		55, 57: return Vector3(0.35, 0.0, 0.0006)
		61, 66, 80: return Vector3(0.35, 0.0, 0.0004)
		63, 81: return Vector3(0.65, 0.0, 0.0007)
		65, 67, 82, 95, 96, 99: return Vector3(1.0, 0.0, 0.0012)
		71, 77, 85: return Vector3(0.0, 0.3, 0.0007)
		73: return Vector3(0.0, 0.6, 0.0014)
		75, 86: return Vector3(0.0, 1.0, 0.0025)
		_: return Vector3(0.0, 0.0, 0.000025)
