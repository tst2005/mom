do local sources, priorities = {}, {};assert(not sources["lube.tcp"])sources["lube.tcp"]=([===[-- <pack lube.tcp> --
local socket = require "socket"

--- CLIENT ---

local tcpClient = {}
tcpClient._implemented = true

function tcpClient:createSocket()
	self.socket = socket.tcp()
	self.socket:settimeout(0)
end

function tcpClient:_connect()
	self.socket:settimeout(5)
	local success, err = self.socket:connect(self.host, self.port)
	self.socket:settimeout(0)
	return success, err
end

function tcpClient:_disconnect()
	self.socket:shutdown()
end

function tcpClient:_send(data)
	return self.socket:send(data)
end

function tcpClient:_receive()
	local packet = ""
	local data, _, partial = self.socket:receive(8192)
	while data do
		packet = packet .. data
		data, _, partial = self.socket:receive(8192)
	end
	if not data and partial then
		packet = packet .. partial
	end
	if packet ~= "" then
		return packet
	end
	return nil, "No messages"
end

function tcpClient:setoption(option, value)
	if option == "broadcast" then
		self.socket:setoption("broadcast", not not value)
	end
end


--- SERVER ---

local tcpServer = {}
tcpServer._implemented = true

function tcpServer:createSocket()
	self._socks = {}
	self.socket = socket.tcp()
	self.socket:settimeout(0)
	self.socket:setoption("reuseaddr", true)
end

function tcpServer:_listen()
	self.socket:bind("*", self.port)
	self.socket:listen(5)
end

function tcpServer:send(data, clientid)
	-- This time, the clientip is the client socket.
	if clientid then
		clientid:send(data)
	else
		for sock, _ in pairs(self.clients) do
			sock:send(data)
		end
	end
end

function tcpServer:receive()
	for sock, _ in pairs(self.clients) do
		local packet = ""
		local data, _, partial = sock:receive(8192)
		while data do
			packet = packet .. data
			data, _, partial = sock:receive(8192)
		end
		if not data and partial then
			packet = packet .. partial
		end
		if packet ~= "" then
			return packet, sock
		end
	end
	for i, sock in pairs(self._socks) do
		local data = sock:receive()
		if data then
			local hs, conn = data:match("^(.+)([%+%-])\n?$")
			if hs == self.handshake and conn ==  "+" then
				self._socks[i] = nil
				return data, sock
			end
		end
	end
	return nil, "No messages."
end

function tcpServer:accept()
	local sock = self.socket:accept()
	while sock do
		sock:settimeout(0)
		self._socks[#self._socks+1] = sock
		sock = self.socket:accept()
	end
end

return {tcpClient, tcpServer}
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lube.udp"])sources["lube.udp"]=([===[-- <pack lube.udp> --
local socket = require "socket"

--- CLIENT ---

local udpClient = {}
udpClient._implemented = true

function udpClient:createSocket()
	self.socket = socket.udp()
	self.socket:settimeout(0)
end

function udpClient:_connect()
	-- We're connectionless,
	-- guaranteed success!
	return true
end

function udpClient:_disconnect()
	-- Well, that's easy.
end

function udpClient:_send(data)
	return self.socket:sendto(data, self.host, self.port)
end

function udpClient:_receive()
	local data, ip, port = self.socket:receivefrom()
	if ip == self.host and port == self.port then
		return data
	end
	return false, data and "Unknown remote sent data." or ip
end

function udpClient:setOption(option, value)
	if option == "broadcast" then
		self.socket:setoption("broadcast", not not value)
	end
end


--- SERVER ---

local udpServer = {}
udpServer._implemented = true

function udpServer:createSocket()
	self.socket = socket.udp()
	self.socket:settimeout(0)
end

function udpServer:_listen()
	self.socket:setsockname("*", self.port)
end

function udpServer:send(data, clientid)
	-- We conviently use ip:port as clientid.
	if clientid then
		local ip, port = clientid:match("^(.-):(%d+)$")
		self.socket:sendto(data, ip, tonumber(port))
	else
		for clientid, _ in pairs(self.clients) do
			local ip, port = clientid:match("^(.-):(%d+)$")
			self.socket:sendto(data, ip, tonumber(port))
		end
	end
end

function udpServer:receive()
	local data, ip, port = self.socket:receivefrom()
	if data then
		local id = ip .. ":" .. port
		return data, id
	end
	return nil, "No message."
end

function udpServer:accept()
end


return {udpClient, udpServer}
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lube.core"])sources["lube.core"]=([===[-- <pack lube.core> --
--- CLIENT ---

local client = {}
-- A generic client class
-- Implementations are required to implement the following functions:
--  * createSocket() --> Put a socket object in self.socket
--  * success, err = _connect() --> Connect the socket to self.host and self.port
--  * _disconnect() --> Disconnect the socket
--  * success, err = _send(data) --> Send data to the server
--  * message, err = _receive() --> Receive a message from the server
--  * setOption(option, value) --> Set a socket option, options being one of the following:
--      - "broadcast" --> Allow broadcast packets.
-- And they also have to set _implemented to evaluate to true.
--
-- Note that all implementations should have a 0 timeout, except for connecting.

function client:init()
	assert(self._implemented, "Can't use a generic client object directly, please provide an implementation.")
	-- 'Initialize' our variables
	self.host = nil
	self.port = nil
	self.connected = false
	self.socket = nil
	self.callbacks = {
		recv = nil
	}
	self.handshake = nil
	self.ping = nil
end

function client:setPing(enabled, time, msg)
	-- If ping is enabled, create a self.ping
	-- and set the time and the message in it,
	-- but most importantly, keep the time.
	-- If disabled, set self.ping to nil.
	if enabled then
		self.ping = {
			time = time,
			msg = msg,
			timer = time
		}
	else
		self.ping = nil
	end
end

function client:connect(host, port, dns)
	-- Verify our inputs.
	if not host or not port then
		return false, "Invalid arguments"
	end
	-- Resolve dns if needed (dns is true by default).
	if dns ~= false then
		local ip = socket.dns.toip(host)
		if not ip then
			return false, "DNS lookup failed for " .. host
		end
		host = ip
	end
	-- Set it up for our new connection.
	self:createSocket()
	self.host = host
	self.port = port
	-- Ask our implementation to actually connect.
	local success, err = self:_connect()
	if not success then
		self.host = nil
		self.port = nil
		return false, err
	end
	self.connected = true
	-- Send our handshake if we have one.
	if self.handshake then
		self:send(self.handshake .. "+\n")
	end
	return true
end

function client:disconnect()
	if self.connected then
		self:send(self.handshake .. "-\n")
		self:_disconnect()
		self.host = nil
		self.port = nil
	end
end

function client:send(data)
	-- Check if we're connected and pass it on.
	if not self.connected then
		return false, "Not connected"
	end
	return self:_send(data)
end

function client:receive()
	-- Check if we're connected and pass it on.
	if not self.connected then
		return false, "Not connected"
	end
	return self:_receive()
end

function client:update(dt)
	if not self.connected then return end
	assert(dt, "Update needs a dt!")
	-- First, let's handle ping messages.
	if self.ping then
		self.ping.timer = self.ping.timer + dt
		if self.ping.timer > self.ping.time then
			self:_send(self.ping.msg)
			self.ping.timer = 0
		end
	end
	-- If a recv callback is set, let's grab
	-- all incoming messages. If not, leave
	-- them in the queue.
	if self.callbacks.recv then
		local data, err = self:_receive()
		while data do
			self.callbacks.recv(data)
			data, err = self:_receive()
		end
	end
end


--- SERVER ---

local server = {}
-- A generic server class
-- Implementations are required to implement the following functions:
--  * createSocket() --> Put a socket object in self.socket.
--  * _listen() --> Listen on self.port. (All interfaces.)
--  * send(data, clientid) --> Send data to clientid, or everyone if clientid is nil.
--  * data, clientid = receive() --> Receive data.
--  * accept() --> Accept all waiting clients.
-- And they also have to set _implemented to evaluate to true.
-- Note that all functions should have a 0 timeout.

function server:init()
	assert(self._implemented, "Can't use a generic server object directly, please provide an implementation.")
	-- 'Initialize' our variables
	-- Some more initialization.
	self.clients = {}
	self.handshake = nil
	self.callbacks = {
		recv = nil,
		connect = nil,
		disconnect = nil,
	}
	self.ping = nil
	self.port = nil
end

function server:setPing(enabled, time, msg)
	-- Set self.ping if enabled with time and msg,
	-- otherwise set it to nil.
	if enabled then
		self.ping = {
			time = time,
			msg = msg
		}
	else
		self.ping = nil
	end
end

function server:listen(port)
	-- Create a socket, set the port and listen.
	self:createSocket()
	self.port = port
	self:_listen()
end

function server:update(dt)
	assert(dt, "Update needs a dt!")
	-- Accept all waiting clients.
	self:accept()
	-- Start handling messages.
	local data, clientid = self:receive()
	while data do
		local hs, conn = data:match("^(.+)([%+%-])\n?$")
		if hs == self.handshake and conn == "+" then
			-- If we already knew the client, ignore.
			if not self.clients[clientid] then
				self.clients[clientid] = {ping = -dt}
				if self.callbacks.connect then
					self.callbacks.connect(clientid)
				end
			end
		elseif hs == self.handshake and conn == "-" then
			-- Ignore unknown clients (perhaps they timed out before?).
			if self.clients[clientid] then
				self.clients[clientid] = nil
				if self.callbacks.disconnect then
					self.callbacks.disconnect(clientid)
				end
			end
		elseif not self.ping or data ~= self.ping.msg then
			-- Filter out ping messages and call the recv callback.
			if self.callbacks.recv then
				self.callbacks.recv(data, clientid)
			end
		end
		-- Mark as 'ping receive', -dt because dt is added after.
		-- (Which means a net result of 0.)
		if self.clients[clientid] then
			self.clients[clientid].ping = -dt
		end
		data, clientid = self:receive()
	end
	if self.ping then
		-- If we ping then up all the counters.
		-- If it exceeds the limit we set, disconnect the client.
		for i, v in pairs(self.clients) do
			v.ping = v.ping + dt
			if v.ping > self.ping.time then
				self.clients[i] = nil
				if self.callbacks.disconnect then
					self.callbacks.disconnect(i)
				end
			end
		end
	end
end

return {client, server}
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lube.enet"])sources["lube.enet"]=([===[-- <pack lube.enet> --
local enet = require "enet"

--- CLIENT ---

local enetClient = {}
enetClient._implemented = true

function enetClient:createSocket()
	self.socket = enet.host_create()
	self.flag = "reliable"
end

function enetClient:_connect()
	self.socket:connect(self.host .. ":" .. self.port)
	local t = self.socket:service(5000)
	local success, err = t and t.type == "connect"
	if not success then
		err = "Could not connect"
	else
		self.peer = t.peer
	end
	return success, err
end

function enetClient:_disconnect()
	self.peer:disconnect()
	return self.socket:flush()
end

function enetClient:_send(data)
	return self.peer:send(data, 0, self.flag)
end

function enetClient:_receive()
	return (self.peer:receive())
end

function enetClient:setoption(option, value)
	if option == "enetFlag" then
		self.flag = value
	end
end

function enetClient:update(dt)
	if not self.connected then return end
	if self.ping then
		if self.ping.time ~= self.ping.oldtime then
			self.ping.oldtime = self.ping.time
			self.peer:ping_interval(self.ping.time*1000)
		end
	end

	while true do
		local event = self.socket:service()
		if not event then break end

		if event.type == "receive" then
			if self.callbacks.recv then
				self.callbacks.recv(event.data)
			end
		end
	end
end


--- SERVER ---

local enetServer = {}
enetServer._implemented = true

function enetServer:createSocket()
	self.connected = {}
end

function enetServer:_listen()
	self.socket = enet.host_create("*:" .. self.port)
end

function enetServer:send(data, clientid)
	if clientid then
		return self.socket:get_peer(clientid):send(data)
	else
		return self.socket:broadcast(data)
	end
end

function enetServer:receive()
	return (self.peer:receive())
end

function enetServer:accept()
end

function enetServer:update(dt)
	if self.ping then
		if self.ping.time ~= self.ping.oldtime then
			self.ping.oldtime = self.ping.time
			for i = 1, self.socket:peer_count() do
				self.socket:get_peer(i):timeout(5, 0, self.ping.time*1000)
			end
		end
	end

	while true do
		local event = self.socket:service()
		if not event then break end

		if event.type == "receive" then
			local hs, conn = event.data:match("^(.+)([%+%-])\n?$")
			local id = event.peer:index()
			if hs == self.handshake and conn == "+" then
				if self.callbacks.connect then
					self.connected[id] = true
					self.callbacks.connect(id)
				end
			elseif hs == self.handshake and conn == "-" then
				if self.callbacks.disconnect then
					self.connected[id] = false
					self.callbacks.disconnect(id)
				end
			else
				if self.callbacks.recv then
					self.callbacks.recv(event.data, id)
				end
			end
		elseif event.type == "disconnect" then
			local id = event.peer:index()
			if self.connected[id] and self.callbacks.disconnect then
				self.callbacks.disconnect(id)
			end
			self.connected[id] = false
		elseif event.type == "connect" and self.ping then
			event.peer:timeout(5, 0, self.ping.time*1000)
		end
	end
end

return {enetClient, enetServer}
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
local add
if not pcall(function() add = require"aioruntime".add end) then
        local loadstring=loadstring; local preload = require"package".preload
        add = function(name, rawcode)
		if not preload[name] then
		        preload[name] = function(...) return loadstring(rawcode)(...) end
		else
			print("WARNING: overwrite "..name)
		end
        end
end
for name, rawcode in pairs(sources) do add(name, rawcode, priorities[name]) end
end;
-- Get our base modulename, to require the submodules
local modulename = ...
--modulename = modulename:match("^(.+)%.init$") or modulename
modulename = "lube"

local function subrequire(sub)
	return unpack(require(modulename .. "." .. sub))
end

-- Common Class fallback
local fallback = {}
function fallback.class(_, table, parent)
	parent = parent or {}

	local mt = {}
	function mt:__index(name)
		return table[name] or parent[name]
	end
	function mt:__call(...)
		local instance = setmetatable({}, mt)
		instance:init(...)
		return instance
	end

	return setmetatable({}, mt)
end

-- Use the fallback only if not other class
-- commons implemenation is defined

--local common = fallback
--if _G.common and _G.common.class then
--	common = _G.common
--end
local common = require "featured" "class"

local lube = {}

-- All the submodules!
local client, server = subrequire "core"
lube.Client = common.class("lube.Client", client)
lube.Server = common.class("lube.Server", server)

local udpClient, udpServer = subrequire "udp"
lube.udpClient = common.class("lube.udpClient", udpClient, lube.Client)
lube.udpServer = common.class("lube.udpServer", udpServer, lube.Server)

local tcpClient, tcpServer = subrequire "tcp"
lube.tcpClient = common.class("lube.tcpClient", tcpClient, lube.Client)
lube.tcpServer = common.class("lube.tcpServer", tcpServer, lube.Server)

-- If enet is found, load that, too
if pcall(require, "enet") then
	local enetClient, enetServer = subrequire "enet"
	lube.enetClient = common.class("lube.enetClient", enetClient, lube.Client)
	lube.enetServer = common.class("lube.enetServer", enetServer, lube.Server)
end

return lube
