import 'package:flutter/material.dart';

class SavedLocationsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> savedLocations;
  final VoidCallback onAddPressed;
  final Function(String locationId) onDeletePressed;

  const SavedLocationsScreen({
    super.key,
    required this.savedLocations,
    required this.onAddPressed,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Locations")),
      body: savedLocations.isEmpty
          ? const Center(child: Text("No saved locations yet."))
          : ListView.builder(
        itemCount: savedLocations.length,
        itemBuilder: (context, index) {
          final loc = savedLocations[index];
          final String locationId = loc["id"];

          return ListTile(
            leading: const Icon(Icons.location_pin, color: Colors.red),
            title: Text(loc["name"]),
            subtitle: Text(
              "Lat: ${loc["latitude"].toStringAsFixed(5)}, "
                  "Lng: ${loc["longitude"].toStringAsFixed(5)}",
            ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey),
                onPressed: () => onDeletePressed(locationId),
              ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onAddPressed,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
