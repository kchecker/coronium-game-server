--======================================================================--
--== Coronium GS
--== @copyright Chris Byerley @develephant
--== @year 2014
--== @version 1.1
--== @license Apache License 2.0
--======================================================================--
local os = require( 'os' )
local utils = require( 'utils' )
local timer = require( 'timer' )
local tools = require( 'Tools' )
local json = require( 'json' )

local Emitter = require( 'core' ).Emitter
local Server = require( 'Server' )
local Client = require( 'Client' )
local Game = require( 'Game' )
local DataManager = require( 'DataManager' )

--- Coronium GS Class.
-- A real-time multi-player game server build on Luvit.io.
-- @author Chris Byerley
-- @copyright 2014 develephant
-- @license Apache License 2.0
-- @module CoroniumGS
local GS = Emitter:extend()

--- Create a new Coronium GS instance.
-- @function GS:new
-- @tparam int port Port to listen on.
-- @tparam sting connection_key A security key to pair client/server
-- @return CoroniumGS The game server instance.
-- @usage local gs = require( 'CoroniumGS' ):new( 1234, 'secret_key' )
function GS:initialize( port, connection_key, print_data )
	--== Key used to pair client
	self.connection_key = connection_key or ""

	--== Clients
	self.clients = {}
	self.client_cnt = 0

	self.client_timeout_seconds = 900

	--== Clients waiting for games
	self.client_game_queue = {}

	--== Games
	self.games = {}
	self.game_cnt = 0

	--== Timers
	self.queue_timer = nil

	--== Start the server
	self:_startServer( port )

	--== Start game queue
	self:_startQueueWatcher()

	--== Data Manager
	self.dm = DataManager:new( 'game', 60000, 'gs' )
	--== Flush old data
	self.dm:clearDb()

	--== Start admin listener
	self.admin_queue_timer = nil
	self:_checkAdminQueue()

	--== print data to console
	self.showOutput = print_data or false
end
--======================================================================--
--== Clients
--======================================================================--

--- Add a client to the system
-- @local
function GS:_addClient( client_sock )

	local client_timeout_seconds = self.client_timeout_seconds or 120

	--== Create client_sock wrapper
	local client = Client:new( client_sock, client_timeout_seconds )
	--== Store new client
	self.clients[ client_sock ] = client
	--== Update client count
	self.client_cnt = self.client_cnt + 1

	--== Bind handlers
	client:on( "ClientData", utils.bind( self.onClientData, self ) )
	client:on( "ClientClose", utils.bind( self.onClientClose, self ) )
	client:on( "ClientTimeout", utils.bind( self.onClientTimeout, self ) )
	client:on( "ClientError", utils.bind( self.onClientError, self ) )

	local client_id = client:getId()
	local host = client:getHost()

	local s = { id = client_id, state = 'handshaking', ip = host, device = 'unknown', }

	self.dm:once( "DataSaved", function( r, e )
		p( r, e )
	end )
	self.dm:saveData( s, 'client:'..client_id )
	self.dm:saveData( self.client_cnt, 'client_count' )

	--== Do Handshake here to verify
	--== this is a true game client
	client.pending_handshake = true
	client:send( { _handshake = 1 } )

end

--- Remove a client from the system
-- @local
function GS:_removeClient( client_sock )
	--== Remove client
	local client_id = self.clients[ client_sock ]:getId()

	self.clients[ client_sock ] = nil

	--== Update client count
	self.client_cnt = self.client_cnt - 1

	self.dm:clearData( 'client:'..client_id )
	self.dm:saveData( self.client_cnt, 'client_count' )

end

--- Get `Client`/Player by its identifier
-- @tparam string client_id The client indentifier.
-- @treturn[1] Client The `Client`/Player belonging to this id.
-- @return[2] nil
-- @usage local client = gs:getPlayerById( 'client-id' )
function GS:getClientById( client_id )
	for _, client in pairs( self.clients ) do
		if client:getId() == client_id then
			return client
		end
	end

	return nil
end

--- Get the current client count connected to the server.
-- @treturn int The client count.
-- @usage local client_cnt = gs:getClientCount()
function GS:getClientCount()
	return self.client_cnt
end

--- Get clients connected to the server.
-- @tparam[opt=nil] table clients_query An optional query table.
-- @treturn table A table of clients.
-- @usage local clients = gs:getClients()
-- for _, client in pairs( clients ) do
--   p( client:getId() )
-- end
-- --== With 'in game' query
-- local clients = gs:getClients( { in_game = true|false } )
function GS:getClients( clients_query )
	--== All
	if not clients_query then
		return self.clients
	end

	local clients_tbl = {}
	for _, client in pairs( self.clients ) do
		if clients_query.in_game == true and client:isInGame() then
			table.insert( clients_tbl, client )
		elseif clients_query.in_game == false and not client:isInGame() then
			table.insert( clients_tbl, client )
		end
	end

	return clients_tbl
end

--- Broadcast a message to clients/players.
-- @tparam table data_tbl The message data table to broadcast.
-- @tparam[opt=false] boolean in_game Send message to everyone,
-- else will just send to clients/players currently not in a game.
-- @usage gs:broadcast( { msg = 'Server will be closing soon.' } )
function GS:broadcast( data_tbl, in_game )

	if not in_game then
		for _, client in pairs( self.clients ) do
			if not client:getGameId() then
				client:send( data_tbl )
			end
		end
	else
		for _, client in pairs( self.clients ) do
			if client:getGameId() then
				client:send( data_tbl )
			end
		end
	end

end
--======================================================================--
--== Client Handlers
--======================================================================--

--- onClientData listener.
-- @local
function GS:onClientData( client_sock, data )

	if self.showOutput == true and data then
		p( data )
	end

	--== Pull Client by socket connection
	local client = self.clients[ client_sock ]

	--======================================================================--
	--== Handshake
	--======================================================================--
	if client.pending_handshake then
		if data._handshook then
			if data.key == self.connection_key then
				client.pending_handshake = false
				if data.handle then
					client:_setPlayerHandle( data.handle )
				end
				if data.data then
					client:setPlayerData( data.data )
				end
				--== Send connection confirmation
				client:send( { _client_confirmed = 1 } )

				local client_id = client:getId()
				local host = client:getHost()
				local handle = client:getPlayerHandle()

				local player_data = client:getPlayerData()
				local device = "unknown"
				if player_data.device then
					device = player_data.device
				end

				local s = { id = client_id, state = 'connected', ip = host, handle = handle, device = device }
				self.dm:saveData( s, 'client:'..client_id )
				self.dm:saveData( self.client_cnt, 'client_count' )

				--== Emit connect event
				self:emit( "ClientConnect", client )
			else
				client:destroy()
			end
		else
			--== INCORRECT close connection
			client:destroy()
		end
	--======================================================================--
	--== Create game
	--======================================================================--
	elseif data._create_game then
		self:createGame( client, data.players_max, data.game_criteria )
	--======================================================================--
	--== Join game
	--======================================================================--
	elseif data._join_game then
		self:addToGameQueue( client, data.players_max, data.game_criteria )
	--======================================================================--
	--== Cancel game
	--======================================================================--
	elseif data._game_cancel then
		self:cancelGame( data._game_cancel )
	--======================================================================--
	--== Send game data
	--======================================================================--
	elseif data._game_data then
		local game = self:getPlayerGame( client )
		if game then
			client:send( { _game_data = 1, data = game.getData() } )
		end
	--======================================================================--
	--== Incoming client data
	--======================================================================--
	else
		self:emit( "ClientData", client, data )
	end

end

--- onClientClose listener
-- @local
function GS:onClientClose( client_sock )
	local client = self.clients[ client_sock ]

	local game = self:getPlayerGame( client )
	if game then
		game:_removePlayer( client )
	end

	client:removeAllListeners()

	self:_removeClient( client_sock )

	self:emit( "ClientClose", client )
end

--- onClientTimeout listener
-- @local
function GS:onClientTimeout( client_sock )
	local client = self.clients[ client_sock ]
	self:emit( "ClientTimeout", client )
end

--- onClientError listener
-- @local
function GS:onClientError( client_sock, error )
	local client = self.clients[ client_sock ]

	if error.code == "ECONNRESET" then
		client:destroy()
	end

	self:emit( "ClientError", client, error )
end
--======================================================================--
--== Games
--======================================================================--

--- onGameStart listener
-- @local
function GS:onGameStart( game, players )

	local game_id = game:getId()

	for i=1, #players do
		local player = players[ i ]
		player.player_num = i
		player:send( {
			_game_start = 1,
			player_handle = player:getPlayerHandle(),
			player_num = player:getPlayerNum(),
			game_id = game_id
		} )
	end

	local s = { id = game_id, players = game:getPlayerCount(), state = 'in progress' }
	self.dm:saveData( s, 'game:'..game_id )

	self:emit( "GameStart", game, players )

end

--- onGameJoin listener
-- @local
function GS:onGameJoin( game, player )
	self:emit( "GameJoin", game, player )
	game:broadcast( { _game_join = 1, player = player:getPlayerHandle() } )
end

--- onGameLeave listener
-- @local
function GS:onGameLeave( game, player )
	player.game_id = nil
	self:emit( "GameLeave", game, player )
	game:broadcast( { _game_leave = 1, player = player:getPlayerHandle() } )
end

--- Create a new `Game` for players to connect to.
-- Usually will be called from a client.
-- @tparam `Client` initial_player The `Client`/Player starting the game.
-- @tparam int players_max The maximal amount of players this game holds.
-- @tparam[opt=nil] table game_criteria Special criteria for the game to be
-- searched by. Currently supports the 'tag' key for the criteria table.
-- See also `addToGameQueue` game criteria paramter.
-- @usage gs:createGame( p, 2, { tag = 'custom_str' } )
-- @local
function GS:createGame( initial_player, players_max, game_criteria )

	local game_id = game_id or tools.uuid()
	local players_max = players_max or 2
	local game_criteria = game_criteria or nil

	initial_player.game_id = game_id

	local game = Game:new({
		initial_player = initial_player,
		players_max = players_max,
		game_criteria = game_criteria,
		game_id = game_id,
		data = {} --== Start with empty data
	})

	-- p( '--== Creating game ==--' )
	-- p( game.players_max, game.game_criteria )

	game:on( "GameJoin", utils.bind( self.onGameJoin, self ) )
	game:on( "GameLeave", utils.bind( self.onGameLeave, self ) )

	game:once( "GameStart", utils.bind( self.onGameStart, self ) )

	self:_addGame( game, game_id )

	self:emit( "GameCreate", game )

	initial_player:send( { _game_create = 1, game_id = game_id } )

	if players_max == 1 then --single player game
		self:joinGame( game, initial_player )
	elseif players_max == 0 then --global 'world' game
		self:joinGame( game, initial_player )
	end
end

--- Cancel a game that's in an 'open'
--  state and waiting for players.
-- @tparam string game_id The `Game` identifier.
function GS:cancelGame( game_id )

	--== Clear any game association.
	local game = self:getGame( game_id )

	if game and game:getState() == 'open' then

		local players = game:getPlayers()
		for i=1, #players do
			players[ i ].game_id = nil
			players[ i ]:send( { _game_cancel = 1 } )
		end

		--== Mark for game gc
		game:close()
	end

end

--- Join an existing `Game` started with `createGame`.
-- Usually called from a `Client`/Player.
-- @tparam `Game` game The game instance to join.
-- @tparam `Client` player The `Client`/Player joining.
-- @local
function GS:joinGame( game, player )
	game:_addPlayer( player )
end

--- Get a game count of all games, or based on a game query.
-- @tparam[opt=all] table game_query A query to use as
-- a filter for returned results.  You can query for
-- players max, game state, or both.
-- @treturn int The number of games found.
-- @usage --== Count all games
-- local game_count = gs:getGameCount()
-- --== Count 'open' games
-- local game_count = gs:getGameCount( { game_state = 'open' } )
-- --== Count 'full' games
-- local game_count = gs:getGameCount( { game_state = 'full' } )
-- --== Count 'closed' games, these games will be cleared
-- --== on the next game queue cycle.
-- local game_count = gs:getGameCount( { game_state = 'closed' } )
-- --== Get game count with players max setting of 2, in any state.
-- local game_count = gs:getGameCount( { players_max = 2 } )
-- --== Get game count with 3 players, in an 'open' state.
-- local game_count = gs:getGameCount( { players_max = 3, game_state = 'open' } )
function GS:getGameCount( game_query )

	--== All games
	if not game_query then
		return self.game_cnt
	end

	--== Query count
	local games = self.games
	local result_cnt = 0

	local state = game_query.game_state
	local players_max = game_query.players_max

	--Game state and players max
	if state and players_max then
		for id, game in pairs( games ) do
			if game:getState() == state and game:getPlayersMax() == players_max then
				result_cnt = result_cnt + 1
			end
		end
		return result_cnt
	end

	--Game state only
	if state then
		for id, game in pairs( games ) do
			if game:getState() == state then
				result_cnt = result_cnt + 1
			end
		end
		return result_cnt
	end

	--Player max only
	if players_max then
		for id, game in pairs( games ) do
			if game:getPlayersMax() == players_max then
				result_cnt = result_cnt + 1
			end
		end
		return result_cnt
	end

	return result_cnt -- 0
end

--- Get the game instance `Client`/Player belongs to.
-- @tparam Client client The Client/Player to pull game for.
-- @treturn[1] Game The requested `Game` instance.
-- @return[2] nil
-- @usage local game = gm:getPlayerGame( client )
-- if game then
--  p( game:getId() )
-- end
function GS:getPlayerGame( client )
	return self:getGame( client.game_id )
end

--- Get a game instance by its game id.
-- @tparam string game_id The game id to pull.
-- @treturn[1] Game The requested `Game` instance.
-- @return[2] nil
-- @usage local game = gm:getGame( 'game-id' )
-- if game then
--  p( game:getId() )
-- end
function GS:getGame( game_id )
	if game_id then
		return self.games[ game_id ]
	end
	return nil
end

--- Get an array of `Game` instances.
-- @treturn table A table of games, keyed by ID.
-- @usage local games = gs:getGames()
-- for id, game in pairs( games ) do
--  p( 'game id is: ' .. id )
-- end
function GS:getGames()
	return self.games
end

--- Add a game to the queue.
-- @tparam Client player The `Client`/Player to add.
-- @tparam int players_max Maximal amount of players to play with.
-- @tparam[opt=nil] table game_criteria The specifics to look for in a game.
-- You can currently use the 'tag' table key to specify a matching create
-- game 'tag' key.
-- See also `createGame` game criteria parameter.
-- @usage gs:addToGameQueue( p, 2, { tag = 'custom_str' } )
-- @local
function GS:addToGameQueue( player, players_max, game_criteria )

	local game_criteria = game_criteria or nil

	--== Check if this is a 'world' based game.
	if game_criteria and game_criteria.world and players_max == 0 then

		--== Create global game if needed
		if self:getGameCount() == 0 then
			self:createGame( player, players_max, game_criteria )

		elseif self:getGameCount() == 1 then

			--== Global game running
			for _, game in pairs( self.games ) do
				if game.game_criteria.world then
					self:joinGame( game, player )
					break
				end
			end

		end

	else --== Standard game rooms

		local qp = { player = player, players_max = players_max, game_criteria = game_criteria }

		-- p( '--== Adding to game queue ==--' )
		-- p( qp )

		table.insert( self.client_game_queue, qp )

	end

end

--- Add a game to the games table
-- @local
function GS:_addGame( game, game_id )
	self.games[ game_id ] = game
	self.game_cnt = self.game_cnt + 1

	--== Stats
	local s = { id = game_id, players = game:getPlayerCount(), state = 'waiting' }
	self.dm:saveData( s, 'game:'..game_id )
	self.dm:saveData( self.game_cnt, 'game_count' )

end

--- Remove a game from the games table.
-- @local
function GS:_removeGame( game_id )
	if game_id then

		self.games[ game_id ] = nil
		self.game_cnt = self.game_cnt - 1

		--== Stats
		self.dm:clearData( 'game:'..game_id )
		self.dm:saveData( self.game_cnt, 'game_count' )

		self:emit( "GameClose", game_id )

	end
end

--- Start the game queue loop.
-- @local
function GS:_startQueueWatcher()
	p( "--== Game Queue Started ==--" )
	self.queue_timer = timer.setInterval( 1555, function()
		if #self.client_game_queue > 0 then
			self:_checkGameQueue()
		end
		--== Run a game gc
		if self.game_cnt > 0 then
			self:_gameCleanUp()
		end
	end)
end

--- Stop the game queue loop.
-- @local
function GS:_stopQueueWatcher()
	p( "--== Game Queue Stopped ==--" )
	if self.queue_timer then
		timer.clearTimer( self.queue_timer )
	end
end

--- Check the game queue for games to start or close.
-- @local
function GS:_checkGameQueue()
	for game_id, game in pairs( self.games ) do
		local game_state = game:getState()
		--======================================================================--
		--== Game open
		--======================================================================--
		if game_state == 'open' then
			local players_max = game:getPlayersMax()

			for i=#self.client_game_queue, 1, -1 do
				--== Query properties
				local qp = self.client_game_queue[ i ]

				if qp then
					--======================================================================--
					--== Game has criteria
					--======================================================================--
					if game.game_criteria then
						local tag = game.game_criteria.tag

						if qp.game_criteria then
							local qp_tag = qp.game_criteria.tag
							if ( qp_tag == tag ) and ( qp.players_max == players_max ) then
								local pd = table.remove( self.client_game_queue, i )
								local player = pd.player
								player.game_id = game_id
								self:joinGame( game, player )
							end
						end
					--======================================================================--
					--== Game does not have criteria, player count only
					--======================================================================--
					elseif not game.game_criteria then
						if not qp.game_criteria and ( qp.players_max == players_max ) then
							local pd = table.remove( self.client_game_queue, i )
							local player = pd.player
							player.game_id = game_id
							self:joinGame( game, player )
						end
					end
				end
			end
		end
	end
end

--- Cleans up expired/empty games
-- @local
function GS:_gameCleanUp()
	--local player_cnt
	local players
	for id, game in pairs( self.games ) do

		players = game:getPlayers()
		local has_player = false

		if players then
			for i=1, #players do
				if players[ i ]:isWritable() then
					has_player = true
				end
			end
		end

		if ( game:getState() == 'closed' ) or has_player == false then
			self:_removeGame( id )
		end

	end
end

--======================================================================--
--== Admin
--======================================================================--
function GS:_checkAdminQueue()
	self.admin_queue_timer = timer.setInterval( 11000, function()
		self.dm:once( "DataRange", function( data )

			if #data > 0 then
				for d=1, #data do
					local record = json.parse( data[ d ] )
					if record.game_id then
						--== Close game
						local game = self:getGame( record.game_id )
						if game then
							game:publishGameDone('The game has been closed')
							game:close()
						end
					elseif record.client_id then
						--== Boot client
						local client = self:getClientById( record.client_id )
						if client then
							client:destroy()
						end
					end
				end
			end

			self.dm:clear( 'admin_queue' )
		end )
		self.dm:range( 'admin_queue', 0, -1 )

	end )
end
--======================================================================--
--== Server
--======================================================================--

--- Start the main server listener
-- @local
function GS:_startServer( port )
	self.server = Server:new( port )

	self.server:on( "ClientConnect", function( client_sock )
		self:_addClient( client_sock )
	end )

	self.server:connect()

	p( '--== Welcome to the Coronium Game Server ==--' )
end
--======================================================================--
--== return GS Class
--======================================================================--
return GS

--- Game Events.
-- You can listen for the following `Game` events.
-- @section Events


--[[--
A `Game` has been created.
@field GameCreate
@usage
gs:on( "GameCreate", function( game )
	print( game:getId() )
end )
]]

--[[--
A `Game` has started. All players present.
@field GameStart
@usage
gs:on( "GameStart", function( game, players )
	print( game:getId(), #players )
end )
]]

--[[--
A player has joined a `Game`.
@field GameJoin
@usage
gs:on( "GameJoin", function( game, player )
	print( game:getId(), player:getId() )
end )
]]

--[[--
A player has left a `Game`.
@field GameLeave
@usage
gs:on( "GameLeave", function( game, player )
	print( game:getId(), player:getId() )
end )
]]

--[[--
A `Game` been closed and will be erased.
@field GameClose
@usage
gs:on( "GameClose", function( game_id )
	print( game_id )
end )
]]

--- Client Events.
-- You can listen for the following `Client` events.
-- @section Events

--[[--
A `Client` has connected.
@field ClientConnect
@usage
gs:on( "ClientConnect", function( client )
	print( client:getHost() )
end )
]]

--[[--
Incoming `Client` data.
@field ClientData
@usage
gs:on( "ClientData", function( client, data )
	print( data.some_table_key )
end )
]]

--[[--
`Client` has timed out.
@field ClientTimeout
@usage
gs:on( "ClientTimeout", function( client )
	print( "client timed out" )
end )
]]

--[[--
`Client` has thrown an error.
@field ClientError
@usage
gs:on( "ClientError", function( client, error )
	print( "error: " .. error )
end )
]]

--[[--
`Client` has closed.
@field ClientClose
@usage
gs:on( "ClientClose", function( client )
	print( "client closed" )
end )
]]
