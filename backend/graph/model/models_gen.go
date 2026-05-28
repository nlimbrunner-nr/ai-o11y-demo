package model

type User struct {
	Email   string   `json:"email"`
	Name    string   `json:"name"`
	Vehicle *Vehicle `json:"vehicle"`
}

type Vehicle struct {
	ID              string  `json:"id"`
	Model           string  `json:"model"`
	BatteryLevel    int     `json:"batteryLevel"`
	RangeKm         int     `json:"rangeKm"`
	TotalKm         int     `json:"totalKm"`
	NextServiceKm   int     `json:"nextServiceKm"`
	TirePressure    float64 `json:"tirePressure"`
	SoftwareVersion string  `json:"softwareVersion"`
	IsLocked        bool    `json:"isLocked"`
	LastUpdated     string  `json:"lastUpdated"`
}
