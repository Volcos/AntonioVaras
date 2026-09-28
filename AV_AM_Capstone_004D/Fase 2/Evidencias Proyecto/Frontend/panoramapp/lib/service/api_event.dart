class ApiEvent {
  final String? id;
  String nombre;
  String descripcion;
  String fechaInicio;
  String fechaTermino;
  String hora;
  String localizacion;
  String? latitude;
  String? longitude;
  String imagen;
  String fuenteInfo;
  String organizador;

  ApiEvent({
    this.id = '',
    required this.nombre,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaTermino,
    required this.hora,
    required this.localizacion,
    this.latitude,
    this.longitude,
    required this.imagen,
    required this.fuenteInfo,
    required this.organizador,
  });

  static ApiEvent objJson(Map<String, dynamic> json) {
    return ApiEvent(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      fechaInicio: json['fecha_inicio'] ?? json['fechaInicio'] ?? '',
      fechaTermino: json['fecha_termino'] ?? json['fechaTermino'] ?? '',
      hora: json['hora'] ?? '',
      localizacion: json['localizacion'] ?? '',
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      imagen: json['imagen'] ?? '',
      fuenteInfo: json['fuente_info'] ?? json['fuenteInfo'] ?? '',
      organizador: json['organizador'] ?? '',
    );
  }
}
