--======================================================================--
--== Emitter Class
--======================================================================--
local Emitter = class()
Emitter.__name = "Emitter"

local dispatcher = require( 'gs.EventDispatcher' )
function Emitter:__init()
	self.events = dispatcher()
end

return Emitter