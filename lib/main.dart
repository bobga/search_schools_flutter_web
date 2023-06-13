import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class School {
  late final String name;
  late final String address;
  late final double latitude;
  late final double longitude;

  School(
      {required this.name,
      required this.address,
      required this.latitude,
      required this.longitude});
}

class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  _AddressSearchScreenState createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final String kGoogleApiKey = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';

  List<School> _initResults = [];
  List<School> _searchResults = [];
  School? _selectedSchool;

  List<Map<String, String>> _suggestions = [];

  void _searchSchools() async {
    final String city = _cityController.text.trim();

    if (city.isEmpty) {
      return;
    }

    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('schools')
        .where('address', isGreaterThanOrEqualTo: city)
        .where('address', isLessThanOrEqualTo: '$city\uf8ff')
        .get();

    final List<School> results = snapshot.docs.map((doc) {
      final data = doc.data() as Map;

      return School(
        name: data['name'],
        address: data['address'],
        latitude: data['latitude'],
        longitude: data['longitude'],
      );
    }).toList();

    setState(() {
      _searchResults = results;
    });
  }

  Future<List<Map<String, String>>> _fetchPlacesAutocomplete(
      String input) async {
    final apiUrl =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&types=school&key=$kGoogleApiKey';

    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final predictions = data['predictions'] as List<dynamic>;

      return predictions.map<Map<String, String>>((prediction) {
        final structuredFormatting = prediction['structured_formatting'];
        final mainText = structuredFormatting['main_text'] as String;
        final secondaryText = structuredFormatting['secondary_text'] as String;
        final placeId = prediction['place_id'] as String;

        return {
          'name': mainText,
          'address': secondaryText,
          'placeId': placeId,
        };
      }).toList();
    } else {
      throw Exception('Failed to fetch places autocomplete');
    }
  }

  Future<Map<String, dynamic>> _fetchPlaceDetails(String placeId) async {
    // Replace with your actual Google Cloud API key
    final apiUrl =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$kGoogleApiKey';

    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final result = data['result'];
      final geometry = result['geometry'];
      final location = geometry['location'];
      final lat = location['lat'] as double;
      final lng = location['lng'] as double;

      return {
        'latitude': lat,
        'longitude': lng,
      };
    } else {
      throw Exception('Failed to fetch place details');
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    initData();
    super.initState();
  }

  void initData() async {
    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('schools').get();

    final List<School> results = snapshot.docs.map((doc) {
      final data = doc.data() as Map;

      return School(
        name: data['name'],
        address: data['address'],
        latitude: data['latitude'],
        longitude: data['longitude'],
      );
    }).toList();
    setState(() {
      _initResults = results;
    });
  }

  void _addSchool() {
    if (_selectedSchool == null) {
      return;
    }

    final schoolData = {
      'name': _selectedSchool!.name,
      'address': _selectedSchool!.address,
      'latitude': _selectedSchool!.latitude,
      'longitude': _selectedSchool!.longitude,
    };

    FirebaseFirestore.instance
        .collection('schools')
        .add(schoolData)
        .then((docRef) {
      print('School added with ID: ${docRef.id}');
      _resetFields();
    }).catchError((error) {
      print('Failed to add school: $error');
    });

    initData();
  }

  void _resetFields() {
    _cityController.clear();
    _addressController.clear();
    _selectedSchool = null;
    _suggestions = [];
    setState(() {
      _searchResults = [];
    });
  }

  final ScrollController controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_initResults.isNotEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.2,
                child: ListView.builder(
                  itemCount: _initResults.length,
                  itemBuilder: (context, index) {
                    final school = _initResults[index];
                    return ListTile(
                      title: Text(school.name),
                      subtitle: Text(school.address),
                    );
                  },
                ),
              ),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'Address Search'),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: _searchSchools,
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            if (_searchResults.isNotEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.1,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final school = _searchResults[index];
                    return ListTile(
                      title: Text(school.name),
                      subtitle: Text(school.address),
                    );
                  },
                ),
              ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Google Map Search',
              ),
              onChanged: (value) {
                // Call the function to fetch autocomplete results
                _fetchPlacesAutocomplete(value).then((predictions) {
                  // Handle the predictions (e.g., update a list or dropdown)
                  // ...
                  setState(() {
                    _suggestions = predictions;
                  });
                }).catchError((error) {
                  // Handle the error
                  // ...
                });
              },
            ),
            const SizedBox(height: 16.0),
            if (_suggestions.isNotEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.2,
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      title: Text(suggestion['name']!),
                      subtitle: Text(suggestion['address']!),
                      onTap: () async {
                        final placeId = suggestion['placeId'] as String;

                        final details = await _fetchPlaceDetails(placeId);
                        final latitude = details['latitude'];
                        final longitude = details['longitude'];

                        setState(() {
                          _selectedSchool = School(
                              name: suggestion['name']!,
                              address: suggestion['address']!,
                              latitude: latitude,
                              longitude: longitude);
                        });
                      },
                    );
                  },
                ),
              ),
            if (_selectedSchool != null) ...[
              const Text(
                'Selected School:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ListTile(
                title: Text(_selectedSchool!.name),
                subtitle: Text(_selectedSchool!.address),
              ),
            ],
            const SizedBox(height: 15.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: _addSchool,
                  child: const Text('Add School'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "",
        authDomain: "",
        projectId: "",
        storageBucket: "",
        messagingSenderId: "",
        appId: "",
        measurementId: ""
        // Add other Firebase configuration parameters as needed
        ),
  );
  runApp(const MaterialApp(home: AddressSearchScreen()));
}
