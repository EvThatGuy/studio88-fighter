--!strict
-- Tiny pub/sub for the AutoTest harness AND any other cross-context state
-- driver. App subscribes to TestBridge.changed inside a useEffect so events
-- arrive in the standard Roblox event context where React.setState batches
-- + flushes properly. External callers just :Fire() the bindable.

local TestBridge = {}

TestBridge.changed = Instance.new("BindableEvent")
TestBridge.setModal = nil :: ((string?) -> ())?

return TestBridge
