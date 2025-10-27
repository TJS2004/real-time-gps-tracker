import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'saved_locations_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref("users/user1/locations");

  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _isAddMode = false;

  final List<Map<String, dynamic>> _savedLocations = [];

  // --- New Travel State Variables ---
  final _userRef = FirebaseDatabase.instance.ref("users/user1");
  Map<String, dynamic>? _activeTravel; // current travel info
  DateTime? _startTime;
  String? _selectedDestinationId;
  bool _canCheckIn = false;
  StreamSubscription<Position>? _positionStream;
  // ----------------------------------

  @override
  void initState() {
    super.initState();
    _resetUserStatus();
    _getCurrentLocation();
    _listenToFirebaseUpdates();
  }

  // --- FIX 1: Added dispose() method ---
  @override
  void dispose() {
    _positionStream?.cancel(); // Cancel the stream subscription
    super.dispose();
  }

  /// Step 0: Reset Firebase status on app start
  Future<void> _resetUserStatus() async {
    // This handles the case where the app was quit mid-travel
    await _userRef.update({
      "status": "off",
      "current_travel": null,
    });
  }

  /// Step 1: Get live current location
  Future<void> _getCurrentLocation() async {
    await Geolocator.requestPermission();
    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    // Start the live position stream
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10 meters
      ),
    ).listen((Position pos) {
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });

      // Check distance every time location updates
      _checkIfNearDestination();
    });
  }

  /// Step 2: Load all saved locations from Firebase
  void _listenToFirebaseUpdates() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final locations = data.entries.map((e) {
          final val = e.value as Map;
          return {
            "id": e.key,
            "name": val["name"],
            "latitude": val["latitude"],
            "longitude": val["longitude"],
          };
        }).toList();

        setState(() {
          _savedLocations
            ..clear()
            ..addAll(locations);
        });
      } else {
        setState(() => _savedLocations.clear());
      }
    });
  }

  /// Step 3: Add a new pin manually
  void _onMapTap(LatLng tappedPoint) async {
    if (!_isAddMode) return;

    TextEditingController nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save this location"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Enter location name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await _dbRef.push().set({
                  "name": name,
                  "latitude": tappedPoint.latitude,
                  "longitude": tappedPoint.longitude,
                });
              }
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );

    // Turn off add mode after saving
    setState(() => _isAddMode = false);
  }

  /// Step 4: Delete a saved pin from Firebase
  Future<void> _deleteLocation(String locationId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text("Are you sure you want to delete this location?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbRef.child(locationId).remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location deleted.")),
      );
    }
  }

  /// --- New Travel Methods ---

  void _startTravel() async {
    if (_savedLocations.isEmpty) return;

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select destination"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _savedLocations.length,
            itemBuilder: (_, index) {
              final loc = _savedLocations[index];
              return ListTile(
                title: Text(loc["name"]),
                onTap: () => Navigator.pop(context, loc),
              );
            },
          ),
        ),
      ),
    );

    if (selected != null) {
      final startTime = DateTime.now();

      setState(() {
        _activeTravel = selected;
        _startTime = startTime;
        _selectedDestinationId = selected["id"];
        _canCheckIn = false; // Reset check-in status
      });

      // 🔥 Update Firebase status
      await _userRef.update({
        "status": "on",
        "current_travel": {
          "destination": selected["name"],
          "latitude": selected["latitude"],
          "longitude": selected["longitude"],
          "startTime": startTime.toIso8601String(),
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Travel started to ${selected["name"]}!")),
      );
    }
  }

  void _checkIfNearDestination() {
    if (_activeTravel == null || _currentPosition == null) return;

    final destination = LatLng(
      _activeTravel!["latitude"],
      _activeTravel!["longitude"],
    );

    // Calculate distance
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      destination.latitude,
      destination.longitude,
    );

    // Check if within 100 meters and not already able to check in
    if (distance < 100 && !_canCheckIn) {
      setState(() => _canCheckIn = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("You are near your destination. You can check in now.")),
      );
    } else if (distance >= 100 && _canCheckIn) {
      // Optional: reset if they move away again
      setState(() => _canCheckIn = false);
    }
  }

  // --- FIX 2: Added _checkIn() method ---
  void _checkIn() async {
    if (_activeTravel == null || _startTime == null) return;

    final endTime = DateTime.now();
    final duration = endTime.difference(_startTime!).inMinutes;

    // Optional: Save to travel history
    await _userRef.child("travel_history").push().set({
      "destination": _activeTravel!["name"],
      "startTime": _startTime!.toIso8601String(),
      "endTime": endTime.toIso8601String(),
      "duration_minutes": duration,
    });

    // Update Firebase status to "off"
    await _userRef.update({
      "status": "off",
      "current_travel": null, // Remove current travel node
    });

    // Reset local state
    setState(() {
      _activeTravel = null;
      _startTime = null;
      _selectedDestinationId = null;
      _canCheckIn = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Checked in! Travel time: $duration minutes.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Real-Time GPS Tracker")),
      // --- FIX 3: Use a Stack for the body ---
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition!,
              initialZoom: 16,
              onTap: (_, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.fyp_2',
              ),
              MarkerLayer(
                markers: [
                  // Show all saved locations
                  ..._savedLocations.map((loc) => Marker(
                    point: LatLng(loc["latitude"], loc["longitude"]),
                    width: 60,
                    height: 60,
                    child: Column(
                      children: [
                        Icon(Icons.location_pin,
                            color:
                            // Highlight destination
                            loc["id"] == _selectedDestinationId
                                ? Colors.purple
                                : Colors.red,
                            size: 40),
                        Text(
                          loc["name"],
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
                  // Show current position
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 60,
                      height: 60,
                      child: const Icon(Icons.my_location,
                          color: Colors.blue, size: 40),
                    ),
                ],
              ),
            ],
          ),

          // --- Button 1: List Button (Bottom Left) ---
          Positioned(
            left: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: "showList",
              backgroundColor: Colors.green,
              child: const Icon(Icons.list, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SavedLocationsScreen(
                      savedLocations: _savedLocations,
                      onAddPressed: () {
                        Navigator.pop(context); // close list view
                        setState(() => _isAddMode = true); // enable add mode
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                            Text("Tap on map to add new location."),
                          ),
                        );
                      },
                      onDeletePressed: _deleteLocation,
                    ),
                  ),
                );
              },
            ),
          ),

          // --- Button 2: Travel Buttons (Bottom Right) ---
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Show start button only if NOT traveling
                if (_activeTravel == null)
                  FloatingActionButton(
                    heroTag: "startTravel",
                    backgroundColor: Colors.blue,
                    child:
                    const Icon(Icons.play_arrow, color: Colors.white),
                    onPressed: _startTravel,
                  ),

                // Show check-in button only if near destination
                if (_canCheckIn) ...[
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: "checkIn",
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.flag, color: Colors.white),
                    onPressed: _checkIn,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}