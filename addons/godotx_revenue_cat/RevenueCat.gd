# addons/godotx_revenue_cat/RevenueCat.gd
# Runtime wrapper for RevenueCat native plugin integration
extends Node

## Signals that TipManager expects
signal purchase_completed(product_id: String)
signal purchase_failed(error: String)
signal purchaseCompleted(product_id: String)  # Alternative camelCase signal
signal purchaseFailed(error: String)

var _native_rc: Object = null
var _is_ready: bool = false

func _ready() -> void:
	# Try to load native RevenueCat plugin on iOS/Android
	var os_name = OS.get_name()
	if os_name in ["iOS", "Android"]:
		if Engine.has_singleton("RevenueCat"):
			_native_rc = Engine.get_singleton("RevenueCat")
			_is_ready = true
			print("[RevenueCat] Native plugin detected and loaded")
		elif Engine.has_singleton("Purchases"):
			_native_rc = Engine.get_singleton("Purchases")
			_is_ready = true
			print("[RevenueCat] Native Purchases plugin detected and loaded")
		else:
			print("[RevenueCat] Native plugin not found on %s" % os_name)
	else:
		print("[RevenueCat] Not on iOS/Android, running in sandbox mode")

## Initialize RevenueCat with API key
func initialize(api_key: String) -> void:
	if not _native_rc:
		print("[RevenueCat] Native plugin not available, skipping initialization")
		return

	if _native_rc.has_method("initialize"):
		_native_rc.initialize(api_key)
		print("[RevenueCat] Initialized with API key")
	elif _native_rc.has_method("setApiKey"):
		_native_rc.setApiKey(api_key)
		print("[RevenueCat] API key set")

## Get available products
func get_products() -> Array:
	if not _native_rc or not _native_rc.has_method("get_products"):
		return []
	return _native_rc.get_products()

## Purchase a product
func purchase_package(package_id: String) -> void:
	if not _native_rc:
		print("[RevenueCat] Native plugin not available, cannot purchase")
		purchase_failed.emit("Native plugin unavailable")
		return

	if _native_rc.has_method("purchase_package"):
		_native_rc.purchase_package(package_id)
	elif _native_rc.has_method("purchasePackage"):
		_native_rc.purchasePackage(package_id)
	else:
		print("[RevenueCat] Purchase method not found")
		purchase_failed.emit("Purchase method not available")

## Handle native purchase completion
func _on_purchase_completed(product_or_dict) -> void:
	var product_id = ""
	if typeof(product_or_dict) == TYPE_DICTIONARY:
		product_id = str(product_or_dict.get("product_id", product_or_dict.get("package_id", "")))
	else:
		product_id = str(product_or_dict)

	purchase_completed.emit(product_id)
	purchaseCompleted.emit(product_id)
	print("[RevenueCat] Purchase completed: %s" % product_id)

## Handle native purchase failure
func _on_purchase_failed(error) -> void:
	var error_msg = str(error)
	purchase_failed.emit(error_msg)
	purchaseFailed.emit(error_msg)
	print("[RevenueCat] Purchase failed: %s" % error_msg)

## Check if native plugin is available
func is_native_available() -> bool:
	return _is_ready and _native_rc != null
