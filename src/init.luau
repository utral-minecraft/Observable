local Observable = {}
Observable.ClassName = "Observable"
Observable.__index = Observable

local Subscription = require(script.Subscription)

local TypeUtils = require(script.TypeUtils)
local ENABLE_STACK_TRACING = false

function Observable.isObservable(value) : boolean
	return TypeUtils.isImplementation(Observable,value)
end

function Observable.new(subscriber)
	assert(typeof(subscriber) == "function", "Observable.new: bad subsriber")
	local self = setmetatable({
		_source = ENABLE_STACK_TRACING or debug.traceback() or "",
		_subscriber = subscriber
	}, Observable)
	return self
end

function Observable:Pipe(transformers: {()->any})
	assert(typeof(transformers) == "table", "Observable:Pipe: bad transformers")
	
	local current = self
	for _,transformer in transformers do
		assert(typeof(transformer) == "function", "Observable:Pipe - In loop: bad transformer")
		current = transformer(current)
		assert(Observable.isObservable(current), "Observable:Pipe - Last of loop: transformer must return an obseravable")
	end
	return current
end


function Observable:Subscribe(fireCallback, failCallback, completeCallback)
	local sub = Subscription.new(fireCallback,failCallback,completeCallback,self._source)
	sub:_assignCleanup(self._subscriber(sub))
	return sub
end

return Observable