import "./util"
import { error, notFound, cors } from "./http"
import { uuid, user, avatar } from "./api"

addEventListener("fetch", (event) ->
  event.respondWith(routeDebug(event.request)))

routeDebug = (request) ->
  try
    await route(request)
  catch err
    error(err.stack || err)

route = (request) ->
  [method, arg] = request.url.split("/")[3..6]
  if method? && arg?
    v2(method, arg)
  else
    notFound("Unknown route")

v2 = (method, arg) ->
  if method == "user"
    user(arg)
  else if method == "avatar"
    avatar(arg)
  else
    notFound("Unknown route")
