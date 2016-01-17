--======================================================================--
--== Coronium GS Client
--== @copyright Chris Byerley @develephant
--== @year 2014
--== @version 1
--== @license Apache License 2.0
--======================================================================--
local table = require( 'table' )
local math = require( 'math' )
local utils = require( 'utils' )
local json = require( 'json' )
local os = require( 'os' )
local tools = require( 'Tools' )
local Emitter = require( 'core' ).Emitter

--- Coronium GS Client/Player.
-- A socket client connected to the server.
-- @author Chris Byerley
-- @copyright 2014 develephant
-- @license Apache License 2.0
-- @module Client
local Client = Emitter:extend()

Client.timeout = 120 --== 2 mins

--======================================================================--
--== Client Instance
--======================================================================--

---Create a new Client instance. __This is handled automatically.__
-- @tparam Socket client_sock The incoming socket connection.
-- @tparam int timeout_seconds The number of seconds before
-- the Client connection will time out.
-- @treturn Client The newly wrapped socket connection.
-- @usage local client = Client:new( socket, 30 )
-- @function new
-- @local
function Client:initialize( client_sock, timeout_seconds )

	self.player_id = tools.uuid()

	local timeout = timeout_seconds or Client.timeout

	self.client = client_sock

	self.client:on( "data", utils.bind( self._handleData, self ) )

	self.client:on( "close", function()
		self:emit( "ClientClose", self.client )
	end)

	self.client:on( "timeout", function ( e )
		self:emit( "ClientTimeout", self.client )
		self.client:done()
	end)

	self.client:on( "error", function( e )
		self:emit( "ClientError", self.client, e )
	end)

	self:setTimeout( timeout )

	self.buffer = ""

	--== Set from outside ==--
	--== Auto-gen random player handle
	self.player_handle = 'user' .. tools.uuid()

	self.player_num = nil
	self.player_data = nil

	self.game_id = nil

end

---Get the `Client`/Player identifier.
-- @treturn string player_id.
function Client:getId()
	return self.player_id
end

--- Set the players connection handle.
-- @tparam string player_handle The `Client`/Players name.
-- @usage client:setPlayerHandle( "player-handle" )
-- @local
function Client:_setPlayerHandle( player_handle )
	if not player_handle then
		self.player_handle = 'users' .. tools.uuid()
	else
		self.player_handle = player_handle
	end
end

--- Gets the players connection handle.
-- This can represent a name, or any other identifier.
-- @treturn string The `Client`/Players name.
-- @usage local player_handle = client:getPlayerHandle()
function Client:getPlayerHandle()
	return self.player_handle
end

--- Get the players game position number.
-- @treturn int `Client`/Player position.
-- @usage local player_num = client:getPlayerNum()
function Client:getPlayerNum()
	return self.player_num
end

--- Get the players game identifier.
-- @treturn string The game id the player belongs to.
-- @usage local game_id = client:getGameId()
function Client:getGameId()
	return self.game_id
end

--- Checks to see if the `Client`/Player is in a `Game`
-- @treturn boolean
-- @usage local in_game = client:isInGame()
function Client:isInGame()
	if self.game_id then
		return true
	end

	return false
end

--- Get the client host address.
-- @treturn string Host address.
-- @usage local host_addr = client:getHost()
function Client:getHost()
	if self.client then
		return self.client:address().address
	end
end

--- Get the client port.
-- @treturn int Port number.
-- @usage local port_num = client:getPort()
function Client:getPort()
	if self.client then
		return self.client:address().port
	end
end

--- Set the Client timeout.
-- @tparam int seconds The seconds before timeout occurs.
-- @usage client:setTimeout( 300 )
function Client:setTimeout( seconds )
	if self.client then
		self.client:setTimeout( ( 1000 * seconds ) )
	end
end

---Set the players custom data table.
--
-- You should be sure to get the current data table
-- using `getPlayerData` and make your changes
-- on that table before using this method.
-- @tparam table data The player data table to save/update.
-- @usage --== Get the current player data
-- local pd = client:getPlayerData()
-- --== Do work
-- pb.fav_color = "Red"
-- --== Store it
-- client:setPlayerData( pb )
-- --== Clear player data
-- client:setPlayerData( {} )
function Client:setPlayerData( data )
	if data then
		self.player_data = data
	end
end

--- Get the players custom data table.
-- Custom data can be included at connection time
-- or during runtime by using `setPlayerData`.
-- @treturn[1] table The custom `Client`/Player data.
-- @return[2] nil
function Client:getPlayerData()
	return self.player_data
end

function Client:_handleData( data )
	local inputs = {}
	table.insert( inputs, data )

	for i, chunk in ipairs( inputs ) do
		local s,f = chunk:find("<<END>>")
		if s then
		  local d = self.buffer .. chunk:sub(1,s-1)
	      local reply = self:json2tbl( d )
	      if reply then
	      	if reply._ping then
	      		self:send( { _pong = 1, ts = reply.ts } ) --return pong
	      	else
	      		--== Internals
	      		self:emit( "ClientData", self.client, reply )
	      	end
	      end

	      self.buffer = ""
		else
			self.buffer = self.buffer .. chunk
		end
	end

end

--- Send data to the Client.
-- @tparam table data_tbl A table of data to send.
-- @usage client:send( { points = 12, update = 1 } )
function Client:send( data_tbl )

	local data = self:tbl2json( data_tbl )

	if data then
		if self.client.writable then
			return self.client:write( data .. "\r\n" )
		end
	end

	return nil
end

--- Destroy the client connection.
-- You normally let the system handle
-- the socket closing.  This will close
-- the connection without delay and end
-- the game.  __The engine automatically handles the client closing.  This can be used for custom functionality__.
-- @usage client:destroy()
-- @local
function Client:destroy()
	self.client:destroy()
end

--- Check if the client socket can send data.
--  __Usually used for custom functionality__.
-- @usage local is_writable = client:isWritable()
-- @local
function Client:isWritable()
	return self.client.writable
end

--- Convert a Lua table to JSON string.
-- __Usually used for custom functionality__.
-- @tparam table tbl The table to convert.
-- @treturn string The JSON string result.
-- @local
function Client:tbl2json( tbl )
	local success, result = pcall( json.stringify, tbl )
	if success then
		return result
	end

	return nil
end

--- Convert a JSON string to a Lua table.
-- __Usually used for custom functionality__.
-- @tparam string str The JSON string to convert.
-- @treturn table The Lua table result.
-- @local
function Client:json2tbl( str )
	local success, result = pcall( json.parse, str )
	if success then
		return result
	end

	return nil
end

--== Return Class
return Client
