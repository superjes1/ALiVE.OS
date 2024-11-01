#include "\x\alive\addons\mil_command\script_component.hpp"
SCRIPT(SeaPatrol);

/* ----------------------------------------------------------------------------
Function: ALIVE_fnc_SeaPatrol

Description:
Ambient sea patrol movement command

Parameters:
Profile - profile
Args - array (SCALAR - radius, STRING - behaviour, ARRAY - objective pos)

Returns:

Examples:
(begin example)
[_profile, [1000, "SAFE", _objective]] call ALiVE_fnc_seaPatrol;
(end)

See Also:

Author:
Tupolov
---------------------------------------------------------------------------- */
private ["_profile","_params","_startPos","_type","_speed","_formation","_behaviour","_profileWaypoint","_vehiclesInCommandOf","_radius","_debug","_objective","_isDiverTeam","_debugColor","_profileSide"];

_profile = _this select 0;
_params = _this select 1;

_debug = false;

if (isnil "_profile") exitWith {};

private _profileID = [_profile,"profileID"] call ALiVE_fnc_HashGet;
_startPos = [_profile,"position"] call ALiVE_fnc_HashGet;
_profileSide = [_profile,"side"] call ALIVE_fnc_hashGet;

if (_debug) then {
    ["SEA PATROL - Starting Sea Patrol for: %1 on water (%3) with params: %2",  _profileID, _params, surfaceIsWater _startPos] call ALiVE_fnc_dump;
};

//defaults
_type = "MOVE";
_speed = "LIMITED";
_formation = "COLUMN";

if (typename _params == "ARRAY") then {
    _radius = _params select 0;
    _behaviour = _params select 1;
    _objective = _params select 2;
} else {
    _radius = 1000;
    _behaviour = "AWARE";
    _objective = [_profile,"position"] call ALiVE_fnc_HashGet;
};


switch(_profileSide) do {
    case "EAST":{
        _debugColor = "ColorRed";
    };
    case "WEST":{
        _debugColor = "ColorBlue";
    };
    case "CIV":{
        _debugColor = "ColorYellow";
    };
    case "GUER":{
        _debugColor = "ColorGreen";
    };
    default {
        _debugColor = "ColorRed";
    };
};

// Ensure first start-WP is in water
if !(surfaceIsWater _startpos) then {

    _startPos = [_startPos, 10, 50, 10, 2, 5 , 0, [], [_startPos]] call BIS_fnc_findSafePos;

    if (_debug) then {
        ["SEA PATROL - Start-WP of Sea Patrol has not been in water! Switched position to be in water: %1 on water (%3) with params: %2",  _profileID, _params, surfaceIsWater _startPos] call ALiVE_fnc_dump;
    };
};

_profileWaypoint = [_startPos, 15, _type, _speed, 30, [], _formation, "NO CHANGE", _behaviour] call ALIVE_fnc_createProfileWaypoint;
[_profileWaypoint,"statements",["true","_disableSimulation = true;"]] call ALIVE_fnc_hashSet;
[_profile, "addWaypoint", _profileWaypoint] call ALIVE_fnc_profileEntity;

if (_debug) then {
    [str(random 1000), _startPos, "ICON",[1,1],"COLOR:","ColorGreen","TYPE:","mil_dot","TEXT:",format ["Marine-%1-START",[_profile,"profileID"] call ALIVE_fnc_hashGet]] call CBA_fnc_createMarker;
};

// Adjust patrol radius based on vehicle availability
_vehiclesInCommandOf = [_profile,"vehiclesInCommandOf",[]] call ALIVE_fnc_HashGet;
if (count _vehiclesInCommandOf > 0) then {

     _radius = 1000;
     _isDiverTeam = false;
} else { // Diver Team - get them to visit the objective too.

    _radius = 500;
    _speed = "NORMAL";
    _isDiverTeam = true;

    // Add the objective location as one of the first waypoints
    _profileWaypoint = [_objective, 15, _type, _speed, 100, [], _formation, "NO CHANGE", _behaviour] call ALIVE_fnc_createProfileWaypoint;
    [_profileWaypoint,"statements",["true","_disableSimulation = true;"]] call ALIVE_fnc_hashSet;
    [_profile, "addWaypoint", _profileWaypoint] call ALIVE_fnc_profileEntity;

    if (_debug  && count ([_profile,"waypoints",[]] call ALiVE_fnc_HashGet) < 5) then {
        [str(random 1000), _objective, "ICON",[1,1],"COLOR:",_debugColor,"TYPE:","mil_dot","TEXT:",format ["Marine-%1-%2",[_profile,"profileID"] call ALIVE_fnc_hashGet, count ([_profile,"waypoints",[]] call ALiVE_fnc_HashGet)]] call CBA_fnc_createMarker;
    };
};

// Find other waypoints in the sea
while {count ([_profile,"waypoints",[]] call ALiVE_fnc_HashGet) < 5} do {

    private ["_lastpos","_profileWaypoint","_gpos"];
    private _last = false;

    if (isNil "_gpos") then {
        _lastpos = +_startPos;
    } else {
        _lastpos = +_gpos;
    };

    // Find a new position in the sea (doesn't have to be closest)
    _gpos = [_startPos, false] call ALiVE_fnc_getClosestSea;

    if !(surfaceIsWater _gpos) then {

        if (_debug) then {
            ["SEA PATROL - ALERT NON WATER INITIAL POSITION Pos: %1 - On Water: %2",  _gpos, surfaceIsWater _gpos] call ALiVE_fnc_dump;
        };

        // Find a position that is definitely in water
        _gpos = [_gpos, 15, _radius, 20, 2, 10, 0, [], [_startPos,_startPos]] call bis_fnc_findSafePos;

        // Add 3rd element because BIS_fnc_findSafePos returns an array of 2 elements...
        _gpos set [2, 0];
    };

    // if its still not water, then go back to start position.
    if !(surfaceIsWater _gpos) then {
        _gpos = +_startPos;
    };

    //Loop last Waypoint
    if (count ([_profile,"waypoints",[]] call ALiVE_fnc_HashGet) == 4) then {
        _gpos = +_startPos;
        _type = "CYCLE";
        _last = true;
    };

    if (surfaceIsWater _gpos || (_isDiverTeam && _last) ) then {

        // Check you don't have to cross land to get there in a boat
        if (!terrainIntersectASL [_lastpos,_gpos] || _isDiverTeam) then {

            _profileWaypoint = [_gpos, 15, _type, _speed, 100, [], _formation, "NO CHANGE", _behaviour] call ALIVE_fnc_createProfileWaypoint;
            [_profileWaypoint,"statements",["true","_disableSimulation = true;"]] call ALIVE_fnc_hashSet;
            [_profile, "addWaypoint", _profileWaypoint] call ALIVE_fnc_profileEntity;

            if (_debug  && count ([_profile,"waypoints",[]] call ALiVE_fnc_HashGet) < 5) then {
                [str(random 1000), _gpos, "ICON",[1,1],"COLOR:",_debugColor,"TYPE:","mil_dot","TEXT:",format ["Marine-%1-%2",[_profile,"profileID"] call ALIVE_fnc_hashGet, count ([_profile,"waypoints",[]] call ALiVE_fnc_HashGet)]] call CBA_fnc_createMarker;
            };
        } else {
            if (_debug) then {
                ["AMB SEA PATROL [WP] - ALERT WAYPOINT MUST CROSS LAND LastPos: %1 - New Pos: %2",  _lastpos, _gpos] call ALiVE_fnc_dump;
            };
        };

    } else {
        // start pos was not in water?
        if (_debug) then {
            ["AMB SEA PATROL [WP] - ALERT NON WATER FINAL POSITION Pos: %1 - On Water: %2",  _gpos, surfaceIsWater _gpos] call ALiVE_fnc_dump;
        };
        _radius = _radius * 1.1;

    };
};

if (_debug) then {
    ["%1 - Placing Sea Patrol: %2 at %3. On water: %4 with %5 waypoints",_profileSide, _profileID, _startPos, surfaceIsWater _startPos, count ([_profile,"waypoints",[]] call ALiVE_fnc_HashGet)] call ALiVE_fnc_dump;
};
