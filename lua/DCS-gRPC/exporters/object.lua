--
-- Converts DCS tables in the Object hierarchy into tables suitable for
-- serialization into GRPC responses
-- Each exporter has an equivalent .proto Message defined and they must
-- be kept in sync
--

-- Patched by Arch 11/7/2023 to work around nil group on dead object bug. https://forum.dcs.world/topic/314933-121622-patch-bug-dead-event-no-longer-includes-units-group-mission-breaking-issue/

GRPC.exporters.position = function(pos)
  local lat, lon, alt = coord.LOtoLL(pos)
  return {
    lat = lat,
    lon = lon,
    alt = alt,
    u = pos.z,
    v = pos.x,
  }
end

GRPC.exporters.unit = function(unit)
  local idNum = 0
  if(unit:getID() ~= nil) then
    idNum = tonumber(unit:getID())
  end

  return {
    id = idNum,
    name = unit:getName(),
    callsign = unit:getCallsign(),
    coalition = unit:getCoalition() + 1, -- Increment for non zero-indexed gRPC enum
    type = unit:getTypeName(),
    playerName = Unit.getPlayerName(unit),
    group = GRPC.exporters.group(Unit.getGroup(unit)),
    numberInGroup = unit:getNumber(),
    rawTransform = GRPC.exporters.rawTransform(unit),
  }
end

-- Data used to calculate position/orientation/velocity on the Rust side.
GRPC.exporters.rawTransform = function(object)
  local p = object:getPosition()
  local position = GRPC.exporters.position(p.p)
  return {
    position = position,
    positionNorth = coord.LLtoLO(position.lat + 1, position.lon),
    forward = p.x,
    right = p.z,
    up = p.y,
    velocity = object:getVelocity(),
  }
end

GRPC.exporters.group = function(group)
  if(group == nil) then
    return {
      id = 0,
      name = "unknown",
      coalition = 1, -- Increment for non zero-indexed gRPC enum
      category = 1, -- Increment for non zero-indexed gRPC enum
    }
  end
  
  local idNum = 0
  if(group:getID() ~= nil) then
    idNum = tonumber(group:getID())
  end

  return {
    id = idNum,
    name = group:getName(),
    coalition = group:getCoalition() + 1, -- Increment for non zero-indexed gRPC enum
    category = group:getCategory() + 1, -- Increment for non zero-indexed gRPC enum
  }
end

GRPC.exporters.weapon = function(weapon)
  return {
    id = tonumber(weapon:getName()),
    type = weapon:getTypeName(),
    rawTransform = GRPC.exporters.rawTransform(weapon),
  }
end

GRPC.exporters.static = function(static)
  local idNum = 0
  if(static:getID() ~= nil) then
    idNum = tonumber(static:getID())
  end

  return {
    id = idNum,
    type = static:getTypeName(),
    name = static:getName(),
    coalition = static:getCoalition() + 1, -- Increment for non zero-indexed gRPC enum
    position = GRPC.exporters.position(static:getPoint()),
  }
end

GRPC.exporters.airbase = function(airbase)
  local a = {
    name = airbase:getName(),
    callsign = airbase:getCallsign(),
    coalition = airbase:getCoalition() + 1, -- Increment for non zero-indexed gRPC enum
    category = airbase:getDesc()['category'] + 1, -- Increment for non zero-indexed gRPC enum
    displayName = airbase:getDesc()['displayName'],
    position = GRPC.exporters.position(airbase:getPoint())
  }

  local unit = airbase:getUnit()
  if unit then
    a.unit = GRPC.exporters.unit(unit)
  end

  return a
end

GRPC.exporters.scenery = function(scenery)
  local idNum = 0
  if(scenery:getName() ~= nil) then
    idNum = tonumber(scenery:getName())
  end

  return {
    id = idNum,
    type = scenery:getTypeName(),
    position = GRPC.exporters.position(scenery:getPoint()),
  }
end

GRPC.exporters.cargo = function()
  return {}
end

-- every object, even an unknown one, should at least have getName implemented as it is
-- in the base object of the hierarchy
-- https://wiki.hoggitworld.com/view/DCS_Class_Object
GRPC.exporters.unknown = function(object)
  return {
    name = tostring(object:getName()),
  }
end

GRPC.exporters.markPanel = function(markPanel)
  local mp = {
    id = markPanel.idx,
    time = markPanel.time,
    text = markPanel.text,
    position = GRPC.exporters.position(markPanel.pos),
  }

  if markPanel.initiator then
    mp.initiator = GRPC.exporters.unit(markPanel.initiator)
  end

  if (markPanel.coalition >= 0 and markPanel.coalition <= 2) then
    mp.coalition = markPanel.coalition + 1; -- Increment for non zero-indexed gRPC enum
  end

  if (markPanel.groupID > 0) then
    mp.groupId = markPanel.groupID;
  end

  return mp
end
