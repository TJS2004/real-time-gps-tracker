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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _listenToFirebaseUpdates();
  }

  /// Step 1: Get live current location
  Future<void> _getCurrentLocation() async {
    await Geolocator.requestPermission();
    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
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
      builder: (context) =>
          AlertDialog(
            title: const Text("Save this location"),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                  hintText: "Enter location name"),
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
    // Show a confirmation dialog (optional, but recommended)
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text("Confirm Deletion"),
            content: const Text(
                "Are you sure you want to delete this location?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true), // Confirm
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

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: const Text("Real-Time GPS Tracker")),
        body: _currentPosition == null
            ? const Center(child: CircularProgressIndicator())
            : FlutterMap(
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
                ..._savedLocations.map((loc) =>
                    Marker(
                      point: LatLng(loc["latitude"], loc["longitude"]),
                      width: 60,
                      height: 60,
                      child: Column(
                        children: [
                          const Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
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
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.green,
          child: const Icon(Icons.list, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SavedLocationsScreen(
                      savedLocations: _savedLocations,
                      onAddPressed: () {
                        Navigator.pop(context); // close list view
                        setState(() => _isAddMode = true); // enable add mode
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Tap on map to add new location."),
                          ),
                        );
                      },
                      onDeletePressed: _deleteLocation,
                    ),
              ),
            );
          },
        ),
      );
    }
  }

