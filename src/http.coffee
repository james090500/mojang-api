util = require("./util")

# Send a HTTP request.
#
# @param {string} url - URL to send the request.
# @param {string} method - HTTP method to use (GET, POST, etc).
# @param {integer} ttl - Time in seconds for Cloudflare to cache requests.
# @param {object} extra - Extra parameters passed to fetch method.
# @returns {[err, json]} - An error or JSON from a 200 status code.
request = (url, method, {ttl, extra} = {}) ->
  ttl ?= 60
  extra ?= {}
  response = await fetch(url, {
    method: method,
    cf: {cacheTtl: ttl} if ttl > 0,
    headers: {"Content-Type": "application/json"}
  }.merge(extra))
  if err = coerce(response.status)
    [err, null]
  else
    [null, try JSON.parse(await response.text()) catch err then null]

# Send a GET HTTP request.
#
# @see #request(url, method, ttl, extra)
get = (url, options = {}) ->
  request(url, "GET", options)

# Send a POST HTTP request.
#
# @see #request(url, method, ttl, extra)
post = (url, json, options = {}) ->
  request(url, "POST", {extra: {body: JSON.stringify(json)}}.merge(options))

# Respond to a HTTP request from a client.
#
# This only creates the response, the implementation
# is responsible for sending this to the client.
#
# @param {json} json - JSON payload sent back to the client.
# @param {integer} code - HTTP status code.
# @returns {response} - Encapsulated response object, not yet sent.
respond = (json, code) ->
  new Response(
    JSON.stringify(json, null, 2),
    {status: code, headers: {"Content-Type": "application/json"}}
  )

# Respond to a HTTP request with a successful JSON response.
#
# @see #respond(json, code)
ok = (json) ->
  respond(json, 200)

# Respond to a HTTP request with an error.
#
# @see #respond(json, code)
error = (code = 500, message = "Internal Error", reason = null) ->
  respond({status: code, message: message + (if reason then " - #{reason}" else "")}, code)

notFound = (msg = null) ->
  error(404, "Not Found", msg)

invalidRequest = (msg = null) ->
  error(400, "Invalid Request", msg)

tooManyRequests = (msg = null) ->
  error(429, "Too Many Requests", msg)

# Convert an upstream HTTP status code to a new error response.
#
# @param {integer} code - HTTP status code.
# @returns {response|null} - An error response or null.
coerce = (code) ->
  switch
    when 200 then null
    when 204 then notFound()
    when 400 then invalidRequest()
    when 429 then tooManyRequests()
    else error()

module.exports = {
  get
  post
  ok
  notFound
  invalidRequest
  tooManyRequests
}
