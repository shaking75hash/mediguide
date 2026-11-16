import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import 'doctor_profile_screen.dart';

enum _CareType { doctors, hospitals }

class YourCareScreen extends StatefulWidget {
  const YourCareScreen({super.key});

  @override
  State<YourCareScreen> createState() => _YourCareScreenState();
}

class _YourCareScreenState extends State<YourCareScreen> {
  static const _green = Color(0xFF347452);
  static const _ink = Color(0xFF183B31);
  static const _muted = Color(0xFF73847C);

  final _formKey = GlobalKey<FormState>();
  final _concernController = TextEditingController();
  final _locationController = TextEditingController();
  _CareType _careType = _CareType.doctors;
  List<dynamic> _doctors = [];
  List<dynamic> _hospitals = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _error;
  int _requestId = 0;

  @override
  void dispose() {
    _concernController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _findCare() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final requestId = ++_requestId;
    final concern = _concernController.text.trim();
    final location = _locationController.text.trim();
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _error = null;
      _doctors = [];
      _hospitals = [];
    });

    try {
      if (_careType == _CareType.doctors) {
        final results = await ApiService.searchDoctors(
          concern,
          location: location,
        );
        if (!mounted || requestId != _requestId) return;
        setState(() => _doctors = results);
      } else {
        final results = await ApiService.searchHospitals(location: location);
        if (!mounted || requestId != _requestId) return;
        setState(() => _hospitals = results);
      }
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      debugPrint('Your care search failed: $error');
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = message;
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        title: const Text('Your care'),
        backgroundColor: const Color(0xFFF6F8F5),
        foregroundColor: _ink,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const Text(
              'Find care that fits your needs',
              style: TextStyle(
                color: _ink,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tell us what you need and where you want to look.',
              style: TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What kind of care do you want?',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<_CareType>(
                    segments: const [
                      ButtonSegment(
                        value: _CareType.doctors,
                        icon: Icon(Icons.person_outline_rounded),
                        label: Text('Doctors'),
                      ),
                      ButtonSegment(
                        value: _CareType.hospitals,
                        icon: Icon(Icons.local_hospital_outlined),
                        label: Text('Hospitals'),
                      ),
                    ],
                    selected: {_careType},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _careType = selection.first;
                        _hasSearched = false;
                        _error = null;
                      });
                    },
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : _ink,
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? _green
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _concernController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _careType == _CareType.doctors
                          ? 'Disease, health concern, or specialty'
                          : 'Health concern (hospital services are unverified)',
                      hintText: _careType == _CareType.doctors
                          ? 'For example, heart care or cardiology'
                          : 'Nearby hospitals will be shown for your area',
                      prefixIcon: const Icon(Icons.health_and_safety_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? _careType == _CareType.doctors
                              ? 'Enter a health concern or specialty'
                              : 'Enter a hospital type or health concern'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _locationController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => _findCare(),
                    decoration: InputDecoration(
                      labelText: 'Preferred location',
                      hintText: 'For example, Kadirganj or Rajshahi',
                      helperText: 'Uses map data with a local directory fallback. Your concern is not sent to OpenStreetMap.',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a city or area'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _findCare,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(_isLoading ? 'Finding care…' : 'Find care'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_hasSearched) ...[const SizedBox(height: 24), _buildResults()],
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: _green),
        ),
      );
    }
    if (_error != null) {
      return _messageCard(
        icon: Icons.cloud_off_outlined,
        title: 'Search could not be completed',
        message: _error!,
      );
    }

    if (_careType == _CareType.doctors) {
      if (_doctors.isEmpty) {
        return _messageCard(
          icon: Icons.person_search_outlined,
          title: 'No matching doctors',
          message: 'No matching doctor listings were found for this location. Try Rajshahi or another nearby area.',
        );
      }
      final hasLocalDirectoryResults = _doctors.any(
        (doctor) => doctor['source'] == 'local_directory',
      );
      final hasOpenStreetMapResults = _doctors.any(
        (doctor) => doctor['source'] == 'openstreetmap',
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_doctors.length} doctor${_doctors.length == 1 ? '' : 's'} found',
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'These are directory suggestions, not a medical diagnosis. Confirm the doctor’s specialty and location before visiting.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
          if (hasLocalDirectoryResults) ...[
            const SizedBox(height: 8),
            const Text(
              'MediGuide directory entries may list only the city, so their exact distance from your area is unknown.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          ],
          if (!_doctors.any((doctor) => doctor['specialty_match'] == true)) ...[
            const SizedBox(height: 8),
            const Text(
              'No nearby map listing explicitly matched that specialty. Map-only doctors shown here may not list a specialty; contact them to confirm.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          ..._doctors.map(_doctorCard),
          if (hasOpenStreetMapResults) ...[
            const SizedBox(height: 4),
            const Text(
              'Map data © OpenStreetMap contributors.',
              style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
            ),
          ],
        ],
      );
    }

    if (_hospitals.isEmpty) {
      return _messageCard(
        icon: Icons.location_city_outlined,
        title: 'No hospitals listed for this location',
        message: 'Try a broader Rajshahi area. OpenStreetMap may not list every hospital.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _hospitals.any((hospital) => hospital['source'] == 'local_directory')
              ? 'MediGuide directory results may be city-level rather than nearby. Hospital services are not verified; contact the hospital before visiting.'
              : 'Nearby hospitals are shown regardless of your concern because their services are not verified on the map. Contact the hospital to confirm care before visiting.',
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(
          '${_hospitals.length} hospital${_hospitals.length == 1 ? '' : 's'} found',
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ..._hospitals.map(_hospitalCard),
        const SizedBox(height: 4),
        const Text(
          'Map location data © OpenStreetMap contributors. Confirm hospital services before visiting.',
          style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _doctorCard(dynamic doctor) {
    final fee = doctor['consultation_fee'];
    final isOpenStreetMap = doctor['source'] == 'openstreetmap';
    final latitude = doctor['latitude'];
    final longitude = doctor['longitude'];
    final canOpenDirections =
        isOpenStreetMap && latitude is num && longitude is num;
    final distance = doctor['distance_km'];
    final location = doctor['location']?.toString() ?? 'Location not listed';
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEAF2EC),
          child: Icon(Icons.person_outline_rounded, color: _green),
        ),
        title: Text(doctor['name']?.toString() ?? 'Doctor'),
        subtitle: Text(
          '${doctor['specialty'] ?? 'Specialty not listed'} · '
          '$location${distance is num ? ' · ${distance.toStringAsFixed(1)} km' : ''}',
        ),
        trailing: canOpenDirections
            ? IconButton(
                tooltip: 'Open directions in Google Maps',
                onPressed: () => _openDirections(latitude, longitude),
                icon: const Icon(Icons.directions_rounded, color: _green),
              )
            : Text(
                fee == null ? '' : '৳$fee',
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w700,
                ),
              ),
        onTap: isOpenStreetMap
            ? () => _openListing(doctor['source_url']?.toString())
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DoctorProfileScreen(
                      doctor: Map<String, dynamic>.from(doctor),
                    ),
                  ),
                );
              },
      ),
    );
  }

  Widget _hospitalCard(dynamic hospital) {
    final isSample = hospital['is_sample'] == true;
    final latitude = hospital['latitude'];
    final longitude = hospital['longitude'];
    final sourceUrl = hospital['source_url']?.toString();
    final canOpenDirections = !isSample && latitude is num && longitude is num;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEAF2EC),
          child: Icon(Icons.local_hospital_outlined, color: _green),
        ),
        title: Text(hospital['name']?.toString() ?? 'Hospital'),
        subtitle: Text(
          '${hospital['category'] ?? 'Hospital'} · '
          '${hospital['location'] ?? 'Location not listed'}',
        ),
        trailing: isSample
            ? const Text(
                'Sample',
                style: TextStyle(
                  color: Color(0xFF9A5B00),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            : canOpenDirections
            ? IconButton(
                tooltip: 'Open directions in Google Maps',
                onPressed: () => _openDirections(latitude, longitude),
                icon: const Icon(Icons.directions_rounded, color: _green),
              )
            : null,
        onTap: sourceUrl == null ? null : () => _openListing(sourceUrl),
      ),
    );
  }

  Future<void> _openListing(String? sourceUrl) async {
    final uri = sourceUrl == null ? null : Uri.tryParse(sourceUrl);
    if (uri == null || uri.scheme != 'https') return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the map listing.')),
        );
      }
    } catch (error) {
      debugPrint('Could not open the map listing: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the map listing.')),
        );
      }
    }
  }

  Future<void> _openDirections(num latitude, num longitude) async {
    final mapsUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    });
    try {
      final opened = await launchUrl(
        mapsUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    } catch (error) {
      debugPrint('Could not open hospital directions: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    }
  }

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, color: _green, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
