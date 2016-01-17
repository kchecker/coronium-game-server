#Client-Side Development (alpha 2)#

##Getting Started##

###Spin Up An Instance###

You can currently run __Coronium GS__ via an Amazon AMI, or Ubuntu 14.04 64bit based install.  [DigitalOcean](https://www.digitalocean.com/?refcode=cddeeddbbdb8) is the recommended cloud provider for Ubuntu based instances.

The most current installation options can be found at the [Coronium GS](http://coronium.gs) site.

*See also: [Server side development](http://coronium.gs/server/topics/development.md.html)*

###Download the source###

Visit the bitbucket repo to [download the latest development bundle](https://bitbucket.org/develephant/coronium-gs-bundle) for __Coronium GS__.

##Overview: main.lua##

The __main.lua__ file that is included in the download (Client/main.lua) represents a template with all the possible client events included (see also: `main-tpl.lua`).  The file is more of a reference -- study it -- you can use it to do development testing before creating your app within a [Composer](http://docs.coronalabs.com/api/library/composer/index.html) based structure.

For a full listing of client events you can listen for see: [Client-side Events](http://coronium.gs/client/modules/CoroniumGSClient.html#Events)

At the very minimum, you need to require the __Coronium GS__ Client into your file:

    local gs = require( 'gs.CoroniumGSClient' ):new()

##Connections##

###Connecting###

Open the __Client/main.lua__ and enter your __Coronium GS__ information at the bottom of the file, in a [connection_table](http://coronium.gs/client/modules/CoroniumGSClient.html#connection_table):

    local connection =
    {
        host = 'your.gs.instance',
        port = 7173,
        handle = 'SuperUser',
        data = { facebookId = "123-books" },
        key = 'abc',
        ping = true
    }
    gs:connect( connection )

For more information on the connect method see the [connect](http://coronium.gs/client/modules/CoroniumGSClient.html#connect).

###Reconnecting###

To reconnect to the server, prehaps after a game has ended, or the client has dropped off for some reason, use the [reconnect](http://coronium.gs/client/modules/CoroniumGSClient.html#reconnect) client method.

For example, to reconnect on a 'game done' event:

    local function onClientData( event )
    	if event.data.game_done then --custom msg from server
    	  gs:reconnect()
    	end
    end
    gs.events:on( "ClientData", onClientData )

##Messaging##

The __Coronium GS__ model is built around messaging events.  To send a message to the server, you use the [send](http://coronium.gs/client/modules/CoroniumGSClient.html#send) method:

    local function onClientData( event )
      gs:send( { msg = "Hello server" } )
    end
    gs.events:on( "ClientData", onClientData )

The messaging protocol is completely up to you.  Just be sure to wrap the data up in a table and then send it with the __send__ method.

##Events##

__Coronium GS__ is an event driven system.  You listen for specific events and then perform some action depending on the data passed into these events. To listen for events, we need an event handler, and the listener.

###GameStart###

The [GameStart](http://coronium.gs/client/modules/CoroniumGSClient.html#GameStart) event is called all the players have connected together are ready to start the game.  We can listen for the event like so:

    local function onGameStart( event )
    	print( "game started!" )
    end
    gs.events:on( 'GameStart', onGameStart )

This event contains keyed data that we can use.  Some of the results passed back from the GameStart event are:

    local function onGameStart( event )
      local d = event.data

      local player_name = d.player_name -- The players name.
      local player_num = d.player_num -- The players position.
      local players_info = d.players_info -- An array of each players info.

      for _, player in ipairs( players_info ) do
         p( player.player_num .. ": " .. player.player_name )
      end
    end

    gs.events:on( "GameStart", onGameStart )

Use the [Pretty Print](http://coronium.gs/client/topics/development.md.html#Pretty_Print) to see the exact results.

###ClientData###

The 'work horse' of __Coronium GS__, the [ClientData](http://coronium.gs/client/modules/CoroniumGSClient.html#ClientData) event is called when the client has recieved data from the server.  You can capture and process this data to make your game do stuff.

    local function onClientData( event )
      if event.data.move_player then
      	player.x = event.data.x
      end
    end
    gs.events:on( "ClientData", onClientData )

###GameData###

The [GameData](http://coronium.gs/client/modules/CoroniumGSClient.html#GameData) event is another important event that delivers the current persistent 'game object'.

    local function onGameData( event )
      p( event.data )
    end
    gs.events:on( "GameData", onGameData )

You can also specifically call for the game data object with the __getData__ method:

    --== Set up the listener
    local function onGameData( event )
      p( event.data )
    end
    gs.events:on( "GameData", onGameData )

    --== Tell the server to send down data object
    gs:getData()

For a full listing of client events you can listen for see: [Client-side Events](http://coronium.gs/client/modules/CoroniumGSClient.html#Events)

###Custom Events###

The __Coronium GS__ Client comes packaged with the awesome [EventDispatcher](https://github.com/daveyang/EventDispatcher) module for Corona SDK.

You can use this module to create your own event emitters, just like the core __Coronium GS__ client module.

__my_module.lua__
    local dispatcher = require( 'gs.EventDispatcher' )
    local my_module = {}

    my_module.events = dispatcher()

    function my_module:doSomething()
      self.events:emit( "DidSomething", { msg = "Oops, I did it again." } )
    end

    return my_module

__other.lua__

    local my_module = require( 'my_module' )

    my_module.events:on( "DidSomething", function( event ) 
      print( event.data.msg )
    end)

    my_module:doSomething()

    --== Outputs: 'Oops, I did it again.'

##Player Names/Handles##

You can set a player name or "handle" in the [connection table](http://coronium.gs/client/modules/CoroniumGSClient.html#connection_table):

    local conn_tbl =
    {
    host = 'ping.coronium.gs',
    port = '7173',
    handle = 'Chris', -- Handle/Player Name
    key = 'abc'
    }
    gs:connect( conn_tbl )

The "handle" can be any string identifier you'd like, and can be accessed with the server-side [Client:getPlayerHandle](http://coronium.gs/server/modules/Client.html#getPlayerHandle), as well as the client-side [getPlayerHandle](http://coronium.gs/client/modules/CoroniumGSClient.html#getPlayerHandle).

On the server-side:

    local function onClientData( client, data )
      local handle = client:getPlayerHandle()
    end

On the client-side:

    local function onClientData( event )
      local handle = gs:getPlayerHandle()
    end

## Check Game State ##

You can check if the game is currently in a running state with the [isGameRunning](http://coronium.gs/client/modules/CoroniumGSClient.html#isGameRunning) method.

    local function checkGameState()
      return gs:isGameRunning() --true or false
    end

    if checkGameState() then
    	gs:send( { move = 1, pos = { 10, 10 } } )
    else
      print( "Game no longer running" )
    end

##Pretty Print##

The __Coronium GS__ client has a built in pretty printer for incoming table data.  This makes it real easy to visualize the incoming data for debugging purposes.  To simplify its usage, you can 'localize' it as the method __p__ -- which is the default on the server -- as follows:

    local gs = require( 'gs.CoroniumGSClient' ):new()
    local p = gs.p --== Pretty Printer

    --== General usage
    p( some_table_data )

    --== As debugging callback
    gs.events:on( "ClientData", p )
 
##Using Composer##

When using the __Coronium GS__ client in a [Composer](http://docs.coronalabs.com/api/library/composer/index.html) Corona SDK based project, you need to 'globalize' the module.

To see a working example, open the demo project in the [downloaded development bundle](https://bitbucket.org/develephant/coronium-gs-bundle) located in the __demos/GS Composer Starter__ directory.

## Demos ##

You can find a handful of demos in the [development bundle download](https://bitbucket.org/develephant/coronium-gs-bundle), in the __demos__ folder.  By studying those files, you can see more clearly how Coronium GS works in practice.

##Client Docs##

For a full listing of all available client methods and events, please see the [Client Side Documentation](http://coronium.gs/client/index.html).

##Support##

For support, tips, and community involvement, please visit the [Coronium Cloud Community](http://forums.coronium.io/categories/coronium-gs).

[Coronium GS](http://coronium.io/gs) &copy;2014 Chris Byerley [@develephant](http://twitter.com/develephant) | [develephant.net](http://develephant.net)
