export type Subscription = {
	Fire: any,
	Fail: () -> (),
	GetFireFailComplete: () -> any,
	GetFailComplete: () -> any,
	Complete: () -> (),
	IsPending: () -> boolean,
	Destroy: () -> ()
}

local Subscription = {}
Subscription.ClassName = "Subscription"
Subscription.__index = Subscription

local Janitor = require(script.Janitor)

local StateTypes = {
	PENDING = "pending",
	FAILED = "failed",
	COMPLETE = "complete",
	CANCELLED = "cancelled"
}

local DebugMsg = {
	fireCallback = "Subscription.new: bad fireCallback",
	failCallback = "Subscription.new: bad failCallback",
	completeCallback = "Subscription.new: bad completeCallback"
}

local ENABLE_STACK_TRACING = false

function Subscription.new(fireCallback, failCallback, completeCallback, observableSource)
	assert(typeof(fireCallback) == "function" or fireCallback == nil, DebugMsg.fireCallback)
	assert(typeof(failCallback) == "function" or failCallback == nil, DebugMsg.failCallback)
	assert(typeof(completeCallback) == "function" or completeCallback == nil, DebugMsg.completeCallback)
	
	return setmetatable({
		_state = StateTypes.PENDING,
		_source = ENABLE_STACK_TRACING and debug.traceback() or "",
		_observableSource = observableSource,
		_fireCallback = fireCallback,
		_failCallback = failCallback,
		_completeCallback = completeCallback
	}, Subscription) :: Subscription
end

function Subscription:Fire(...)
	if self._state == StateTypes.PENDING then
		if self._fireCallback then
			self._fireCallback(...)
		end
	elseif self._state == StateTypes.CANCELLED then
		warn("Subscription:Fire(...): Subscription is cancelled. Events are still being pushed")
		if ENABLE_STACK_TRACING then
			print(debug.traceback())
			print(self._source)
			print(self._observableSource)
		end
	end
end

function Subscription:Fail()
	if self._state ~= StateTypes.PENDING then
		return
	end
	
	self._state = StateTypes.FAILED
	
	if self._failCallback then
		self._failCallback()
	end
	
	self:_cleanUp()
end

function Subscription:GetFireFailComplete()
	return function(...)
		self:Fire(...)
	end, function(...)
		self:Fail(...)
	end, function(...)
		self:Complete(...)
	end
end

function Subscription:GetFailComplete()
	return function(...)
		self:Fail(...)
	end, function(...)
		self:Complete(...)
	end
end

function Subscription:Complete()
	if self._state ~= StateTypes.PENDING then
		return
	end

	self._state = StateTypes.COMPLETE
	if self._completeCallback then
		self._completeCallback()
	end

	self:_cleanUp()
end

function Subscription:IsPending()
	return self._state == StateTypes.PENDING
end

function Subscription:_assignCleanup(Task)
	assert(not self._cleanupTask, "Subscription:_assignCleanup: Already have a task to clean")
	
	if Task then
		if self._state ~= StateTypes.PENDING then
			local j = Janitor.new()
			j:Add(Task)
			j:Destroy()
			return
		end
		
		self._cleanupTask = Task
	end
end

function Subscription:_cleanUp()
	if self._cleanupTask then
		local Task = self._cleanupTask
		self._cleanupTask = nil
		local j = Janitor.new()
		j:Add(self._cleanupTask)
		j:Destroy()
	end
end

function Subscription:Destroy()
	if self._state == StateTypes.PENDING then
		self._state = StateTypes.CANCELLED
	end
	
	self:_cleanUp()
end

Subscription.Disconnect = Subscription.Destroy

return Subscription