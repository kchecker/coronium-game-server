--======================================================================--
--== Coronium GS Game
--== @copyright Chris Byerley @develephant
--== @year 2014
--== @version 1
--== @license Apache License 2.0
--======================================================================--
local Emitter = require( 'core' ).Emitter
local json = require( 'json' )
local math = require( 'math' )
local table = require( 'table' )
--======================================================================--
--== Game Class
--======================================================================--

--- Coronium Game Class.
-- A single instance of a running game.  You can get a game instance by
-- using the `CoroniumGS` class.
-- @author Chris Byerley
-- @copyright 2014 develephant
-- @license Apache License 2.0
-- @module Game
local Game = Emitter:extend()

function Game:initialize( game_params_tbl )

	local gd = game_params_tbl

	self.players = {}

	self.players_max = gd.players_max

	--== game data holder
	self.data = gd.data or {}

	self.game_id = gd.game_id

	self.game_state = 'open'

	self.game_players_info = {}

	self.game_criteria = gd.game_criteria or nil

	self:_addPlayer( gd.initial_player )

end

---Add a `Client`/Player to the `Game`.
-- @local
function Game:_addPlayer( player )
	if player then

		player.game_id = self:getId()

		if not self:_isPlayerInGame( player ) then
			table.insert( self.players, player )

			--== Send down the game players meta
			self:getPlayersInfo() --=== Refresh cache
			self:publishPlayersInfo()

			self:emit( "GameJoin", self, player )
		end

		if #self.players == self.players_max then

			self.game_state = 'full'
			self:emit( "GameStart", self, self.players )

		elseif self.players_max == 0 and #self.players == 1 then --== Global 'world' game

			self.game_state = 'open'
			self:emit( "GameStart", self, self.players )

		end
	end
end

---Remove a `Client`/Player from the `Game`.
-- @local
function Game:_removePlayer( player )

	for i=1, #self.players do
		if self.players[ i ] == player then
			table.remove( self.players, i )
		end
	end

	--== Send down the game players meta
	self:getPlayersInfo() --=== Refresh cache
	self:publishPlayersInfo()

	self:emit( "GameLeave", self, player )

	if self.players == nil or #self.players == 0 then
		--== Game empty
		self:close()
	end
end

--- Get the unique Game identifier
-- @treturn string The game id.
-- @usage local game_id = game:getId()
function Game:getId()
	return self.game_id
end

--- Get the current game state.
-- One of `open`, `closed`, or `full`
-- @treturn string The current state.
-- @usage local game_state = game:getState()
function Game:getState()
	return self.game_state
end

--- Get the maximum amount of players this game
-- has been set to handle.
-- @treturn int maximal players.
-- @usage local max_players = game:getPlayersMax()
function Game:getPlayersMax()
	return self.players_max
end

--- Get the current player count in the Game.
-- @treturn int Player count.
-- @usage local player_cnt = game:getPlayerCount()
function Game:getPlayerCount()
	if self.players then
		return #self.players
	end

	return 0
end

--- Close a game, setting its state to 'closed'.
-- The game will be deleted on the next queue cycle.
-- @usage game:close()
function Game:close()
	self:removeAllListeners()

	--== Clear out players
	if self.players then
		for i=1, #self.players do
			local player = self.players[ i ]
			if player then
				player.game_id = nil
			end
		end
	end

	self.players = nil

	self.game_state = 'closed'
end

--- Get the game players.
-- @tparam[opt=nil] Client exclude_player A `Client`/Player to exclude from the list.
-- Useful to get all the players except the calling player.
-- @treturn array A table array of `Client`/Player instances.
-- @usage local players = game:getPlayers()
function Game:getPlayers( exclude_player )

	local players = self.players
	local players_collection = {}

	if players then
		for p=1, #players do
			local player = players[ p ]
			if player ~= exclude_player then
				table.insert( players_collection, player )
			end
		end
	end

	return players_collection
end

--- Build a players meta data table. Refreshes cache.
-- @treturn table The players meta information.
-- @usage local players_meta = game:getPlayersInfo()
function Game:getPlayersInfo()
	if self.players then
		local players_info = {}
		for i=1, #self.players do
			local player = self.players[ i ]
			local player_info = {
				num = player:getPlayerNum(),
				handle = player:getPlayerHandle(),
				data = player:getPlayerData()
			}
			table.insert( players_info, player_info )
		end

		self.game_players_info = players_info --== Cache

		return players_info
	end
end

--- Get the stored game data object.
-- @tparam[opt=nil] string data_key A specifc key to pull.
-- If you omit this parameter, the entire game data object
-- is returned.
-- @treturn table The game data table.
-- @usage local game_data = game:getData()
-- local score = game_data.score
-- --== is the same as
-- local score = game:getData( 'score' )
-- --== and
-- local score = game.data.score
function Game:getData( data_key )
	if data_key then
		return self.data[ data_key ]
	else
		return self.data
	end
end

--- Set the game data with a table
-- @tparam table data_tbl The table to use for
-- the game data.  __Overwrites existing game data.__
-- @usage game:setData( { enemies = 35, mana = 2 } )
function Game:setData( data_tbl )
	self.data = data_tbl
end

--- Get a Client/Player instance by player number.
-- @tparam int player_num The player number to retrieve.
-- @treturn[1] client A `Client`/Player instance.
-- @return[2] nil
-- @usage local player = game:getPlayerByNumber( 2 )
-- if player then
--  p( 'got player' )
-- end
function Game:getPlayerByNumber( player_num )
	local players = self:getPlayers()
	for p=1, #players do
		local player = players[ p ]
		if player.player_num == player_num then
			return player
		end
	end

	return nil
end

--- Get a Client/Player by connection `handle`
-- @tparam string player_handle The handle passed into the [connection table](http://coronium.gs/client/modules/CoroniumGSClient.html#connection_table).
-- @treturn[1] client A `Client`/Player instance.
-- @return[2] nil
-- @usage local player = game:getPlayerByHandle( 'handle-id' )
-- if player then
--  p( 'got player' )
-- end
function Game:getPlayerByHandle( player_handle )
	local players = self:getPlayers()
	for p=1, #players do
		local player = players[ p ]
		if player.player_handle == player_handle then
			return player
		end
	end

	return nil
end

--- Get a random Client/Player from the game.
-- @tparam[opt=nil] Client exclude_player A `Client`/Player to exclude from the list.
-- Useful to get all the players except the calling player.
-- @treturn Client A random `Client`/Player instance.
-- @usage local ran_player = game:getRandomPlayer()
function Game:getRandomPlayer( exclude_player )

	-- Get players from game
	local players = self:getPlayers( exclude_player )

	-- Return random
	return players[ math.random( #players ) ]

end

--- Check if `Client`/Player is in the game.
-- @local
function Game:_isPlayerInGame( player )
	for i=1, #self.players do
		if self.players[ i ] == player then
			return true
		end
	end

	return false
end
--======================================================================--
--== Messaging
--======================================================================--

--- Broadcast a table of data to all players in the game.
-- @tparam table data_tbl A table of data to broadcast.
-- @usage game:broadcast( { update = 1 } )
function Game:broadcast( data_tbl )
	if self.players then
		for p=1, #self.players do
			self.players[ p ]:send( data_tbl )
		end
	end
end

--- Publish the currently stored game data to the game player(s).
-- @tparam[opt] client player The `Client`/Player to publish data to.
-- If no player is passed, will be published to all players. *Optional*.
-- @usage game:publishGameData()
function Game:publishGameData( player )

	local game_data = self.data or {}

	game_data._game_data = 1

	if player then --== To specific player
		player:send( game_data )
	else --== To all players
		self:broadcast( game_data )
	end

end

--- Broadcast a `GameDone` message to all game players.
-- This does not close the game (see: `close`), but instead is a helper
-- method to send a 'game done' event to the players.
-- @tparam[opt=nil] string final_msg A message to send along with the `GameDone`
-- event.
-- @usage game:publishGameDone()
function Game:publishGameDone( final_msg )
	self:broadcast( { _game_done = 1, msg = final_msg } )
end

--- Broadcast the game players meta information to all game players.
-- @usage game:publishPlayersInfo()
function Game:publishPlayersInfo()
	self:broadcast( { _players_info = 1, info = self.game_players_info } )
end

--======================================================================--
--== return Game
--======================================================================--
return Game
