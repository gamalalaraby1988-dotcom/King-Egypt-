extends RefCounted
class_name AssetReviewRegistry

const MANIFEST_PATH := "res://assets/asset_registry.json"
const VALID_STATUSES := [
	"proposed",
	"preview_pending",
	"approved",
	"integrated",
	"rejected",
	"existing_unverified",
	"procedural_prototype_unverified"
]

static func validate_manifest(path: String = MANIFEST_PATH) -> PackedStringArray:
	var errors := PackedStringArray()
	if not FileAccess.file_exists(path):
		errors.append("Asset registry file is missing: " + path)
		return errors

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("Asset registry must contain a JSON object.")
		return errors

	var data: Dictionary = parsed
	if int(data.get("schema_version", 0)) != 1:
		errors.append("Unsupported asset registry schema_version.")
	var assets: Variant = data.get("assets", null)
	if not assets is Array:
		errors.append("Asset registry assets must be an array.")
		return errors

	var seen_ids := {}
	for index in range(assets.size()):
		var item: Variant = assets[index]
		if not item is Dictionary:
			errors.append("Asset entry %d must be an object." % index)
			continue
		var entry: Dictionary = item
		var asset_id := str(entry.get("id", "")).strip_edges()
		var asset_path := str(entry.get("path", "")).strip_edges()
		var status := str(entry.get("status", "")).strip_edges()
		if asset_id.is_empty():
			errors.append("Asset entry %d has no id." % index)
		elif seen_ids.has(asset_id):
			errors.append("Duplicate asset id: " + asset_id)
		else:
			seen_ids[asset_id] = true
		if asset_path.is_empty():
			errors.append("Asset %s has no resource path." % asset_id)
		elif not ResourceLoader.exists(asset_path):
			errors.append("Asset resource does not exist: " + asset_path)
		if not VALID_STATUSES.has(status):
			errors.append("Asset %s has an invalid review status." % asset_id)
		if status in ["approved", "integrated"]:
			if str(entry.get("source", "")).strip_edges().is_empty():
				errors.append("Approved asset %s has no source record." % asset_id)
			if str(entry.get("license", "")).strip_edges().is_empty():
				errors.append("Approved asset %s has no license record." % asset_id)
			if str(entry.get("preview", "")).strip_edges().is_empty():
				errors.append("Approved asset %s has no preview reference." % asset_id)
	return errors
