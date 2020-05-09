local M = {}

M.BUTTON = hash("onscreen_button")
M.ANALOG = hash("onscreen_analog")

M.BUTTON_PRESSED = hash("button_pressed")
M.BUTTON_RELEASED = hash("button_released")
M.ANALOG_PRESSED = hash("analog_pressed")
M.ANALOG_RELEASED = hash("analog_released")
M.ANALOG_MOVED = hash("analog_moved")

-- Create an instance of onscreen controls
-- @param config Optional table with configuration values. Accepted values are:
--		* touch (hash) Action id for the binding to single touch
-- @return instance
function M.create(config)
	config = config or {}
	config.touch = config.touch or hash("touch")

	local multitouch_enabled = false

	local instance = {}

	local controls = {}

	local BUTTON = hash("button")
	local ANALOG = hash("analog")

	local function create_data(control)
		local data = {
			x = control.x,
			y = control.y,
			id = control.id,
			pressed = control.pressed,
			released = control.released,
		}
		return data
	end
	
	local function handle_button(control, node)
		if control.pressed then
			control.fn(M.BUTTON_PRESSED, node, create_data(control))
		elseif control.released then
			control.fn(M.BUTTON_RELEASED, node, create_data(control))
		end
		control.fn(M.BUTTON, node, create_data(control))
	end

	local function handle_analog(control, node)
		if control.pressed then
			gui.cancel_animation(node, gui.PROP_POSITION)
			control.x = 0
			control.y = 0
			control.analog_pos = vmath.vector3(control.touch_position)
			control.analog_offset = control.touch_position - control.start_position
			control.fn(M.ANALOG_PRESSED, node, create_data(control))
		elseif control.released then
			gui.animate(node, gui.PROP_POSITION, control.start_position, gui.EASING_OUTQUAD, 0.2)
			control.x = 0
			control.y = 0
			control.fn(M.ANALOG_RELEASED, node, create_data(control))
		else
			local diff = control.analog_pos - control.touch_position
			local dir = vmath.normalize(diff)
			local distance = vmath.length(diff)
			if distance > 0 then
				local radius = control.settings.radius or 80
				if distance > radius then
					control.touch_position = control.start_position - dir * radius
					distance = radius
				else
					control.touch_position = control.touch_position - control.analog_offset	
				end
				gui.set_position(node, control.touch_position)
				control.x = -dir.x * distance / radius
				control.y = -dir.y * distance / radius
				control.fn(M.ANALOG_MOVED, node, create_data(control))
			end
		end
		control.fn(M.ANALOG, node, create_data(control))
	end

	local function find_control_for_xy(x, y)
		for node,control in pairs(controls) do
			if gui.pick_node(node, x, y) then
				return control, node
			end
		end
	end

	local function find_control_for_touch_index(touch_index)
		for node,control in pairs(controls) do
			if control.touch_index == touch_index then
				return control, node
			end
		end
	end

	local function register_control(node, handler, settings, fn)
		local id = gui.get_id(node)
		controls[node] = {
			start_position = gui.get_position(node),
			touch_position = vmath.vector3(),
			id = id,
			pressed = false,
			fn = fn,
			settings = settings,
			handler = handler,
		}
	end

	function instance.reset()
		multitouch_enabled = false
		for k,_ in pairs(controls) do
			controls[k] = nil
		end
	end
	
	--- Register an on-screen button
	-- Will generate onscreen.BUTTON_PRESSED and onscreen.BUTTON_RELEASED
	-- @param node The node representing the button
	-- @param settings Optional settings table (currently unused)
	-- @param fn Function to call when button is interacted with
	function instance.register_button(node, settings, fn)
		assert(node, "You must provide a node")
		assert(fn, "You must provide a function")
		settings = settings or {}
		register_control(node, handle_button, settings, fn)
	end

	--- Register an on-screen analog stick
	-- Will generate onscreen.BANALOG_PRESSED, onscreen.ANALOG_RELEASED and onscreen.ANALOG_MOVED
	-- @param node The node representing the analog stick
	-- @param settings Optional settings table. Accepted parameters are:
	--		* radius (number) - Radius of analog stick
	-- @param fn Function to call when analog stick is interacted with
	function instance.register_analog(node, settings, fn)
		assert(node, "You must provide a node")
		assert(fn, "You must provide a function")
		settings = settings or {}
		register_control(node, handle_analog, settings, fn)
	end

	local function handle_touch(touch, touch_index)
		if touch.pressed then
			local control, node = find_control_for_xy(touch.x, touch.y)
			if control and not control.pressed then
				control.touch_position.x = touch.x
				control.touch_position.y = touch.y
				control.pressed = true
				control.released = false
				control.touch_index = touch_index
				control.handler(control, node)
			end
		elseif touch.released then
			local control, node = find_control_for_touch_index(touch_index)
			if control then
				control.touch_position.x = touch.x
				control.touch_position.y = touch.y
				control.pressed = false
				control.released = true
				control.touch_index = nil
				control.handler(control, node)
			end
		else
			local control, node = find_control_for_touch_index(touch_index)
			if control then
				control.touch_position.x = touch.x
				control.touch_position.y = touch.y
				control.pressed = false
				control.released = false
				control.handler(control, node)
			end
		end
	end

	-- Forward any input here
	-- @param action_id
	-- @param action
	function instance.on_input(action_id, action)
		assert(action, "You must provide an action table")
		if action.touch then
			multitouch_enabled = true
			for i,tp in pairs(action.touch) do
				handle_touch(tp, tp.id)
			end
		elseif action_id == config.touch and not multitouch_enabled then
			handle_touch(action, 0)
		end
	end
	
	return instance
end


local singleton = M.create()

function M.reset(instance)
	instance = instance or singleton
	return instance.reset()
end

function M.register_button(node, settings, fn, instance)
	instance = instance or singleton
	return instance.register_button(node, settings, fn)
end

function M.register_analog(node, settings, fn, instance)
	instance = instance or singleton
	return instance.register_analog(node, settings, fn)
end

function M.on_input(action_id, action, instance)
	instance = instance or singleton
	return instance.on_input(action_id, action)
end

pprint(...)
return M