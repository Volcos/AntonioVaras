import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:capstone/service/create_event_service.dart';
import 'package:capstone/service/api_event.dart';
import 'package:capstone/service/apibenja_service.dart';
import 'package:capstone/service/location_service.dart';
import 'package:capstone/service/web_service.dart';
import 'package:capstone/service/auth_service.dart';
import 'package:capstone/service/notification_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:capstone/views/map_location_picker.dart';

class CreateEventView extends StatefulWidget {
  final ApiEvent? eventToEdit;

  const CreateEventView({super.key, this.eventToEdit});

  @override
  State<CreateEventView> createState() => CreateEventViewState();
}

class CreateEventViewState extends State<CreateEventView> {
  static const _eventTypes = ['Música', 'Deportes', 'Teatro', 'Familia'];
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _addressFocus = FocusNode();
  final _imageUrl = TextEditingController();
  final _eventUrl = TextEditingController();
  final _comuna = TextEditingController();
  final _type = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _organizer = TextEditingController();
  late List<_DateForm> _dates;
  bool _saving = false;
  bool _resolvingAddress = false;
  Timer? _addressSearchTimer;
  List<AddressSuggestion> _addressSuggestions = [];
  int _addressSearchRequest = 0;
  AddressSuggestion? _selectedAddress;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _existingImage;
  final ImagePicker _imagePicker = ImagePicker();
  AuthUser? _creator;
  bool _loadingCreator = true;
  bool _loadingEditData = false;
  String? _editDataError;

  @override
  void initState() {
    super.initState();
    _dates = [_DateForm(DateTime.now())];
    _addressFocus.addListener(() {
      if (!_addressFocus.hasFocus) _resolveAddress();
    });
    _loadCreator();
    if (widget.eventToEdit != null) {
      _loadingEditData = true;
      _loadEditData(widget.eventToEdit!);
    }
  }

  Future<void> _loadEditData(ApiEvent event) async {
    final eventId = event.apiEventId ?? event.id;
    if (eventId == null || eventId.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingEditData = false;
          _editDataError = 'No se encontró el identificador del evento.';
        });
      }
      return;
    }

    try {
      final details = await ApibenjaService.getEventDetails(eventId);
      if (!mounted) return;
      setState(() {
        _populateEditData(details);
        _loadingEditData = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingEditData = false;
        _editDataError = 'No se pudo cargar el evento: $error';
      });
    }
  }

  void _populateEditData(ApiEvent event) {
    _name.text = event.nombre;
    _description.text = event.descripcion;
    _address.text = event.localizacion;
    _existingImage = event.imagen;
    _imageUrl.text = event.imagen.startsWith('http') ? event.imagen : '';
    _eventUrl.text = event.fuenteInfo.startsWith('http')
        ? event.fuenteInfo
        : '';
    _organizer.text = event.organizador;
    _comuna.text = event.comuna;
    _type.text = event.tipoEvento;
    _latitude.text = event.latitude ?? '';
    _longitude.text = event.longitude ?? '';
    for (final date in _dates) {
      date.dispose();
    }
    _dates = [];
    if (event.schedules.isNotEmpty) {
      _dates = event.schedules.map((schedule) {
        final date = _DateForm(
          DateTime.tryParse(schedule.start)?.toLocal() ?? DateTime.now(),
        )..idFecha = schedule.idFecha;
        date.end = schedule.end == null || schedule.end!.isEmpty
            ? null
            : DateTime.tryParse(schedule.end!)?.toLocal();
        date.price.text = schedule.price ?? '';
        return date;
      }).toList();
    } else if (event.fechaInicio.isNotEmpty) {
      final starts = event.fechaInicio
          .split('\n')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      final ends = event.fechaTermino
          .split('\n')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      _dates = starts.asMap().entries.map((entry) {
        final start = DateTime.tryParse(entry.value);
        final end = entry.key < ends.length
            ? DateTime.tryParse(ends[entry.key])
            : null;
        return _DateForm(start?.toLocal() ?? DateTime.now())
          ..end = end?.toLocal();
      }).toList();
    }
    if (_dates.isEmpty) _dates = [_DateForm(DateTime.now())];
  }

  Future<void> _loadCreator() async {
    final creator = await AuthService.getSavedUser();
    if (!mounted) return;
    setState(() {
      _creator = creator;
      _loadingCreator = false;
      if (widget.eventToEdit == null && creator?.userType == 3) {
        _organizer.text = creator?.name ?? '';
      }
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _address,
      _imageUrl,
      _eventUrl,
      _comuna,
      _type,
      _latitude,
      _longitude,
      _organizer,
    ]) {
      controller.dispose();
    }
    _addressFocus.dispose();
    _addressSearchTimer?.cancel();
    for (final date in _dates) {
      date.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.eventToEdit != null ? 'Editar evento' : 'Crear evento',
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            Text(
              widget.eventToEdit != null
                  ? 'Modifica la información del evento'
                  : 'Publica una nueva experiencia',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Completa los datos del evento y agrega todas sus funciones.',
              style: TextStyle(color: Colors.white60),
            ),
            if (_loadingEditData) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text(
                'Cargando datos completos del evento…',
                style: TextStyle(color: Colors.white60),
              ),
            ],
            if (_editDataError != null) ...[
              const SizedBox(height: 16),
              Text(
                _editDataError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 24),
            _field(_name, 'Nombre del evento', required: true),
            _field(_description, 'Descripción', maxLines: 3),
            _addressField(),
            _imageField(),
            _field(_imageUrl, 'URL de imagen (alternativa)'),
            _field(
              _eventUrl,
              'Página del evento (opcional)',
              keyboard: TextInputType.url,
              validator: _validateOptionalUrl,
            ),
            _eventTypeField(),
            if (!_loadingCreator && _creator?.userType == 1)
              _field(_organizer, 'Organizador', required: true),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Fechas y precios',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadingEditData || _editDataError != null
                      ? null
                      : () => setState(
                          () => _dates.add(_DateForm(_dates.last.start)),
                        ),
                  icon: const Icon(CupertinoIcons.plus),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            ..._dates.asMap().entries.map(
              (entry) => _dateCard(entry.key, entry.value),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving || _loadingEditData || _editDataError != null
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.eventToEdit != null
                          ? 'Guardar cambios'
                          : 'Crear evento',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboard,
    FocusNode? focusNode,
    ValueChanged<String>? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        focusNode: focusNode,
        onFieldSubmitted: onFieldSubmitted,
        style: const TextStyle(color: Colors.white),
        validator:
            validator ??
            (required
                ? (value) => value == null || value.trim().isEmpty
                      ? 'Campo requerido'
                      : null
                : null),
        decoration: _decoration(label),
      ),
    );
  }

  Widget _addressField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _address,
            focusNode: _addressFocus,
            style: const TextStyle(color: Colors.white),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Campo requerido'
                : null,
            onChanged: _searchAddresses,
            onFieldSubmitted: (_) => _resolveAddress(),
            decoration: _decoration('Dirección').copyWith(
              suffixIcon: IconButton(
                icon: const Icon(
                  CupertinoIcons.map_pin_ellipse,
                  color: Colors.pinkAccent,
                ),
                tooltip: 'Seleccionar en el mapa',
                onPressed: _openMapLocationPicker,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openMapLocationPicker,
              icon: const Icon(
                CupertinoIcons.map_pin_ellipse,
                size: 16,
                color: Colors.pinkAccent,
              ),
              label: const Text(
                'Seleccionar ubicación en el mapa',
                style: TextStyle(
                  color: Colors.pinkAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_addressSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _addressSuggestions.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Colors.white12),
                itemBuilder: (context, index) {
                  final suggestion = _addressSuggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      CupertinoIcons.location,
                      color: Colors.white70,
                    ),
                    title: Text(
                      suggestion.displayName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => _selectAddress(suggestion),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _pickJpgImage,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(CupertinoIcons.photo),
            label: Text(
              _selectedImageName == null
                  ? 'Agregar imagen JPG'
                  : 'Cambiar imagen JPG',
            ),
          ),
          if (_selectedImageBytes != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _selectedImageBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedImageName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _selectedImageBytes = null;
                    _selectedImageName = null;
                  }),
                  icon: const Icon(
                    CupertinoIcons.clear_circled,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openMapLocationPicker() async {
    final currentLat = double.tryParse(_latitude.text.trim());
    final currentLng = double.tryParse(_longitude.text.trim());

    final selectedLatLng = await Navigator.push<LatLng>(
      context,
      CupertinoPageRoute(
        builder: (_) => MapLocationPickerView(
          initialLat: currentLat,
          initialLng: currentLng,
        ),
      ),
    );

    if (selectedLatLng == null || !mounted) return;

    final latStr = selectedLatLng.latitude.toStringAsFixed(6);
    final lngStr = selectedLatLng.longitude.toStringAsFixed(6);

    _latitude.text = latStr;
    _longitude.text = lngStr;

    setState(() => _resolvingAddress = true);
    try {
      final address = await LocationService.obtenerDireccion(latStr, lngStr);
      if (address != null && address.isNotEmpty) {
        _address.text = address;
        _selectedAddress = AddressSuggestion(
          displayName: address,
          latitude: selectedLatLng.latitude,
          longitude: selectedLatLng.longitude,
        );
        final suggestions = await LocationService.buscarDirecciones(address);
        if (suggestions.isNotEmpty && suggestions.first.comuna != null) {
          _comuna.text = suggestions.first.comuna!;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _resolvingAddress = false);
  }

  Future<void> _pickJpgImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null || !mounted) return;

    final name = picked.name.toLowerCase();
    if (!name.endsWith('.jpg') && !name.endsWith('.jpeg')) {
      _showMessage('Selecciona una imagen en formato JPG.');
      return;
    }

    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      _showMessage('La imagen JPG no puede superar 2 MB.');
      return;
    }

    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageName = picked.name;
    });
  }

  void _searchAddresses(String value) {
    _selectedAddress = null;
    _latitude.clear();
    _longitude.clear();
    _comuna.clear();
    _addressSearchTimer?.cancel();
    if (value.trim().length < 3) {
      setState(() => _addressSuggestions = []);
      return;
    }

    final requestId = ++_addressSearchRequest;
    _addressSearchTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final suggestions = await LocationService.buscarDirecciones(value);
        if (!mounted || requestId != _addressSearchRequest) return;
        setState(() => _addressSuggestions = suggestions);
      } catch (_) {
        if (mounted && requestId == _addressSearchRequest) {
          setState(() => _addressSuggestions = []);
        }
      }
    });
  }

  void _selectAddress(AddressSuggestion suggestion) {
    _address.text = suggestion.displayName;
    _address.selection = TextSelection.collapsed(offset: _address.text.length);
    _latitude.text = suggestion.latitude.toString();
    _longitude.text = suggestion.longitude.toString();
    _comuna.text = suggestion.comuna ?? '';
    _selectedAddress = suggestion;
    _addressSuggestions = [];
    _addressFocus.unfocus();
    setState(() {});
  }

  Widget _eventTypeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FormField<String>(
        initialValue: _type.text.isEmpty ? null : _type.text,
        validator: (value) =>
            value == null ? 'Selecciona un tipo de evento' : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipo de evento',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _eventTypes.map((type) {
                final selected = _type.text == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _type.text = type);
                    field.didChange(type);
                  },
                  selectedColor: Colors.pinkAccent,
                  backgroundColor: const Color(0xFF202020),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                  ),
                );
              }).toList(),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateCard(int index, _DateForm date) {
    return Card(
      color: const Color(0xFF202020),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Función ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_dates.length > 1)
                  IconButton(
                    onPressed: () => setState(() {
                      date.dispose();
                      _dates.removeAt(index);
                    }),
                    icon: const Icon(
                      CupertinoIcons.delete,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
              ],
            ),
            _dateButton(
              'Inicio',
              date.start,
              (value) => setState(() => date.start = value),
            ),
            _dateButton(
              'Término (opcional)',
              date.end,
              (value) => setState(() => date.end = value),
            ),
            TextFormField(
              controller: date.price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Precio desde (opcional)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateButton(
    String label,
    DateTime? value,
    ValueChanged<DateTime> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        onPressed: () {
          DateTime tempPicked = value ?? DateTime.now();
          showCupertinoModalPopup<void>(
            context: context,
            builder: (BuildContext context) => ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  height: 310,
                  padding: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xCC1A1A1A,
                    ), // Efecto vidrio líquido translúcido
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color: const Color(0x33FFFFFF),
                      width: 1,
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        // Tirador superior indicador
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(top: 8, bottom: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(color: Colors.white54),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: const Text(
                                'Aceptar',
                                style: TextStyle(
                                  color: Colors.pinkAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                onChanged(tempPicked);
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                        Expanded(
                          child: CupertinoTheme(
                            data: const CupertinoThemeData(
                              brightness: Brightness.dark,
                              textTheme: CupertinoTextThemeData(
                                pickerTextStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.dateAndTime,
                              initialDateTime: value ?? DateTime.now(),
                              minimumDate: DateTime.now().subtract(
                                const Duration(days: 1),
                              ),
                              maximumDate: DateTime(2100),
                              use24hFormat: true,
                              onDateTimeChanged: (DateTime newDateTime) {
                                tempPicked = newDateTime;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          alignment: Alignment.centerLeft,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size.fromHeight(48),
        ),
        child: Text(
          value == null ? label : '$label: ${_formatDate(value)}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    for (final date in _dates) {
      if (date.end != null && date.end!.isBefore(date.start)) {
        _showMessage('La fecha de término debe ser posterior al inicio.');
        return;
      }
    }
    await _resolveAddress();
    if (!mounted) return;
    if (_comuna.text.trim().isEmpty) {
      _showMessage('Selecciona una dirección con una comuna reconocida.');
      return;
    }
    setState(() => _saving = true);
    try {
      final creator = await AuthService.getSavedUser();
      final organizerName = widget.eventToEdit != null
          ? _organizer.text
          : creator?.userType == 1
          ? _organizer.text
          : (creator?.name ?? '');

      if (widget.eventToEdit != null) {
        final token = await AuthService.getToken();
        if (token == null || token.isEmpty) {
          throw Exception('Debes iniciar sesión nuevamente.');
        }
        await CreateEventService.updateEvent(
          eventId:
              widget.eventToEdit!.apiEventId ?? widget.eventToEdit!.id ?? '',
          token: token,
          nombre: _name.text,
          descripcion: _description.text,
          direccion: _address.text,
          imagenUrl: _selectedImageBytes != null
              ? 'data:image/jpeg;base64,${base64Encode(_selectedImageBytes!)}'
              : _imageUrl.text.trim().isNotEmpty
              ? _imageUrl.text
              : (_existingImage ?? ''),
          eventUrl: _eventUrl.text,
          comuna: _comuna.text,
          tipoEvento: _type.text.isEmpty ? 'Música' : _type.text,
          latitud: double.tryParse(_latitude.text.trim()),
          longitud: double.tryParse(_longitude.text.trim()),
          organizador: organizerName,
          creatorId: widget.eventToEdit!.creatorId ?? creator?.id,
          fechas: _dates
              .map(
                (date) => EventDateInput(
                  fechaInicio: date.start,
                  fechaTermino: date.end,
                  precioDesde: double.tryParse(date.price.text.trim()),
                  idFecha: int.tryParse(date.idFecha ?? ''),
                ),
              )
              .toList(),
        );
        if (!mounted) return;
        _showMessage('Evento actualizado correctamente.');
      } else {
        final response = await CreateEventService.createEvent(
          nombre: _name.text,
          descripcion: _description.text,
          direccion: _address.text,
          imagenUrl: _selectedImageBytes != null
              ? 'data:image/jpeg;base64,${base64Encode(_selectedImageBytes!)}'
              : _imageUrl.text,
          eventUrl: _eventUrl.text,
          comuna: _comuna.text,
          tipoEvento: _type.text.isEmpty ? 'Música' : _type.text,
          latitud: double.tryParse(_latitude.text.trim()),
          longitud: double.tryParse(_longitude.text.trim()),
          organizador: organizerName,
          creatorId: creator?.id,
          fechas: _dates
              .map(
                (date) => EventDateInput(
                  fechaInicio: date.start,
                  fechaTermino: date.end,
                  precioDesde: double.tryParse(date.price.text.trim()),
                ),
              )
              .toList(),
        );
        if (!mounted) return;
        final responseData = response['data'];
        if (responseData is! Map) {
          throw Exception(
            'El servidor no devolvió los datos del evento creado.',
          );
        }
        final createdEvent = ApibenjaService.parseEvent(
          Map<String, dynamic>.from(responseData),
        )..creatorId = creator?.id;
        if (createdEvent.id == null || createdEvent.id!.isEmpty) {
          throw Exception(
            'El servidor no devolvió el identificador del evento.',
          );
        }
        Webservice.upsertEvent(createdEvent);
        _showMessage('Evento creado correctamente.');

        final eventName = _name.text.trim();
        final comuna = _comuna.text.trim();
        NotificationService().showOrganizerEventCreatedNotification(
          eventName: eventName,
        );
        NotificationService().showNewEventAddedNotification(
          eventName: eventName,
          comuna: comuna,
        );
      }

      if (widget.eventToEdit != null) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      _formKey.currentState!.reset();
      for (final controller in [
        _name,
        _description,
        _address,
        _imageUrl,
        _eventUrl,
        _comuna,
        _type,
        _latitude,
        _longitude,
        _organizer,
      ]) {
        controller.clear();
      }
      setState(() {
        _selectedImageBytes = null;
        _selectedImageName = null;
        for (final date in _dates) {
          date.dispose();
        }
        _dates = [_DateForm(DateTime.now())];
      });
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resolveAddress() async {
    final address = _address.text.trim();
    if (address.isEmpty || _resolvingAddress) return;
    if (_selectedAddress?.displayName == address) return;

    // Si ya existen coordenadas asignadas (por selector de mapa o sugerencia), NO sobrescribir
    final currentLat = double.tryParse(_latitude.text.trim());
    final currentLng = double.tryParse(_longitude.text.trim());
    if (currentLat != null &&
        currentLng != null &&
        currentLat != 0 &&
        currentLng != 0) {
      return;
    }

    setState(() => _resolvingAddress = true);
    try {
      final coordinates = await LocationService.obtenerCoordenadasPorTexto(
        address,
      );
      if (!mounted) return;
      _latitude.text = coordinates?.latitude.toString() ?? '';
      _longitude.text = coordinates?.longitude.toString() ?? '';
    } finally {
      if (mounted) setState(() => _resolvingAddress = false);
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white60),
    filled: true,
    fillColor: const Color(0xFF202020),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String? _validateOptionalUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return 'Ingresa una URL válida (https://...)';
    }
    return null;
  }
}

class _DateForm {
  DateTime start;
  DateTime? end;
  String? idFecha;
  final TextEditingController price = TextEditingController();

  _DateForm(this.start);

  void dispose() => price.dispose();
}
