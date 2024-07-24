
local obs = obslua

local tracked_source = "nothing"
local connection_lost_source = "nothing"

local check_interval = 1 -- In seconds

local is_tracked_source_active = true

function script_description()
  return "Monitors a source and switches to a standby source upon no visual output."
end

function script_update(settings)
  tracked_source = obs.obs_data_get_string(settings, "tracked_source")
  tracked_scene = obs.obs_data_get_string(settings, "tracked_scene")
  connection_lost_source = obs.obs_data_get_string(settings, "connection_lost_source")

  check_interval = obs.obs_data_get_int(settings, "check_interval")

  obs.timer_remove(check_source_timer)

  -- obs.script_log(obs.LOG_WARNING, "--------------")
  -- obs.script_log(obs.LOG_WARNING, "Updated Settings:")
  -- obs.script_log(obs.LOG_WARNING, "Tracked Source: " .. tracked_source)
  -- obs.script_log(obs.LOG_WARNING, "Tracked Scene: " .. tracked_scene)
  -- obs.script_log(obs.LOG_WARNING, "Connection Lost Source: " .. connection_lost_source)
  -- obs.script_log(obs.LOG_WARNING, "Check Interval: " .. check_interval)
  -- obs.script_log(obs.LOG_WARNING, "--------------")

  if tracked_source ~= "nothing" and connection_lost_source ~= "nothing" then
    check_source_timer = obs.timer_add(tracked_source, check_interval * 1000)
  end
end

function script_properties()
  local props = obs.obs_properties_create()

  -- Tracked Source option
  local p = obs.obs_properties_add_list(props, "tracked_source", "Tracked Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
  local sources = obs.obs_enum_sources()
  if sources ~= nil then
    for _, source in ipairs(sources) do
      source_id = obs.obs_source_get_id(source)
      local name = obs.obs_source_get_name(source)
      if source_id == "ffmpeg_source" then
        obs.obs_property_list_add_string(p, name, name)
      end
    end
  end
  
  -- Connection Lost Source option
  
  local p = obs.obs_properties_add_list(props, "connection_lost_source", "Connection Lost Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
  if sources ~= nil then
    for _, source in ipairs(sources) do
      source_id = obs.obs_source_get_id(source)
      local name = obs.obs_source_get_name(source)
      if source_id == "ffmpeg_source" then
        obs.obs_property_list_add_string(p, name, name)
      end
    end
  end
  
    -- Tracked Scene option
    local p = obs.obs_properties_add_list(props, "tracked_scene", "Tracked Scene", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    local scenes = obs.obs_frontend_get_scenes()
    if scenes ~= nil then
      for _, scene in ipairs(scenes) do
        local name = obs.obs_source_get_name(scene)
        obs.obs_property_list_add_string(p, name, name)
      end
    end

  -- Check Interval option
  obs.obs_properties_add_int(props, "check_interval", "Check Interval (seconds)", 1, 60, 1)
  
  obs.source_list_release(sources)

  return props
end

function get_sceneitem_by_name(scene_name, source_name)
  -- Get the scene source
  local scene_source = obs.obs_get_source_by_name(scene_name)
  if scene_source ~= nil then
    -- Convert to scene
    local scene = obs.obs_scene_from_source(scene_source)
    if scene ~= nil then
      -- Find the scene item by source name
      local scene_item = obs.obs_scene_find_source(scene, source_name)
      if scene_item ~= nil then
        return scene_item
      else
        print("Scene item not found: " .. source_name)
      end
    else
        print("Scene not found: " .. scene_name)
    end
    -- Release the scene source object
    obs.obs_source_release(scene_source)
  else
    print("Scene source not found: " .. scene_name)
  end
end

function check_source()
  local source = obs.obs_get_source_by_name(tracked_source)
  local source_connection_lost_source = obs.obs_get_source_by_name(connection_lost_source)
  if source ~= nil then
    local width, height = obs.obs_source_get_width(source), obs.obs_source_get_height(source)
    local active = (width > 0 and height > 0)
    obs.obs_source_release(source)
    
    if not active then
      is_tracked_source_active = false
      -- obs.script_log(obs.LOG_WARNING, "Source " .. tracked_source .. " is inactive. Switching to " .. connection_lost_source)
      if source_connection_lost_source ~= nil then
        -- make the source visible
        -- obs.script_log(obs.LOG_WARNING, "Enabling source " .. connection_lost_source)

        local scene_item = get_sceneitem_by_name(tracked_scene, connection_lost_source)
        
        if not obs.obs_sceneitem_visible(scene_item) then
          obs.obs_sceneitem_set_visible(scene_item, true)
        else
          -- obs.script_log(obs.LOG_WARNING, "Source " .. connection_lost_source .. " is already visible.")
        end

        -- obs.obs_source_release(source) -- causes a crash? fix later
        -- obs.obs_source_release(source_connection_lost_source)
        -- return
      end
    else if not is_tracked_source_active then
      is_tracked_source_active = true
      -- obs.script_log(obs.LOG_WARNING, "Source " .. tracked_source .. " is now active. Hiding " .. connection_lost_source)

      if source_connection_lost_source ~= nil then
        -- make the source visible
        -- obs.script_log(obs.LOG_WARNING, "Disabling source " .. connection_lost_source)

        local scene_item = get_sceneitem_by_name(tracked_scene, connection_lost_source)
        
        if obs.obs_sceneitem_visible(scene_item) then
          obs.obs_sceneitem_set_visible(scene_item, false)
        else
          -- obs.script_log(obs.LOG_WARNING, "Source " .. connection_lost_source .. " is already hidden.")
        end

        -- obs.obs_source_release(source)
        -- obs.obs_source_release(source_connection_lost_source)
        -- return
      end
    end
    end
  end
end

function wait(seconds)
  local start = os.time()
  repeat until os.time() > start + seconds
end

function script_load(settings)
  check_source_timer = obs.timer_add(check_source, check_interval * 1000)
end

function script_unload()
  obs.timer_remove(check_source_timer)
end
