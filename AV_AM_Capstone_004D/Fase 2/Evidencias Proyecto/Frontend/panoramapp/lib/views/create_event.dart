import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:capstone/service/create_event_service.dart';
import 'package:capstone/service/location_service.dart';

class CreateEventView extends StatefulWidget {
  const CreateEventView({super.key});

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
  final List<_DateForm> _dates = [
    _DateForm(DateTime.now().add(const Duration(days: 1))),
  ];
  bool _saving = false;
  bool _resolvingAddress = false;
  Timer? _addressSearchTimer;
  List<AddressSuggestion> _addressSuggestions = [];
  int _addressSearchRequest = 0;
  AddressSuggestion? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _addressFocus.addListener(() {
      if (!_addressFocus.hasFocus) _resolveAddress();
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
        title: const Text('Crear evento'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            const Text(
              'Publica una nueva experiencia',
              style: TextStyle(
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
            const SizedBox(height: 24),
            _field(_name, 'Nombre del evento', required: true),
            _field(_description, 'Descripción', maxLines: 3),
            _addressField(),
            _field(_imageUrl, 'URL de imagen'),
            _field(
              _eventUrl,
              'Página del evento (opcional)',
              keyboard: TextInputType.url,
              validator: _validateOptionalUrl,
            ),
            _eventTypeField(),
            _field(_organizer, 'Organizador'),
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
                  onPressed: () =>
                      setState(() => _dates.add(_DateForm(_dates.last.start))),
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
              onPressed: _saving ? null : _submit,
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
                  : const Text(
                      'Crear evento',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
            decoration: _decoration('Dirección'),
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

  void _searchAddresses(String value) {
    _selectedAddress = null;
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
        onPressed: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime(2100),
          );
          if (date == null || !mounted) return;
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
          );
          if (time != null) {
            onChanged(
              DateTime(date.year, date.month, date.day, time.hour, time.minute),
            );
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          alignment: Alignment.centerLeft,
        ),
        child: Text(value == null ? label : '$label: ${_formatDate(value)}'),
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
      await CreateEventService.createEvent(
        nombre: _name.text,
        descripcion: _description.text,
        direccion: _address.text,
        imagenUrl: _imageUrl.text,
        eventUrl: _eventUrl.text,
        comuna: _comuna.text,
        tipoEvento: _type.text,
        latitud: double.tryParse(_latitude.text.trim()),
        longitud: double.tryParse(_longitude.text.trim()),
        organizador: _organizer.text,
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
      _showMessage('Evento creado correctamente.');
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
  final TextEditingController price = TextEditingController();

  _DateForm(this.start);

  void dispose() => price.dispose();
}
