import { request, json, buffer, respond, error, badRequest, notFound } from "./http"
import {
	usernameToUuid, uuidToProfile, uuidIsSlim, textureAlex, textureSteve, uuidSteve
} from "./mojang"

# Get the Uuid of a user given their name.
#
# @param {string} name - Minecraft username, must be alphanumeric 16 characters.
# @returns {promise<response>} - An error or a Uuid response as text.
export uuid = (name) ->
	unless name.asUsername()
		return badRequest("Invalid format for the name '#{name}'")
	unless id = await NAMES.get(name.toLowerCase(), "text")
		unless response = await usernameToUuid(name)
			return notFound("No user with the name '#{name}' was found")
		id = response.id?.asUuid({ dashed: true })
		await NAMES.put(name.toLowerCase(), id, { expirationTtl: 60 * 5 })
	respond(id, { text: true })

# Get the profile of a user given their Uuid or name.
#
# @param {string} id - Uuid or Minecraft username.
# @returns {promise<response>} - An error or a profile response as Json.
export user = (id) ->
	if id.asUsername()
		if (response = await uuid(id)).ok
			response = user(await response.text())
			return response
	unless id.asUuid()
		return badRequest("Invalid format for the UUID '#{id}'")
	if response = await USERS.get(id.asUuid({ dashed: true }), "json")
		return respond(response, { json: true })
	profile = await uuidToProfile(id = id.asUuid())
	unless profile
		return notFound("No user with the UUID '#{id}' was found")
	texturesRaw = profile.properties?.filter((item) -> item.name == "textures")[0] || {}
	textures = JSON.parse(atob(texturesRaw?.value || btoa("{}"))).textures || {}
	unless textures.isEmpty()
		skin = await buffer(skinUrl) if skinUrl = textures.SKIN?.url
	unless skin
		[type, skin] = if uuidIsSlim(id) then ["alex", textureAlex] else ["steve", textureSteve]
		skinUrl = "http://assets.mojang.com/SkinTemplates/#{type}.png"
	response = {
		uuid: id = profile.id
		username: profile.name
		skin: {
			url: skinUrl
			data: skin
		}
	}
	respond(response, { json: true })

# Redirect to the avatar service to render the face of a user.
#
# @param {string} id - Uuid of the user.
# @returns {promise<response>} - Avatar response as a png.
export avatar = (id) ->
	if !id.asUsername() && !id.asUuid()
		return avatar(uuidSteve)
	unless png = await AVATARS.get(id.toLowerCase(), "text")
		profile = await json(user(id))
		png = profile.skin.data

		fs = require 'fs'
		readable = require('stream').Readable
		imgBuffer = Buffer.from(base64, 'base64')
		s = new Readable()
		s.push(imgBuffer)
		s.push(null)
		s.pipe(fs.createWriteStream("test.png"))
		png = s

		if id != uuidSteve
			options = { expirationTtl: 60 * 60 }
		await AVATARS.put(id.toLowerCase(), png, options)
	respond(png, { png: true })
