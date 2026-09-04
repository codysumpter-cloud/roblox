--!strict
return {
	dayDurationSeconds = 12 * 60,
	startingClockTime = 8,
	transitionSeconds = 12,
	weatherSequence = {
		{ name = "Clear", duration = 150 }, { name = "Cloudy", duration = 45 },
		{ name = "Rain", duration = 75 }, { name = "Clear", duration = 150 },
		{ name = "Storm", duration = 45 },
	},
	weather = {
		Clear = { atmosphereDensity = 0.24, haze = 1.1, brightness = 2.35, cloudCover = 0.18, cloudDensity = 0.22 },
		Cloudy = { atmosphereDensity = 0.36, haze = 1.7, brightness = 1.9, cloudCover = 0.62, cloudDensity = 0.48 },
		Rain = { atmosphereDensity = 0.46, haze = 2.15, brightness = 1.55, cloudCover = 0.82, cloudDensity = 0.62 },
		Storm = { atmosphereDensity = 0.58, haze = 2.8, brightness = 1.05, cloudCover = 0.96, cloudDensity = 0.78 },
	},
}
