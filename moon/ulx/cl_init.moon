print "ULX v#{ulx.VERSION} loading client-side..."

ulx.CoreConfig = Config "client"
ulx.CoreConfig\LoadAndUseDefaults
	Language: ""

rcvUlxCmd = (len using net) ->
	cmd = net.ReadString()
	switch cmd
		when "start"
			print "Instructed to boot ULX" -- TODO

		else
			print "Unknown command! " .. cmd -- TODO, better error handling
net.Receive(ulx.NET_CMDS, rcvUlxCmd)
