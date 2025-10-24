import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

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

    // turn off add mode after saving
    setState(() => _isAddMode = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Real-Time GPS Tracker"),
      ),
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
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
        backgroundColor: _isAddMode ? Colors.red : Colors.blue,
        child: Icon(_isAddMode ? Icons.close : Icons.add, color: Colors.white),
        onPressed: () {
          setState(() => _isAddMode = !_isAddMode);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isAddMode
                    ? "Tap on the map to add a new pin."
                    : "Add mode cancelled."),
                duration: const Duration(seconds: 2),
          ));
        },
      ),
    );
  }
}
