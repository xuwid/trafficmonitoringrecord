import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:trafficmonitoringrecord/screens/login.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _firestore = FirebaseFirestore.instance;

  String getViolationCategory(DateTime violationDate) {
    final now = DateTime.now();
    final difference = now.difference(violationDate);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays <= 7) {
      return 'Last Week';
    } else {
      return 'Older';
    }
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      print("Error logging out: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Traffic Violations",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: logout,
            tooltip: 'Logout',
          ),
        ],
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: _firestore
            .collection('violations')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final violations = snapshot.data!.docs;

          if (violations.isEmpty) {
            return Center(
              child: Text(
                "No violations recorded",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          Map<String, List<DocumentSnapshot>> categorizedViolations = {
            'Today': [],
            'Yesterday': [],
            'Last Week': [],
            'Older': [],
          };

          for (var violation in violations) {
            final data = violation.data() as Map<String, dynamic>;
            final violationDate =
                DateFormat('yyyy-MM-dd').parse(data['date'] ?? '');
            final category = getViolationCategory(violationDate);
            categorizedViolations[category]!.add(violation);
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: 16.0),
                child: Column(
                  children: [
                    ...categorizedViolations.entries.map((entry) {
                      final category = entry.key;
                      final violationsList = entry.value;

                      return Visibility(
                        visible: violationsList.isNotEmpty,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                            ...violationsList.map((violation) {
                              final data =
                                  violation.data() as Map<String, dynamic>;
                              return ViolationTile(
                                numberPlate:
                                    data['numberPlate'] ?? 'Unknown Plate',
                                date: data['date'] ?? 'No Date',
                                longitude: data['longitude'] ?? 0.0,
                                latitude: data['latitude'] ?? 0.0,
                                speed: data['speed'] ?? 0.0,
                              );
                            }).toList(),
                            Divider(thickness: 1, color: Colors.grey[300]),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ViolationTile extends StatefulWidget {
  final String numberPlate;
  final String date;
  final double longitude;
  final double latitude;
  final double speed;

  ViolationTile({
    required this.numberPlate,
    required this.date,
    required this.longitude,
    required this.latitude,
    required this.speed,
  });

  @override
  _ViolationTileState createState() => _ViolationTileState();
}

class _ViolationTileState extends State<ViolationTile> {
  late GoogleMapController mapController;
  Set<Marker> _markers = {}; // Define the marker set

  // Initial position of the camera
  CameraPosition get _initialCameraPosition => CameraPosition(
        target: LatLng(widget.latitude, widget.longitude),
        zoom: 15,
      );

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _addMarker(); // Call the method to add the marker
  }

  // Method to add a marker to the marker set
  void _addMarker() {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId("violation_location"),
          position: LatLng(widget.latitude, widget.longitude),
          infoWindow: InfoWindow(
            title: "Violation Location",
            snippet: "${widget.latitude}, ${widget.longitude}",
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Plate: ${widget.numberPlate}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent,
                      ),
                    ),
                    Icon(Icons.directions_car, color: Colors.redAccent),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  "Date: ${widget.date}",
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                SizedBox(height: 8),
                Text(
                  "Speed: ${widget.speed.toStringAsFixed(1)} km/h",
                  style: TextStyle(fontSize: 14, color: Colors.green),
                ),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to MapScreen with the violation location
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapScreen(
                          latitude: widget.latitude,
                          longitude: widget.longitude,
                        ),
                      ),
                    );
                  },
                  child: Text("View on Map"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple, // Button color
                    foregroundColor: Colors.white, // Text color
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;

  MapScreen({required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Violation Location"),
        backgroundColor: Colors.purple,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: MarkerId('violation_location'),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(
              title: "Violation Location",
              snippet: "$latitude, $longitude",
            ),
          ),
        },
      ),
    );
  }
}
