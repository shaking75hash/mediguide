import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'doctor_profile_screen.dart';

enum SearchMode { doctors, tests }

class SearchScreen extends StatefulWidget {
  final SearchMode initialMode;

  const SearchScreen({super.key, this.initialMode = SearchMode.doctors});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _ink = Color(0xFF183B31);
  static const _green = Color(0xFF347452);
  static const _muted = Color(0xFF73847C);
  static const _line = Color(0xFFE4EBE6);

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  SearchMode _mode = SearchMode.doctors;
  bool _modePinned = false;
  List<dynamic> _doctors = [];
  List<dynamic> _services = [];
  List<dynamic> _facilities = [];
  Map<String, dynamic>? _selectedService;
  bool _loadingDoctors = false;
  bool _loadingServices = true;
  bool _loadingFacilities = false;
  String? _doctorError;
  String? _serviceError;
  String? _facilityError;
  int _searchRequest = 0;
  int _facilityRequest = 0;
  int? _requestedServiceId;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _modePinned = widget.initialMode != SearchMode.doctors;
    _loadServices();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loadingServices = true;
      _serviceError = null;
    });
    try {
      final services = await ApiService.getMedicalServices();
      if (!mounted) return;
      setState(() {
        _services = services;
        _loadingServices = false;
      });
      if (_searchController.text.trim().isNotEmpty) _runSearch();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _serviceError = error.toString();
        _loadingServices = false;
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final request = ++_searchRequest;
    _facilityRequest++;
    setState(() {
      _doctors = [];
      _doctorError = null;
      _loadingDoctors = false;
      _facilities = [];
      _facilityError = null;
      _loadingFacilities = false;
      _selectedService = null;
      _requestedServiceId = null;
    });

    if (value.trim().isEmpty) {
      setState(() {
        _loadingDoctors = false;
        _loadingFacilities = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (request == _searchRequest) _runSearch();
    });
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final matchingServices = _matchingServices(query);
    final queryMatchesService =
        matchingServices.isNotEmpty && _serviceMatchesQuery(query);
    final searchForTests = _modePinned
        ? _mode == SearchMode.tests
        : queryMatchesService;
    if (searchForTests) {
      setState(() {
        _mode = SearchMode.tests;
        _doctors = [];
        _doctorError = null;
      });
      if (matchingServices.isEmpty) {
        setState(() {
          _selectedService = null;
          _facilities = [];
          _loadingFacilities = false;
        });
      } else if (matchingServices.length == 1 || _serviceMatchesQuery(query)) {
        _selectService(matchingServices.first);
      } else {
        setState(() {
          _selectedService = null;
          _facilities = [];
          _loadingFacilities = false;
        });
      }
      return;
    }

    final request = ++_searchRequest;
    setState(() {
      _mode = SearchMode.doctors;
      _loadingDoctors = true;
      _doctorError = null;
      _doctors = [];
      _selectedService = null;
      _facilities = [];
    });
    try {
      final results = await ApiService.searchDoctors(query);
      if (!mounted || request != _searchRequest) return;
      results.sort(
        (a, b) =>
            _number(a['consultation_fee'])
                .compareTo(_number(b['consultation_fee'])),
      );
      setState(() {
        _doctors = results;
        _loadingDoctors = false;
      });
    } catch (error) {
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _doctorError = error.toString();
        _loadingDoctors = false;
      });
    }
  }

  List<dynamic> _matchingServices(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return [];
    final matches = _services.where((service) {
      final name = _normalize(service['name']?.toString() ?? '');
      return name.contains(normalizedQuery) ||
          _serviceAliasMatches(normalizedQuery, name);
    }).toList();
    matches.sort((a, b) {
      final aName = _normalize(a['name']?.toString() ?? '');
      final bName = _normalize(b['name']?.toString() ?? '');
      return aName.length.compareTo(bName.length);
    });
    return matches;
  }

  bool _serviceAliasMatches(String query, String serviceName) {
    if (query == 'cbc' && serviceName.contains('completebloodcount')) {
      return true;
    }
    if (query == 'ecg' && serviceName.contains('electrocardiogram')) {
      return true;
    }
    return false;
  }

  bool _serviceMatchesQuery(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return false;
    return _matchingServices(query).any((service) {
      final normalizedName = _normalize(service['name']?.toString() ?? '');
      return normalizedName.contains(normalizedQuery) ||
          _serviceAliasMatches(normalizedQuery, normalizedName);
    });
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  double _number(dynamic value) => value is num ? value.toDouble() : 0;

  void _selectService(dynamic service) {
    final serviceId = service['id'];
    if (serviceId is! int) {
      setState(
        () => _facilityError = 'This service has an invalid identifier.',
      );
      return;
    }
    if (_requestedServiceId == serviceId) return;
    _requestedServiceId = serviceId;
    final request = ++_facilityRequest;
    setState(() {
      _selectedService = Map<String, dynamic>.from(service);
      _loadingFacilities = true;
      _facilityError = null;
      _facilities = [];
    });
    _loadFacilityPrices(serviceId, request);
  }

  Future<void> _loadFacilityPrices(int serviceId, int request) async {
    try {
      final response = await ApiService.getPriceComparison(serviceId);
      if (!mounted || request != _facilityRequest) return;
      final facilities = List<dynamic>.from(response['providers'] ?? []);
      facilities.sort(
        (a, b) => _number(a['price']).compareTo(_number(b['price'])),
      );
      setState(() {
        _facilities = facilities;
        _loadingFacilities = false;
      });
    } catch (error) {
      if (!mounted || request != _facilityRequest) return;
      setState(() {
        _facilityError = error.toString();
        _requestedServiceId = null;
        _loadingFacilities = false;
      });
    }
  }

  void _setMode(SearchMode mode) {
    FocusScope.of(context).unfocus();
    _searchRequest++;
    _facilityRequest++;
    setState(() {
      _mode = mode;
      _modePinned = true;
      _doctors = [];
      _doctorError = null;
      _selectedService = null;
      _facilities = [];
      _facilityError = null;
      _requestedServiceId = null;
    });
    if (_searchController.text.trim().isNotEmpty) _runSearch();
  }

  void _submitSuggestion(String value, SearchMode mode) {
    setState(() {
      _mode = mode;
      _modePinned = true;
    });
    _searchController.text = value;
    _searchController.selection = TextSelection.collapsed(offset: value.length);
    FocusScope.of(context).unfocus();
    _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8F5),
        title: const Text('Find care'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What are you looking for?',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Search specialists or compare test prices nearby.',
                    style: TextStyle(color: _muted, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  _buildSearchField(),
                  const SizedBox(height: 14),
                  _buildModeSelector(),
                ],
              ),
            ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        onChanged: _onQueryChanged,
        onSubmitted: (_) {
          _debounce?.cancel();
          _runSearch();
        },
        decoration: InputDecoration(
          hintText: _mode == SearchMode.doctors
              ? 'Try “neurologist”'
              : 'Try “X-ray” or “CBC”',
          prefixIcon: const Icon(Icons.search_rounded, color: _green, size: 25),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    _onQueryChanged('');
                  },
                  icon: const Icon(Icons.close_rounded, color: _muted),
                ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
          hintStyle: const TextStyle(color: Color(0xFF98A59E), fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0EB),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _modeButton(
            SearchMode.doctors,
            Icons.medical_services_outlined,
            'Doctors',
          ),
          _modeButton(
            SearchMode.tests,
            Icons.monitor_heart_outlined,
            'Tests & prices',
          ),
        ],
      ),
    );
  }

  Widget _modeButton(SearchMode mode, IconData icon, String label) {
    final selected = _mode == mode;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _setMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _ink.withValues(alpha: 0.06),
                        blurRadius: 9,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: selected ? _green : _muted),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? _ink : _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searchController.text.trim().isEmpty) {
      return _buildSuggestions();
    }
    if (_mode == SearchMode.tests) return _buildServiceResults();
    if (_loadingDoctors) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_doctorError != null) {
      return _buildMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Search is unavailable',
        message: 'Check your connection, then try again.',
        action: TextButton(
          onPressed: _runSearch,
          child: const Text('Try again'),
        ),
      );
    }
    if (_doctors.isEmpty) {
      return _buildMessage(
        icon: Icons.person_search_rounded,
        title: 'No matching doctors',
        message: 'Try a specialty such as cardiologist or neurologist.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 36),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _sectionHeading(
          '${_doctors.length} matching doctor${_doctors.length == 1 ? '' : 's'}',
          trailing: 'Lowest fee first',
        ),
        const SizedBox(height: 12),
        ..._doctors.map(_doctorCard),
      ],
    );
  }

  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_mode == SearchMode.doctors) ...[
          _sectionHeading('Popular specialties'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children:
                [
                  'Cardiologist',
                  'Neurologist',
                  'Pediatrician',
                  'Dermatologist',
                  'Orthopedic Surgeon',
                  'Gynecologist',
                ].map((specialty) {
                  return _suggestionChip(
                    specialty,
                    Icons.medical_services_outlined,
                    SearchMode.doctors,
                  );
                }).toList(),
          ),
        ] else ...[
          _sectionHeading(
            'Tests & diagnostics',
            trailing: _loadingServices
                ? 'Loading'
                : '${_services.length} tests',
          ),
          const SizedBox(height: 12),
          if (_loadingServices)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(color: _green),
              ),
            )
          else if (_serviceError != null)
            _buildMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load tests',
              message: 'Check your connection, then reload the catalogue.',
              action: TextButton(
                onPressed: _loadServices,
                child: const Text('Reload'),
              ),
            )
          else
            ..._services.map((service) => _serviceSuggestionCard(service)),
        ],
        if (_mode == SearchMode.doctors) ...[
          const SizedBox(height: 24),
          _sectionHeading('Compare diagnostic prices'),
          const SizedBox(height: 12),
          ..._services
              .take(4)
              .map((service) => _serviceSuggestionCard(service)),
        ],
      ],
    );
  }

  Widget _buildServiceResults() {
    if (_loadingServices) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_serviceError != null) {
      return _buildMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load tests',
        message: 'Check your connection and reload the service catalogue.',
        action: TextButton(
          onPressed: _loadServices,
          child: const Text('Reload'),
        ),
      );
    }

    final matches = _matchingServices(_searchController.text);
    if (matches.isEmpty) {
      return _buildMessage(
        icon: Icons.biotech_outlined,
        title: 'No matching test',
        message: 'Try X-ray, ECG, CBC, or ultrasound.',
      );
    }
    if (_selectedService == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 36),
        children: [
          _sectionHeading('Choose a test'),
          const SizedBox(height: 12),
          ...matches.map((service) => _serviceSuggestionCard(service)),
        ],
      );
    }
    if (_loadingFacilities) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_facilityError != null) {
      return _buildMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load prices',
        message: 'Please check your connection and try again.',
        action: TextButton(
          onPressed: () => _selectService(_selectedService),
          child: const Text('Try again'),
        ),
      );
    }
    if (_facilities.isEmpty) {
      return _buildMessage(
        icon: Icons.location_city_outlined,
        title: 'No price listings yet',
        message: 'There are no facilities offering this service right now.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 36),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _sectionHeading(
          '${_facilities.length} facilities',
          trailing: 'Cheapest first',
        ),
        const SizedBox(height: 10),
        _samplePricesNotice(),
        const SizedBox(height: 12),
        ..._facilities.asMap().entries.map(
          (entry) => _facilityCard(entry.value, entry.key == 0),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedService = null;
              _facilities = [];
              _requestedServiceId = null;
            });
          },
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Choose a different test'),
        ),
      ],
    );
  }

  Widget _doctorCard(dynamic doctor) {
    final fee = _number(doctor['consultation_fee']);
    final verified = doctor['is_verified'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorProfileScreen(
                  doctor: Map<String, dynamic>.from(doctor),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Container(
                  width: 51,
                  height: 51,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2EC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: _green,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              doctor['name']?.toString() ?? 'Doctor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified_rounded,
                              color: _green,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${doctor['specialty'] ?? 'Specialist'} · ${doctor['location'] ?? 'Location not listed'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        '৳${fee.toStringAsFixed(0)} consultation',
                        style: const TextStyle(
                          color: _green,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.chevron_right_rounded, color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _serviceSuggestionCard(dynamic service) {
    final name = service['name']?.toString() ?? 'Medical test';
    final category = service['category']?.toString() ?? 'Diagnostic';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: () {
            _searchController.text = name;
            _selectService(service);
            setState(() => _mode = SearchMode.tests);
            FocusScope.of(context).unfocus();
          },
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2EC),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.biotech_outlined,
                    color: _green,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$category · Compare facility prices',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: _muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _facilityCard(dynamic facility, bool cheapest) {
    final price = _number(facility['price']);
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cheapest ? const Color(0xFFF0F7F1) : Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: cheapest ? const Color(0xFFBBD5C0) : _line),
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: cheapest
                  ? const Color(0xFFDCECDF)
                  : const Color(0xFFF0F3F1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              facility['category'] == 'Hospital'
                  ? Icons.local_hospital_outlined
                  : Icons.biotech_outlined,
              color: _green,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facility['name']?.toString() ?? 'Medical facility',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${facility['category'] ?? 'Facility'} · ${facility['location'] ?? 'Location not listed'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                if (facility['is_sample'] == true) ...[
                  const SizedBox(height: 5),
                  const Text(
                    'Sample listing',
                    style: TextStyle(
                      color: Color(0xFF9A6B24),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (cheapest)
                const Text(
                  'LOWEST',
                  style: TextStyle(
                    color: _green,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              Text(
                '৳${price.toStringAsFixed(0)}',
                style: TextStyle(
                  color: cheapest ? _green : _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _samplePricesNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D9A8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF9A6B24)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sample listings and prices are for demonstration only. Confirm current rates and availability with the facility.',
              style: TextStyle(
                color: Color(0xFF76541F),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label, IconData icon, SearchMode mode) {
    return ActionChip(
      onPressed: () => _submitSuggestion(label, mode),
      avatar: Icon(icon, size: 17, color: _green),
      label: Text(label),
      backgroundColor: Colors.white,
      side: const BorderSide(color: _line),
      labelStyle: const TextStyle(
        color: _ink,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }

  Widget _sectionHeading(String title, {String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2EC),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _green, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
            ),
            if (action != null) action,
          ],
        ),
      ),
    );
  }
}
