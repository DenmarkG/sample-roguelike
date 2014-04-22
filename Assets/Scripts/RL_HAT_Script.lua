--Animation script event functions

function OnIdleToRun()
	hkbFireEvent("MoveStart")
end

function OnRunToIdle()
	hkbFireEvent("MoveStop")
end

function OnAttack()
	hkbFireEvent("Attack")
end