# Hubot dependencies
{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = require (process.env.HUBOT_HALL_REQUIRE_PATH || 'hubot')

# Hall dependencies
hall = 			require 'hall-client'
_ = 			require 'underscore'
debug = 		require('debug')('hubot:hall')
pjson = 		require('../package.json')

class Hall extends Adapter
	decodeRoom: (room) ->
		#for hall, rooms should be of the form "#{room_type}-#{room_id}", so just split it up
		res = room.split "-"
		room_type	:	res[0]
		room_id		:	res[1]

	encodeRoom: (room_type, room_id) ->
		"#{room_type}-#{room_id}"

	send: (params, strings...) ->
		user = @userFromParams(params)
		room = @decodeRoom(user.room)
		@bot.sendMessage room.room_id, room.room_type, str for str in strings

	reply: (params, strings...) ->
		user = @userFromParams(params)
		strings.forEach (str) =>
			@send params, "@#{user.name}: #{str}"

	userFromParams: (params) ->
		# hubot < 2.4.2: params = user
		# hubot >= 2.4.2: params = {user: user, ...}
		if params.user then params.user else params

	connect: ->

		debug "hubot-hall is trying to connect to the streaming api.............."

		@io = @bot.io

		onRoomItemNew = (data) =>
			data = JSON.parse(data)
			unless !data
				author =
					id: data.agent._id
					name: data.agent.display_name
					room: @encodeRoom((!data.participants) && 'group' || null, data.room_id)
				return if @bot.session.get('_id') == author.id || !data.message || !data.message.plain

				#Store the user if we haven't already
				console.log "#{author.id}, #{author.name}"


				regex_bot_name = new RegExp("^@?#{@robot.name}(,|\\b)", "i")
				regex_user_name = new RegExp("^@?#{@bot.session.get 'display_name'}(,|\\b)", "i")
				message = data.message.plain
				if message.match(regex_bot_name)
					message = message.replace(regex_bot_name, "#{@robot.name}:")
				else if message.match(regex_user_name)
					message = message.replace(regex_user_name, "#{@robot.name}:")
				@receive new TextMessage(author, message)

		@io.on 'ROOM_ITEM_NEW', onRoomItemNew

	run: ->

		cfg =
			email:		process.env.HUBOT_HALL_EMAIL
			password:	process.env.HUBOT_HALL_PASSWORD
			ua:
				meta: 	'Hall-Hubot-Adapter/'+pjson.version

		unless cfg.email and cfg.password
			console.error "ERROR: No credentials in environment variables HUBOT_HALL_EMAIL and HUBOT_HALL_PASSWORD"
			@emit "error", "No credentials"

		@bot = new hall(cfg)

		@connect()

		@emit 'connected'

exports.use = (robot) ->
	new Hall robot