import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapPickerResult {
  final String street;
  final String city;
  final String state;
  final String country;
  final String zipCode;
  final double latitude;
  final double longitude;

  MapPickerResult({
    required this.street,
    required this.city,
    required this.state,
    required this.country,
    required this.zipCode,
    required this.latitude,
    required this.longitude,
  });
}

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const MapPickerScreen({super.key, this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;

  static const LatLng _defaultPosition = LatLng(18.4861, -69.9312);

  late LatLng _selectedPosition;
  MapPickerResult? _selectedAddress;

  bool _isLoadingLocation = false;
  bool _isGeocoding = false;
  bool _isSearching = false;
  String _addressPreview = 'Mueve el mapa para seleccionar una dirección';

  final TextEditingController _searchController = TextEditingController();
  List<Location> _searchResults = [];
  List<Placemark> _searchPlacemarks = [];
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition ?? _defaultPosition;
    if (widget.initialPosition != null) {
      _geocodePosition(_selectedPosition);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─── BÚSQUEDA POR TEXTO ─────────────────────────────────────────────────
  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty && mounted) {
        // Obtener placemarks para cada resultado
        final placemarks = <Placemark>[];
        for (final loc in locations.take(5)) {
          try {
            final pm =
                await placemarkFromCoordinates(loc.latitude, loc.longitude);
            placemarks.add(pm.isNotEmpty ? pm.first : Placemark());
          } catch (_) {
            placemarks.add(Placemark());
          }
        }

        setState(() {
          _searchResults = locations.take(5).toList();
          _searchPlacemarks = placemarks;
          _showResults = true;
        });
      } else {
        setState(() {
          _showResults = false;
          _searchResults = [];
        });
        _showSnack('No se encontraron resultados para "$query"');
      }
    } catch (e) {
      setState(() {
        _showResults = false;
        _searchResults = [];
      });
      _showSnack('No se encontraron resultados');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(int index) {
    final loc = _searchResults[index];
    final pm = _searchPlacemarks[index];
    final newPos = LatLng(loc.latitude, loc.longitude);

    final street = [pm.thoroughfare ?? '', pm.subThoroughfare ?? '']
        .where((s) => s.isNotEmpty)
        .join(' ')
        .trim();
    final city = pm.locality ?? pm.subAdministrativeArea ?? '';
    final state = pm.administrativeArea ?? '';
    final country = pm.country ?? 'República Dominicana';
    final zipCode = pm.postalCode ?? '';

    final preview =
        [street, city, state, country].where((s) => s.isNotEmpty).join(', ');

    setState(() {
      _selectedPosition = newPos;
      _addressPreview = preview.isNotEmpty ? preview : 'Dirección seleccionada';
      _selectedAddress = MapPickerResult(
        street: street.isNotEmpty
            ? street
            : '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
        city: city,
        state: state,
        country: country,
        zipCode: zipCode,
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      _showResults = false;
      _searchController.text = preview.isNotEmpty ? preview : _addressPreview;
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: newPos, zoom: 17),
      ),
    );

    FocusScope.of(context).unfocus();
  }

  String _buildResultLabel(int index) {
    final pm = _searchPlacemarks[index];
    final parts = [
      pm.thoroughfare,
      pm.subThoroughfare,
      pm.locality,
      pm.administrativeArea,
      pm.country,
    ].where((s) => s != null && s.isNotEmpty).join(', ');
    return parts.isNotEmpty ? parts : 'Resultado ${index + 1}';
  }

  // ─── GEOCODING INVERSO ──────────────────────────────────────────────────
  Future<void> _geocodePosition(LatLng pos) async {
    setState(() {
      _isGeocoding = true;
      _addressPreview = 'Buscando dirección...';
    });

    try {
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final street = [
          place.thoroughfare ?? '',
          place.subThoroughfare ?? '',
        ].where((s) => s.isNotEmpty).join(' ').trim();

        final city = place.locality ?? place.subAdministrativeArea ?? '';
        final state = place.administrativeArea ?? '';
        final country = place.country ?? 'República Dominicana';
        final zipCode = place.postalCode ?? '';

        final preview = [street, city, state, country]
            .where((s) => s.isNotEmpty)
            .join(', ');

        setState(() {
          _addressPreview =
              preview.isNotEmpty ? preview : 'Dirección no disponible';
          _selectedAddress = MapPickerResult(
            street: street.isNotEmpty
                ? street
                : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
            city: city,
            state: state,
            country: country,
            zipCode: zipCode,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
        });
      } else {
        setState(() {
          _addressPreview = 'Dirección no encontrada';
          _selectedAddress = MapPickerResult(
            street:
                '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
            city: '',
            state: '',
            country: 'República Dominicana',
            zipCode: '',
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
        });
      }
    } catch (e) {
      setState(() {
        _addressPreview = 'No se pudo obtener la dirección';
        _selectedAddress = MapPickerResult(
          street:
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
          city: '',
          state: '',
          country: 'República Dominicana',
          zipCode: '',
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      });
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  // ─── MI UBICACIÓN ───────────────────────────────────────────────────────
  Future<void> _goToMyLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Activa el GPS para usar esta función');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Permiso de ubicación denegado');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Activa el permiso de ubicación en Ajustes');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final newPos = LatLng(position.latitude, position.longitude);
      setState(() => _selectedPosition = newPos);

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: newPos, zoom: 17),
        ),
      );
      await _geocodePosition(newPos);
    } catch (e) {
      _showSnack('Error obteniendo ubicación');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _onCameraIdle() => _geocodePosition(_selectedPosition);

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _selectedPosition = position.target;
      _showResults = false;
    });
  }

  void _confirm() {
    if (_selectedAddress != null) {
      Navigator.pop(context, _selectedAddress);
    } else {
      _showSnack('Espera a que se cargue la dirección');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Dirección'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isGeocoding ? null : _confirm,
            child: const Text(
              'Confirmar',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Mapa ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: 15,
            ),
            onMapCreated: (c) => _mapController = c,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Pin central fijo ──
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_pin,
                  color: Color(0xFF1976D2),
                  size: 48,
                  shadows: [
                    Shadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4))
                  ],
                ),
                SizedBox(height: 40),
              ],
            ),
          ),

          // ── Buscador de dirección ──
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                // Campo de búsqueda
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar dirección...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF1976D2)),
                              ),
                            )
                          : const Icon(Icons.search, color: Color(0xFF1976D2)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.grey, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _showResults = false;
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _searchAddress,
                    onChanged: (v) {
                      setState(() {});
                      if (v.length > 3) {
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (_searchController.text == v) {
                            _searchAddress(v);
                          }
                        });
                      }
                    },
                  ),
                ),

                // Resultados de búsqueda
                if (_showResults && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_outlined,
                              color: Color(0xFF1976D2), size: 20),
                          title: Text(
                            _buildResultLabel(index),
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(index),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── Panel inferior con dirección ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on,
                            color: Color(0xFF1976D2), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Dirección seleccionada',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87),
                      ),
                      const Spacer(),
                      if (_isGeocoding)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF1976D2)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _addressPreview,
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey[700], height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedPosition.latitude.toStringAsFixed(6)}, '
                    '${_selectedPosition.longitude.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGeocoding ? null : _confirm,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        'Usar esta dirección',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Botón mi ubicación ──
          Positioned(
            right: 16,
            bottom: 220,
            child: FloatingActionButton.small(
              onPressed: _isLoadingLocation ? null : _goToMyLocation,
              backgroundColor: Colors.white,
              elevation: 4,
              tooltip: 'Mi ubicación',
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF1976D2)),
                    )
                  : const Icon(Icons.my_location, color: Color(0xFF1976D2)),
            ),
          ),
        ],
      ),
    );
  }
}
