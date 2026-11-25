-- Заглушка PlayerAnimator для fxsim: только hitStop (пишет в журнал).
return {
	hitStop = function(duration)
		table.insert(__SIM.hitStops, { t = __VT(), d = duration })
	end,
}
