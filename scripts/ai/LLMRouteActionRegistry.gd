class_name LLMRouteActionRegistry
extends RefCounted


func register_payload_candidate_routes(payload: Dictionary, action_catalog: Dictionary) -> Dictionary:
	var routes_by_id: Dictionary = {}
	var catalog: Dictionary = action_catalog.duplicate(true)
	var raw_routes: Variant = payload.get("candidate_routes", [])
	if not (raw_routes is Array):
		return {"catalog": catalog, "routes_by_id": routes_by_id}
	for raw_route: Variant in raw_routes:
		if not (raw_route is Dictionary):
			continue
		var route: Dictionary = (raw_route as Dictionary).duplicate(true)
		var route_action_id := _route_action_id(route)
		if route_action_id == "":
			continue
		var route_actions: Array[Dictionary] = materialize_candidate_route_actions(route.get("actions", []), catalog)
		if route_actions.is_empty():
			continue
		route["id"] = route_action_id
		route["action_id"] = route_action_id
		route["type"] = "route"
		route["candidate_route"] = true
		route["actions"] = route_actions
		route["summary"] = str(route.get("description", "candidate route"))
		routes_by_id[route_action_id] = route
		catalog[route_action_id] = route
	return {"catalog": catalog, "routes_by_id": routes_by_id}


func materialize_candidate_route_actions(raw_actions: Variant, action_catalog: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (raw_actions is Array):
		return result
	for raw: Variant in raw_actions:
		if not (raw is Dictionary):
			continue
		var raw_ref: Dictionary = raw
		var action_id := str(raw_ref.get("id", raw_ref.get("action_id", ""))).strip_edges()
		if action_id == "":
			continue
		var ref: Dictionary = {}
		if action_catalog.has(action_id):
			ref = (action_catalog.get(action_id, {}) as Dictionary).duplicate(true)
		elif action_id == "end_turn":
			ref = {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
		else:
			continue
		ref["id"] = action_id
		ref["action_id"] = action_id
		for key: String in ["interactions", "selection_policy", "capability"]:
			if raw_ref.has(key):
				ref[key] = raw_ref.get(key)
		result.append(ref)
	return result


func materialize_action_ref_array(raw_actions: Variant, action_catalog: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (raw_actions is Array):
		return result
	for raw: Variant in raw_actions:
		var action_id := ""
		var interactions: Dictionary = {}
		var selection_policy: Dictionary = {}
		if raw is String:
			action_id = str(raw).strip_edges()
		elif raw is Dictionary:
			action_id = str((raw as Dictionary).get("id", (raw as Dictionary).get("action_id", ""))).strip_edges()
			var raw_interactions: Variant = (raw as Dictionary).get("interactions", {})
			if raw_interactions is Dictionary:
				interactions = (raw_interactions as Dictionary).duplicate(true)
			var raw_selection_policy: Variant = (raw as Dictionary).get("selection_policy", {})
			if raw_selection_policy is Dictionary:
				selection_policy = (raw_selection_policy as Dictionary).duplicate(true)
		if action_id != "" and action_catalog.has(action_id):
			var ref: Dictionary = (action_catalog.get(action_id, {}) as Dictionary).duplicate(true)
			ref["id"] = action_id
			ref["action_id"] = action_id
			if str(ref.get("type", "")) == "route":
				for route_action: Dictionary in expand_candidate_route_ref(ref):
					result.append(route_action)
				continue
			if not interactions.is_empty():
				ref["interactions"] = interactions
			if not selection_policy.is_empty():
				ref["selection_policy"] = selection_policy
			result.append(ref)
			continue
		if raw is Dictionary:
			var raw_dict: Dictionary = raw
			if action_id != "":
				continue
			result.append(raw_dict)
	return result


func expand_candidate_route_ref(route_ref: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_actions: Variant = route_ref.get("actions", [])
	if not (raw_actions is Array):
		return result
	for raw: Variant in raw_actions:
		if not (raw is Dictionary):
			continue
		var action: Dictionary = (raw as Dictionary).duplicate(true)
		var action_id := str(action.get("id", action.get("action_id", ""))).strip_edges()
		if action_id == "":
			continue
		action["id"] = action_id
		action["action_id"] = action_id
		result.append(action)
	return result


func best_route_action_id(routes_by_id: Dictionary) -> String:
	var best_id := ""
	var best_priority := -999999
	for raw_key: Variant in routes_by_id.keys():
		var route_id := str(raw_key)
		var route: Dictionary = routes_by_id.get(raw_key, {}) if routes_by_id.get(raw_key, {}) is Dictionary else {}
		var priority := int(route.get("priority", 0))
		if priority > best_priority:
			best_priority = priority
			best_id = route_id
	return best_id


func _route_action_id(route: Dictionary) -> String:
	var route_action_id := str(route.get("route_action_id", "")).strip_edges()
	if route_action_id != "":
		return route_action_id
	var route_id := str(route.get("id", "")).strip_edges()
	return "route:%s" % route_id if route_id != "" else ""
