// Load the classname arrays
[] ExecVM "scripts\OpforUnits.sqf";

// Get a list of all triggers & define some default values.
AllTriggerNames = allMissionObjects "EmptyDetector";
MarkerNum = 0; 
GroupNum = 0; 
SubTriggerNum = 0; 

// Default value for list of active triggers
ActiveTriggerArray = []; 

// Default value for list of spawned groups
SpawnedEnemyGroupArray = []; 

// Draw markers for all of the triggers
{
	if !(vehicleVarName _x in FilterTriggerArray) then {

		// Autogenerate a numerically incrementing name for the trigger. 
		_ParentTriggerAutoName = Format["Trigger%1", MarkerNum];

		// Set trigger name
		_x setVehicleVarName _ParentTriggerAutoName;

		// Get trigger size
		_area = triggerArea _x; // result is [200, 120, 45, false]

		// Set marker name to something we can get from trigger name
		_markerObjName = Format["MarkerFor%1", vehicleVarName _x];

		// Create the damn marker
		createMarker[_markerObjName, getPos _x];
		_markerObjName setMarkerShape "RECTANGLE";
		_markerObjName setMarkerSize [_area select 0, _area select 1];
		_markerObjName setMarkerColor "ColorRed";
		_markerObjName setMarkerBrush "FDiagonal";
		MarkerNum = MarkerNum + 1; 

		// Create the SubTrigger Name
		_subTriggerName = Format["SubTrigger%1", SubTriggerNum];
		SubTriggerNum = SubTriggerNum + 1; 

		// Define the trigger actions
		_onTriggerAct = format["%1 = ['%2', '%3'] spawn makeMarkerBlink; ['%2', '%3', '%4', thisTrigger] spawn activateSector;", _threadName, _markerObjName, vehicleVarName _x, _subTriggerName];
		_onTriggerDeact = format["['%1','%2'] call makeMarkerSolid; [thisTrigger, '%3'] spawn cleanUpAbandonedSector;", vehicleVarName _x, _markerObjName, _subTriggerName];

		_x setTriggerActivation ["WEST", "PRESENT", true];
		_x setTriggerStatements ["this", _onTriggerAct, _onTriggerDeact];

	};
} forEach AllTriggerNames;

// Make the active marker blink, to show it is active
makeMarkerBlink = {
	
	// Get the params
 	_markerName = _this select 0; 
	_triggerName = _this select 1; 

	// Loop through and see if the triggername is in the active trigger array, if not, add it. 
	if !(_triggerName in ActiveTriggerArray) then {
		ActiveTriggerArray pushback _triggerName;
	};
	 
	// Make the server start blinking the marker.
	if isServer then {		
		while {_triggerName in ActiveTriggerArray} do {

			_markerName setMarkerAlpha 0.2;
			sleep 0.3;

			_markerName setMarkerAlpha 1;
			sleep 0.3;
		};
	};
};

// Make the inactive marker solid again (To show it is inactive);
makeMarkerSolid = {

	// Get the params
	_triggerName = _this select 0;
	_markerName = _this select 1;

	// Get the trigger name out of the active trigger array
	ActiveTriggerArray deleteAt (ActiveTriggerArray find _triggerName);

	// Stop the marker from blinking. 
	if isServer then {		
		_markerName setMarkerAlpha 1;
	};
};

// Handle the activation of a sector
activateSector = { 

	// Get the params
	_markerName = _this select 0; 
	_triggerName = _this select 1; 
	_subTrigger = _this select 2; 
	_trigger = _this select 3;

	// Get the area of the trigger
	_area = triggerArea _trigger;

	// Set the incremental spawn count value to 0 for this sector. 
	_spawnCount = 0;

	// Define an array of random numbers, and then select the random number from the array
	
	_randomGroupCompositionCount = random [2,6];

	// Spawn a random number of groups containing a random number of units
	while {_spawnCount < _randomGroupCompositionCount} do {
		[_markerName] spawn createEnemyInfantryGroups;
		_spawnCount = _spawnCount + 1;

		// Show a message for debug purposes. 
		if (OpforDebug) then {
			hint format ["Groups Spawned: %1", _spawnCount];
			sleep .2;
		}

	};

	// Spawn a random number of enemies in a random number of buildings of defined types
	[_trigger, BaseBldgArray] spawn populateEnemyLocations;
	[_trigger, VillageBldgArray] spawn populateEnemyLocations; 

	// 20% Chance of spawning a mechanized presence 
	if (20 > random 100) then {
		[_trigger, OpforMGTruck] spawn populateMechanizedPatrols; 
	}; 

	// 20% Chance of spawning a static MG presence 
	if (20 > random 100) then {
		[_trigger, OpforStaticGuns] spawn populateStaticPositions; 
	}; 

	// 20% Chance of spawning a static mortar / launcher presence 
	if (20 > random 100) then {
		[_trigger, OpforStaticMortar] spawn populateStaticPositions; 
	}; 


	// Create success trigger
	_xTrigger = createTrigger ["EmptyDetector", getMarkerPos _markerName]; 
	_xTrigger setTriggerArea [_area select 0, _area select 1, 0, false]; 
	_xTrigger setTriggerActivation ["EAST", "NOT PRESENT", false]; 
	_xTrigger setTriggerType "NONE";
	_xTrigger setTriggerTimeout [10,10,10,true];
	_xTrigger setVehicleVarName _subTrigger;

	// Define the function to be called on success
	_subtriggerOnAct = format["['%1', '%2', '%3', thisTrigger] spawn cleanUpVictorySector;", _triggerName, _markerName, _trigger]; 

	// Set the trigger statements.
	_xTrigger setTriggerStatements ["This",_subtriggerOnAct,""]; 

};
   
// Clean up a completed sector
cleanUpVictorySector = {

	// Get the params
	_triggerName = _this select 0; 
	_markerName = _this select 1; 
	_parentTrigger = _this select 2; 
	_trigger = _this select 3; 
	
	// Set up a debug message so we know when the victory trigger was activated. 
	if (OpforDebug) then {
		hint format ["Victory Trigger Activated. Cleaning up %1, activated by %2", _triggerName, _trigger];
	};

	// Make the marker solid -- We may not need to do this.
	// [_trigger, _markerName] spawn makeMarkerSolid;

	// Get the marker's area
	_area = getMarkerSize _markerName;

	// Set marker name to something we can get from trigger name
	_markerObjName = Format["MarkerForCompleted%1", _trigger];

	// Create the completed marker
	createMarker[_markerObjName, getMarkerPos _markerName];
	_markerObjName setMarkerShape "RECTANGLE";
	_markerObjName setMarkerSize [_area select 0, _area select 1];
	_markerObjName setMarkerColor "ColorGreen";
	_markerObjName setMarkerBrush "FDiagonal";

	// Increment the autoname number
	MarkerNum = MarkerNum + 1; 
	
	// Delete the completion trigger
	DeleteVehicle _trigger; 

	// Since the parentTrigger will be a random name, and we set the varName, we'll need to loop through all triggers and check their varNames, then delete the correct trigger. 
	_AllTriggerNamesUpdated = allMissionObjects "EmptyDetector";
	{
		if (vehicleVarName _x == _parentTrigger ) then {
			deleteVehicle _x;
		};
	} foreach _AllTriggerNamesUpdated;
	
	// Delete the blinking red marker.
	DeleteMarker _markerName; 
};

// Clean up an abandoned sector
cleanUpAbandonedSector = {

	// Get the params
	_trigger = _this select 0; 
	_subTrigger = _this select 1;

	// Set up a debug mesage so we know when the sector has been abandoned.
	if (OpforDebug) then {
		hint format ["Sector for %1 abandoned. Deleting %2", _trigger, _subTrigger];
	};

	// Loop through and delete all the enemy units in the trigger (if any have made it out of the trigger, they will survive. I actually like this. Makes stragglers, maybe even in green sectors.)
	{
		if ((side _x) == EAST and [_trigger, _x] call BIS_fnc_inTrigger) then {
			deleteVehicle _x;
		};
	} foreach allUnits;

	// Update the list of triggers, since we've created some when the zone was activated, and those are actually the ones we care about. 
	_AllTriggerNamesUpdated = allMissionObjects "EmptyDetector";

	// Loop through and delete the trigger based on the varName we set (because the actual objeect name will be random)
	{
		if (vehicleVarName _x == _subtrigger ) exitWith {
			deleteVehicle _x;
		};

	} foreach _AllTriggerNamesUpdated;
};

// Create enemy groups and giver them orders 
createEnemyInfantryGroups = {

	// Define the area we're focusing on
	_marker = _this select 0;
	// grab an array of any base markers 
	_baseMarkers = _this select 1; 

	// Select a random number of soldiers to stick in the group
	
	_randomGroupCount = random [3,9];

	// Define a default array to stick the randomly selected soldiers in.
	_randomGroupCompositionArray = [];

	// default counter values
	_spawnCount = 0; 
	GroupNum = 0; 

	// Loop through and push the soldiers in the group into the array
	while {_spawnCount < _randomGroupCount} do {
		_randomOpforSoldier = OpforRifleUnit select floor random count OpforRifleUnit;
		_randomGroupCompositionArray pushBack _randomOpforSoldier;
		_spawnCount = _spawnCount + 1;
	};

	// Generate an automatic name for the group
	_autoGroupName = Format["OpforPatrolGroup%1", GroupNum];
	GroupNum = GroupNum + 1; 

	_randomPosInTrigger = _marker call BIS_fnc_randomPosTrigger;

	// Generate the group of soldiers
	_autoGroupName = [_randomPosInTrigger, EAST, _randomGroupCompositionArray] call BIS_fnc_spawnGroup;
	[_autoGroupName, getMarkerPos _marker, 100] call BIS_fnc_taskPatrol; 

};

// Populate bldgs with a 20% chance. 
// ToDo: Change pop chance to a paramsArray value? Cons: Could be abused to detrimental effect...
populateEnemyLocations = {

	// Get the params
	_trigger = _this select 0; 
	_bldgArray = _this select 1;
	_area = triggerArea _trigger;
	_areaLength = _area select 0 ;
	_areaWidth = _area select 1;

	// Math function to get the radius of a square - Rectangles will make this fall apart as the compounds on the edges will not be picked up.
	_calculatedArea = sqrt ((_areaLength / 2) * (_areaWidth / 2) * 2);

	// Grab an array of buildings in the area that match the bldgs we define as ones we wanna spawn enemies in. 
	_spawnBldgs = nearestObjects [_trigger, _bldgArray, _calculatedArea];

	// Set an auto-incrementor for the auto-naming in this loop. 
	_i = 0; 
	{
		// for each bldg, there is a 20% chance there will be enemy there. 
		if (20 > random 100) then {

			// Select a random number of soldiers to stick in the group
			
			_randomGroupCount = random [1, 4];

			// Define a default array to stick the randomly selected soldiers in.
			_randomGroupCompositionArray = [];

			// default counter values
			_spawnCount = 0; 
			GroupNum = 0; 

			// Loop through and push the soldiers in the group into the array
			while {_spawnCount < _randomGroupCount} do {
				_randomOpforSoldier = OpforRifleUnit select floor random count OpforRifleUnit;
				_randomGroupCompositionArray pushBack _randomOpforSoldier;
				_spawnCount = _spawnCount + 1;
			};
			
			// Autoname the group
			_autoGroupName = format["OpforDefenseGroup%1",_i]; 

			// Spawn a group from the randon composition array. 
			_autoGroupName = [getPos _x, EAST, _randomGroupCompositionArray] call BIS_fnc_spawnGroup;

			// make the newly spawned group havbe an order to defend. 
			[_autoGroupName, getPos _x] call BIS_fnc_taskDefend; 

			// Increment the autonaming number.
			_i = _i + 1;
		};
	} foreach _spawnBldgs;
};

// Create vehicles with people that drive places. 
populateMechanizedPatrols = {

	// Get params
	_trigger = _this select 0; 
	_vehArray = _this select 1;
	_area = triggerArea _trigger;
	_areaLength = _area select 0 ;
	_areaWidth = _area select 1;

	// Math function to get the radius of a square - Rectangles will make this fall apart as the compounds on the edges will not be picked up.
	_calculatedArea = sqrt ((_areaLength / 2) * (_areaWidth / 2) * 2);

	// Get a random position within the trigger area
	_randomPosInTrigger = _trigger call BIS_fnc_randomPosTrigger;
	
	// Find the nearest road within 500m of the random position.
	_nearestRoad = [_randomPosInTrigger, 100] call BIS_fnc_nearestRoad;
	
	// Select a random vehicle from the pre-defined array.
	_randomOpforVehicle = _vehArray select floor random count _vehArray;
	
	// Create the randomly selected vehicle at the randomly selected on road location.
	_opforVeh= CreateVehicle [_randomOpforVehicle, getPosATL _nearestRoad, [], 0, "NONE"];
	
	// Create a group 
	_group = createGroup east;

	// Populate the vehicle 
	[ _opforVeh, _group] call BIS_fnc_spawnCrew;

	// Give them some orders
	[_group, getPosATL _nearestRoad, 500] call BIS_fnc_taskPatrol; 

};

// Create static positions with people to use them
populateStaticPositions = {

	// Get params
	_trigger = _this select 0; 
	_vehArray = _this select 1;
	_area = triggerArea _trigger;
	_areaLength = _area select 0 ;
	_areaWidth = _area select 1;

	// Math function to get the radius of a square - Rectangles will make this fall apart as the compounds on the edges will not be picked up.
	_calculatedArea = sqrt ((_areaLength / 2) * (_areaWidth / 2) * 2);

	// Select a random vehicle from the pre-defined array.
	_randomOpforVehicle = _vehArray select floor random count _vehArray;

	// Get a random position within the trigger area
	_randomPosInTrigger = _trigger call BIS_fnc_randomPosTrigger;
	
	// Create the randomly selected vehicle at the randomly selected location.
	_opforVeh= CreateVehicle [_randomOpforVehicle, _randomPosInTrigger, [], 0, "NONE"];
	
	// Create a group 
	_group = createGroup east;

	// Populate the vehicle 
	[_opforVeh, _group] call BIS_fnc_spawnCrew;

	// Make the newly spawned group have an order to defend. 
	[_group, _randomPosInTrigger] call BIS_fnc_taskDefend; 
};