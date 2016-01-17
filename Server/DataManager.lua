--======================================================================--
--== Coronium GS Data class
--======================================================================--
local Emitter = require( 'core' ).Emitter

local json = require( 'json' )

--==Redis
local redis = require( 'redis' )
redis:on( "error", function ( err )
    p("Error (error callback): ", err )
end)

local DataManager = Emitter:extend()

--- Coronium DataManager Class.
-- An instance of the default data manager.  Data 'managers' are usually passed
-- to other 'managers' that handle server functionality.  This default manager
-- uses the Redis.io local memory based data store.  __Don't play with this module
-- unless you know what you're doing.__
-- @author Chris Byerley
-- @copyright 2014 develephant
-- @license Apache License 2.0
-- @module DataManager

---Create a new data manager instance.  Data managers are used to pass to
-- other managers for data functionality.  You can create your own data managers for
-- custom data needs.
-- @tparam[opt=nil] string data_id The 'global' default for the data key.
-- @tparam[opt=300] int data_expiry The number of seconds before data expires.
-- @tparam[opt='data'] string data_prefix The default prefix for the data key.
-- @usage local dm = DataManager:new( 'world', 900, 'data')
-- @function new
function DataManager:initialize( data_id, data_expiry, data_prefix )

	self.data_id = data_id or nil
	self.data_expiry = data_expiry or 900
	self.data_prefix = data_prefix or 'data'

	self.redis = redis:new()

end

--======================================================================--
--== Data
--======================================================================--

--- Save data to the data storage.
-- Emits a __'DataSaved'__ event when the data has been saved.
-- @tparam table data A table of data to store.
-- @tparam string data_id A key to store data under.
-- @tparam int data_expiry The seconds until data expires.
-- @tparam string data_prefix The data prefix.
-- @usage data:once( "DataSaved", function( err )
--		if not err then
--			print( "data saved" )
--		end
-- )
-- game:saveData( data_tbl, 'some-id', 300, 'some-prefix' )
function DataManager:saveData( data, data_id, data_expiry, data_prefix )

	local data_id = data_id or self.data_id
	local data_expiry = data_expiry or self.data_expiry
	local data_prefix = data_prefix or self.data_prefix

	if type( data ) == 'table' then
		data = json.stringify( data )
	end

	self.redis:setex( data_prefix..':'..data_id, self.data_expiry, data, function( err, reply )
		self:emit( "DataSaved", err )
	end )
end

--- Get the currently saved data.
-- Emits a __'Data'__ event when the data has been retrieved.
-- @tparam string data_id The key data is stored with.
-- @tparam[opt='data'] string data_prefix The data prefix.
-- @usage data:once( "Data", function( game_data )
--		print( game_data.some_table_key )
--	end )
-- data:getData( 'some-id', 'some-prefix' )
function DataManager:getData( data_id, data_prefix )

	local data_id = data_id or self.data_id
	local data_prefix = data_prefix or self.data_prefix

	self.redis:get( data_prefix..':'..data_id, function( err, reply )
		if not err then
			reply = json.parse( reply )
		end
		self:emit( "Data", reply )
	end )
end

--- Clears all stored data.
-- Emits a __'DataCleared'__ event when the data has been cleared.
-- @tparam string data_id The key data is stored with.
-- @tparam[opt='data'] string data_prefix The data prefix.
-- @usage data:once( "DataCleared", function( err )
--		if not err then
--			print( "game data cleared" )
--		end
--	end )
-- data:clearData( 'some-id', 'some-prefix' )
function DataManager:clearData( data_id, data_prefix )

	local data_id = data_id or self.data_id
	local data_prefix = data_prefix or self.data_prefix

	self.redis:del( data_prefix..':'..data_id, function( err, reply )
		self:emit( "DataCleared", err )
	end )
end

function DataManager:push( key, value )
	self.redis:rpush( key, value, function( err, reply )
		self:emit( "DataPushed", reply )
	end )
end

function DataManager:pop( key )
	self.redis:rpop( key, function( err, reply )
		self:emit( "DataPopped", reply )
	end )
end

function DataManager:range( key, start, stop )
	self.redis:lrange( key, start, stop, function( err, reply )
		self:emit( "DataRange", reply )
	end )
end

function DataManager:clear( key )
	self.redis:del( key, function( err, reply )
		self:emit( "DataListCleared", err )
	end )
end

function DataManager:clearDb()
	self.redis:flushall()
end

return DataManager
