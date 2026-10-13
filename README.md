# xSun

A watchOS app that shows where the sun is and where it's going, based on your location.

## Features

- **Phase**: sunrise, sunset and solar noon times, the sun's current position on its daily arc, and its current irradiance.
- **Direction**: a compass view that points toward the sun and shows the sunrise and sunset azimuths.
- **Time travel**: turn the Digital Crown to scrub forward or backward in time and see where the sun will be.

## Requirements

- Xcode with the watchOS SDK
- watchOS 11.6 or later
- Location permission (used to calculate sun position)

## Build and run

1. Open `xSun.xcodeproj` in Xcode.
2. Let Xcode resolve the Swift package dependencies.
3. Select the `xSun Watch App` scheme and a watchOS simulator or paired Apple Watch.
4. Press Run.

## Dependencies

- [Solar](https://github.com/ceeK/Solar) for sunrise, sunset and solar position calculations.

## Project layout

- `RootView.swift`: top-level navigation
- `PhaseView.swift`: sun phase and arc view
- `DirectionView.swift`: compass and direction view
- `SunManager.swift`: location and solar calculations
