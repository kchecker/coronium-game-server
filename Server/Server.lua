--======================================================================--
--== Coronium GS Server
--== @copyright Chris Byerley @develephant
--== @year 2014
--== @version 1
--== @license Apache License 2.0
--======================================================================--
local Emitter = require( 'core' ).Emitter

local net = require( 'net' )
local utils = require( 'utils' )

--== Catch main process errors
process:on( "error", function( e )
	p( "Process Error", e )
end )
--======================================================================--
--== Server Class
--======================================================================--
local Server = Emitter:extend()
function Server:initialize( port )
	self.port = port
	self.ns = nil --== net.Server instance
end
--======================================================================--
--== Server handlers
--======================================================================--
function Server:handleClient( client )
	self:emit( "ClientConnect", client )
end

function Server:handleListen()
	self:emit( "ServerListen", "Listening on port " .. self.port )
end

function Server:handleClose( )
	p( "Server Closed" )
end

function Server:handleError( e )
	p( "Sever Error", e )
end
--======================================================================--
--== Server Connect
--======================================================================--
function Server:connect()

	self.ns = net.createServer()

	--== Start listening
	self.ns:listen( self.port, utils.bind( Server.handleListen, self ) )

	--== Server connection (client)
	self.ns:on( "connection", utils.bind( Server.handleClient, self ) )

	--== Server Close
	self.ns:on( "close", utils.bind( Server.handleClose, self) )

	--== Server Error
	self.ns:on( "error", utils.bind( Server.handleError, self ) )
end

--== Return Class
return Server
